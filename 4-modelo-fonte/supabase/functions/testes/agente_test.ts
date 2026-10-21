// Testes da função agente (B39, 086) contra o banco de ensaio, com a Anthropic simulada (fetch falso).
// Tudo roda dentro de uma transação desfeita no fim: não fica pedido, cartão, instância nem chave no banco.
// Rodar: IMTS_DB_URL=postgres://postgres:<senha>@127.0.0.1:5499/ensaio deno test -A functions/testes/agente_test.ts
import postgres from "npm:postgres@3.4.4";
import { INSTRUCAO_AGENTE, tratar as agente } from "../agente/tratar.ts";

const sql = postgres(Deno.env.get("IMTS_DB_URL") || "postgres://postgres:ensaio-local@127.0.0.1:5499/ensaio", { max: 1, prepare: false, onnotice: () => {} });
function ok(c: unknown, m: string) { if (!c) throw new Error(m); }
class Desfazer extends Error {}

// Anthropic simulada: guarda o que recebeu; "fora" responde 500
const chamadas: { url: string; corpo: string; chave: string | null }[] = [];
let fora = false;
function simulado(input: string | URL | Request, init?: RequestInit): Promise<Response> {
  const url = String(input);
  chamadas.push({ url, corpo: String(init?.body ?? ""), chave: new Headers(init?.headers).get("x-api-key") });
  const J = (b: unknown, s = 200) => Promise.resolve(new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } }));
  if (url.startsWith("https://api.anthropic.com/")) {
    if (fora) return J({ error: { message: "sobrecarregado" } }, 500);
    return J({ content: [{ type: "text", text: "## Resultado\nRascunho do agente simulado.\n## Pendências\nnenhuma\n## Próximo passo\nRevisar." }], usage: { input_tokens: 150, output_tokens: 60 } });
  }
  return J({ error: { message: "rota não simulada: " + url } }, 500);
}

