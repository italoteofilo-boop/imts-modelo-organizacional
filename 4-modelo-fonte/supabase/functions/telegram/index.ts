// Canal Telegram do IMTS.OS (E5). Edge Function do Supabase.
// POST do Telegram (webhook): confere o cabeçalho X-Telegram-Bot-Api-Secret-Token com o segredo do Vault, entrega a atualização a
// rt.receber_update, responde ao botão e esvazia a fila de envio respeitando os limites (rt.proximos_envios).
// POST ?tarefa=manutencao | configurar | estado, com o cabeçalho X-IMTS-Chave (segredo do Vault): esvazia a fila, apaga as mensagens
// vencidas (autodestruição) e configura o webhook e os comandos do bot. Ambiente "teste" usa a Bot API em /bot<token>/test/<método>.
// Segredos (Vault): telegram_bot_token, telegram_webhook_segredo, imts_funcao_chave; ambiente em telegram_ambiente ("teste" por padrão).
import postgres from "npm:postgres@3.4.4";

const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { max: 2, prepare: false });
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });

async function segredo(nome: string): Promise<string | null> {
  const r = await sql`select rt._segredo(${nome}) as v`;
  return r[0]?.v ?? null;
}

function iguais(a: string | null, b: string | null): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

async function api(token: string, ambiente: string, metodo: string, corpo: unknown) {
  const base = ambiente === "producao" ? `https://api.telegram.org/bot${token}/${metodo}` : `https://api.telegram.org/bot${token}/test/${metodo}`;
  const r = await fetch(base, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(corpo) });
  return await r.json().catch(() => ({ ok: false, description: `HTTP ${r.status}` }));
}

// Envia o que a fila deixar sair agora; os simulados não vão ao Telegram (são confirmados sem envio)
async function esvaziar(token: string | null, ambiente: string) {
  let enviados = 0, falhas = 0;
  for (let rodada = 0; rodada < 5; rodada++) {
    const lote = await sql`select * from rt.proximos_envios(20)`;
    if (!lote.length) break;
    for (const f of lote) {
      if (f.simulado || !token) {
        await sql`select rt.confirmar_envio(${f.id}, ${!!f.simulado}, ${f.simulado ? "simulado" : null}, ${f.simulado ? null : "token do bot ausente"})`;
        if (f.simulado) enviados++; else falhas++;
        continue;
      }
      const chat_id = String(f.chat_ref).replace(/^tg:/, "");
      const corpo: Record<string, unknown> = { chat_id, text: f.texto };
      if (f.botoes) corpo.reply_markup = { inline_keyboard: f.botoes };
      const r = await api(token, ambiente, "sendMessage", corpo);
      if (r.ok) { await sql`select rt.confirmar_envio(${f.id}, true, ${String(r.result.message_id)})`; enviados++; }
      else { await sql`select rt.confirmar_envio(${f.id}, false, null, ${String(r.description ?? "erro")})`; falhas++; }
    }
    await new Promise((ok) => setTimeout(ok, 1100)); // 1 mensagem por segundo por chat
  }
  return { enviados, falhas };
}

// Autodestruição: o bot só apaga mensagens com menos de 48 horas
async function apagar(token: string | null, ambiente: string) {
  if (!token) return { apagadas: 0, motivo: "token do bot ausente" };
  const lista = await sql`select id, chat_ref, mensagem_ref from rt.v_a_apagar where canal = 'telegram' and mensagem_ref is not null limit 200`;
  let apagadas = 0;
  for (const m of lista) {
    const r = await api(token, ambiente, "deleteMessage", { chat_id: String(m.chat_ref).replace(/^tg:/, ""), message_id: Number(m.mensagem_ref) });
    // apagada, ou já não existe/passou de 48 horas: em todos os casos sai da fila e fica registrado
    await sql`select rt.marcar_apagada(${m.id})`;
    if (r.ok) apagadas++;
  }
  return { apagadas, vistas: lista.length };
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const tarefa = url.searchParams.get("tarefa");
    const ambiente = (await segredo("telegram_ambiente")) ?? "teste";
    const token = await segredo("telegram_bot_token");

    if (tarefa) {
      if (!iguais(req.headers.get("x-imts-chave"), await segredo("imts_funcao_chave"))) return json({ erro: "não autorizado" }, 401);
      if (tarefa === "estado") {
        const q = await sql`select count(*) filter (where estado = 'pendente') as pendentes, count(*) filter (where estado = 'erro') as erros from rt.fila_envio`;
        return json({ ambiente, token: !!token, fila: q[0] });
      }
      if (tarefa === "manutencao") return json({ fila: await esvaziar(token, ambiente), autodestruicao: await apagar(token, ambiente) });
      if (tarefa === "configurar") {
        if (!token) return json({ erro: "token do bot ausente: grave-o no Vault com o nome telegram_bot_token" }, 503);
        const destino = `${Deno.env.get("SUPABASE_URL")}/functions/v1/telegram`;
        const w = await api(token, ambiente, "setWebhook", { url: destino, secret_token: await segredo("telegram_webhook_segredo"),
          allowed_updates: ["message", "callback_query"], drop_pending_updates: false });
        const c = await api(token, ambiente, "setMyCommands", { commands: [
          { command: "quadro", description: "Suas tarefas abertas" }, { command: "nova", description: "Nova tarefa avulsa" },
          { command: "concluir", description: "Concluir a tarefa N" }, { command: "decidir", description: "Decidir o cartão N" },
          { command: "aceitar", description: "Aceitar a tarefa N" }, { command: "recusar", description: "Recusar a tarefa N" },
          { command: "iniciar", description: "Iniciar uma jornada" }, { command: "ajuda", description: "Como usar" }] });
        const me = await api(token, ambiente, "getMe", {});
        return json({ webhook: w, comandos: c, bot: me.result?.username ?? null });
      }
      return json({ erro: "tarefa desconhecida" }, 400);
    }

    // webhook do Telegram
    if (req.method !== "POST") return json({ erro: "use POST" }, 405);
    if (!iguais(req.headers.get("x-telegram-bot-api-secret-token"), await segredo("telegram_webhook_segredo"))) return json({ erro: "não autorizado" }, 401);
    const update = await req.json();
    const r = await sql`select rt.receber_update(${sql.json(update)}, false) as r`;
    const res = r[0]?.r ?? {};
    if (res.callback_id && token) await api(token, ambiente, "answerCallbackQuery", { callback_query_id: res.callback_id });
    await esvaziar(token, ambiente);
    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return json({ erro: String((e as Error).message ?? e) }, 500);
  }
});