Deno.test({ name: "agente: fila da IA, revisão humana, modo autônomo, falha e falta de chave", sanitizeResources: false, sanitizeOps: false, async fn(t) {
  try {
    await sql.begin(async (tx) => {
      const deps = { sql: tx, fetch: simulado as typeof fetch };
      const [{ v: chaveFuncao }] = await tx`select rt._segredo('imts_funcao_chave') as v`;
      ok(chaveFuncao, "o ensaio precisa do segredo imts_funcao_chave");
      const chamar = (chave: string | null = chaveFuncao) =>
        agente(new Request("http://local/agente", { method: "POST", headers: { "content-type": "application/json", ...(chave ? { "x-imts-chave": chave } : {}) }, body: '{"acao":"agente_executar"}' }), deps);

      await tx`update adm.parametro set valor = 'true' where chave in ('motor.maquina_assistida', 'motor.agente_ia')`;
      await tx`update adm.parametro set valor = 'false' where chave = 'motor.agente_ia_autonomo'`;
      await tx`update adm.parametro set valor = '200' where chave = 'motor.agente_ia_chamadas_dia'`;
      await tx`update adm.parametro set valor = '2' where chave = 'motor.agente_ia_tentativas'`;
      await tx`update adm.parametro set valor = '2000000' where chave = 'ia.orcamento_mensal_tokens'`;
      await tx`update adm.parametro set valor = '"anthropic"' where chave = 'ia.provedor'`;
      await tx`update adm.parametro set valor = '""' where chave in ('ia.kimi_url', 'ia.kimi_modelo')`;
      await tx`update adm.parametro set valor = '"https://teste-agente.invalid/functions/v1"' where chave = 'servidor.url_funcoes'`;
      await tx`delete from vault.secrets where name = 'anthropic_chave'`;
      await tx`select vault.create_secret('chave-de-teste', 'anthropic_chave')`;
      // nada pendente de antes atrapalha a contagem
      await tx`update rt.fila_ia set estado = 'cancelado' where estado in ('pendente', 'executando')`;

      const [tar] = await tx`select t.id, t.nome from org.tarefa t where t.executor = 'A' and exists (select 1 from rt.no n join rt.fluxo f on f.jornada = n.jornada and f.de = n.id where n.tarefa = t.id) order by t.id limit 1`;
      ok(tar, "modelo sem tarefa de agente");
      // instância real e interativa com o token na tarefa de agente; o motor anda um passo
      const nova = async () => {
        const [{ id }] = await tx`with n as (select * from rt.no where tarefa = ${tar.id} order by jornada, id limit 1)
          insert into rt.instancia (motor, jornada, simulado, inicio, relogio, versao_base, interativo)
          select j.circulo, n.jornada, false, now(), now(), m.versao_base, true from n join org.jornada j on j.codigo = n.jornada join rt.motor m on m.circulo = j.circulo returning id`;
        await tx`insert into rt.token (instancia, no) select ${id}, id from rt.no where tarefa = ${tar.id} order by jornada, id limit 1`;
        await tx`select rt._avancar(${id}::bigint, 1)`;
        const [f] = await tx`select * from rt.fila_ia where instancia = ${id}`;
        return { inst: id, f };
      };

      await t.step("sem a chave da função: 401 e nenhuma chamada à IA", async () => {
        const antes = chamadas.length;
        ok((await chamar("errada")).status === 401 && (await chamar(null)).status === 401 && chamadas.length === antes, "aceitou sem chave");
      });

      await t.step("padrão: rascunho da IA vira cartão de revisão, com tokens registrados", async () => {
        const { inst, f } = await nova();
        ok(f?.estado === "pendente", "não entrou na fila: " + JSON.stringify(f));
        const r = await chamar(); const j = await r.json();
        ok(r.status === 200 && j.processados === 1 && j.revisao === 1, JSON.stringify(j));
        const enviado = JSON.parse(chamadas.at(-1)!.corpo);
        ok(chamadas.at(-1)!.chave === "chave-de-teste" && enviado.system === INSTRUCAO_AGENTE && enviado.messages[0].content === f.prompt
           && enviado.messages[0].content.startsWith("Tarefa: " + tar.nome) && enviado.max_tokens === 3000, "pedido à IA");
        const [g] = await tx`select f.estado, f.desfecho, f.resultado, f.provedor, f.tokens_entrada, f.tokens_saida, c.titulo, c.coluna from rt.fila_ia f join rt.cartao c on c.id = f.cartao where f.id = ${f.id}`;
        ok(g?.estado === "feito" && g.desfecho === "revisao" && g.resultado.includes("Rascunho do agente simulado") && g.provedor === "anthropic"
           && g.tokens_entrada === 150 && g.titulo.startsWith("Revisar rascunho da IA: ") && g.coluna === "a_fazer", JSON.stringify(g));
        const [tk] = await tx`select count(*)::int as n from rt.token where instancia = ${inst} and estado = 'aguardando'`; ok(tk.n === 1, "o token deveria esperar a revisão");
        const [reg] = await tx`select ok, tokens_entrada + tokens_saida as t, detalhe from adm.registro_servidor where funcao = 'ia' and acao = 'agente_executar' and alvo = ${"fila:" + f.id}`;
        ok(reg?.ok && reg.t === 210 && reg.detalhe.includes("revisao"), JSON.stringify(reg));
      });

      await t.step("modo autônomo: o agente conclui e o token segue sem cartão", async () => {
        await tx`update adm.parametro set valor = 'true' where chave = 'motor.agente_ia_autonomo'`;
        const { inst, f } = await nova();
        const j = await (await chamar()).json(); ok(j.autonomos === 1, JSON.stringify(j));
        const [e] = await tx`select count(*)::int as n from rt.evento where instancia = ${inst} and tarefa = ${tar.id} and tipo = 'fim' and resultado = 'concluída pelo agente de IA (anthropic, sem revisão)'`;
        const [c] = await tx`select count(*)::int as n from rt.cartao where instancia = ${inst} and tarefa = ${tar.id}`;
        const [k] = await tx`select count(*)::int as n from rt.token where instancia = ${inst} and no = ${f.no}`;
        ok(e.n === 1 && c.n === 0 && k.n === 0, JSON.stringify({ e, c, k }));
        await tx`update adm.parametro set valor = 'false' where chave = 'motor.agente_ia_autonomo'`;
      });

      await t.step("provedor fora do ar: tenta de novo e, esgotadas as tentativas, cai no cartão humano", async () => {
        fora = true;
        try {
          const { f } = await nova();
          const j1 = await (await chamar()).json(); ok(j1.novas_tentativas === 1, JSON.stringify(j1));
          const j2 = await (await chamar()).json(); ok(j2.cartoes_humanos === 1, JSON.stringify(j2));
          const [g] = await tx`select f.estado, f.tentativas, f.motivo, c.titulo from rt.fila_ia f join rt.cartao c on c.id = f.cartao where f.id = ${f.id}`;
          ok(g?.estado === "erro" && g.tentativas === 2 && g.motivo.includes("anthropic") && g.titulo.includes("(assistida:"), JSON.stringify(g));
          const [reg] = await tx`select count(*)::int as n from adm.registro_servidor where funcao = 'ia' and acao = 'agente_executar' and alvo = ${"fila:" + f.id} and not ok`;
          ok(reg.n === 2, "falhas registradas: " + reg.n);
        } finally { fora = false; }
      });

      await t.step("chave apagada depois de entrar na fila: a função não chama a IA e o pedido cai no cartão humano", async () => {
        const { f } = await nova();
        await tx`delete from vault.secrets where name = 'anthropic_chave'`;
        const antes = chamadas.length;
        const j = await (await chamar()).json(); ok(j.cartoes_humanos + j.degradados >= 1 && chamadas.length === antes, JSON.stringify(j));
        const [g] = await tx`select estado, desfecho, motivo, cartao from rt.fila_ia where id = ${f.id}`;
        ok(g.estado === "erro" && g.desfecho === "cartao_humano" && g.cartao && /anthropic_chave/.test(g.motivo), JSON.stringify(g));
      });

      throw new Desfazer();
    });
  } catch (e) { if (!(e instanceof Desfazer)) throw e; }
  finally { await sql.end(); }
} });
