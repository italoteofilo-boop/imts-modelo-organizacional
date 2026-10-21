// Função agente (B39): executa pela IA as tarefas de agente (executor A) que o motor pôs na fila rt.fila_ia (086).
// Chamada pelo banco (rt._agente_ia_chamar, pela fila do pg_net) e pela rotina imts-agente-ia, sempre com o cabeçalho
// X-IMTS-Chave = segredo imts_funcao_chave. Sem login de pessoa: implantar com verify_jwt desligado.
// Provedores: o mesmo código da função ia (Anthropic e Kimi, com reserva; segredos anthropic_chave e kimi_chave no cofre).
// O banco decide o resto: rt.agente_ia_concluir grava o rascunho e abre o cartão de revisão (ou conclui, no modo autônomo);
// rt.agente_ia_falhar devolve à fila ou cai no cartão humano. Cada chamada fica em adm.registro_servidor (função ia, com tokens).
import { CORS, Deps, iguais, json, limparErro, Recusa, registrar, segredo } from "../_comum/servidor.ts";
import { chamarIA, ConfigIA } from "../ia/tratar.ts";

const MAX_SAIDA = 3000;   // tokens de saída por tarefa

export const INSTRUCAO_AGENTE = `Você é o agente de IA do IMTS.OS e faz o rascunho do resultado de uma tarefa de um processo de trabalho, em português do Brasil.
Regras:
- use só o contexto recebido (tarefa, jornada, etapa, entradas, saídas, o que já foi feito e rascunhos anteriores);
- não invente nome, número, valor, data, norma nem decisão; quando faltar um dado, escreva "a confirmar" e liste o que falta;
- o rascunho será revisado por uma pessoa antes de valer, salvo quando o administrador liga o modo autônomo: escreva pronto para uso;
- formato: texto simples com títulos curtos em Markdown, no máximo 800 palavras, nesta ordem:
  ## Resultado (o que a tarefa entrega)
  ## Pendências (o que falta confirmar, ou "nenhuma")
  ## Próximo passo (uma frase)`;

export interface ItemFila { id: number; prompt: string; tarefa: string; tentativa: number }

export async function tratar(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ erro: "use POST" }, 405);
  try {
    const chave = await segredo(deps.sql, "imts_funcao_chave");
    if (!iguais(req.headers.get("x-imts-chave"), chave)) throw new Recusa("não autorizado", 401);
    // deno-lint-ignore no-explicit-any
    const d: any = await req.json().catch(() => ({}));
    const acao = String(d.acao || "agente_executar");
    if (acao !== "agente_executar") throw new Recusa("ação desconhecida: " + acao);
    const lote = Math.min(Math.max(Math.trunc(Number(d.lote) || 5), 1), 20);

    const [{ r }] = await deps.sql`select rt.agente_ia_pegar(${lote}::int) as r`;
    const itens: ItemFila[] = r?.itens || [];
    const cfg: ConfigIA = r?.config || {};
    const res = { processados: 0, revisao: 0, autonomos: 0, cartoes_humanos: 0, novas_tentativas: 0, erros: 0, degradados: Number(r?.degradados || 0) };

    for (const it of itens) {
      res.processados++;
      try {
        const { saida, falhas } = await chamarIA(deps, cfg, INSTRUCAO_AGENTE, it.prompt, MAX_SAIDA);
        // deno-lint-ignore no-explicit-any
        let c: any;
        if (saida && saida.texto.trim()) {
          const modelo = saida.provedor === "kimi" ? cfg.kimi_modelo : cfg.modelo;
          [{ c }] = await deps.sql`select rt.agente_ia_concluir(${it.id}::bigint, ${saida.texto}, ${saida.provedor}, ${modelo ?? null}, ${saida.entrada}::int, ${saida.saida}::int) as c`;
          await registrar(deps.sql, "ia", "agente_executar", null, null, "fila:" + it.id, true,
            saida.provedor + (falhas.length ? " (reserva)" : "") + ": " + (c?.desfecho || "?"), saida.entrada, saida.saida);
        } else {
          // sem resposta: falta de configuração em todos os provedores é definitiva (vai ao cartão); falha de rede ou da API tenta de novo
          const definitivo = !saida && falhas.length > 0 && falhas.every((f) => f.status === 503);
          const motivo = saida ? "a IA devolveu resposta vazia" : "IA indisponível: " + falhas.map((f) => f.provedor + ": " + f.motivo).join("; ");
          [{ c }] = await deps.sql`select rt.agente_ia_falhar(${it.id}::bigint, ${motivo}, ${definitivo}) as c`;
          await registrar(deps.sql, "ia", "agente_executar", null, null, "fila:" + it.id, false, motivo + " -> " + (c?.desfecho || "?"),
            saida?.entrada ?? null, saida?.saida ?? null);
        }
        if (c?.desfecho === "revisao") res.revisao++;
        else if (c?.desfecho === "autonomo") res.autonomos++;
        else if (c?.desfecho === "cartao_humano") res.cartoes_humanos++;
        else if (c?.desfecho === "nova_tentativa") res.novas_tentativas++;
      } catch (e) {
        // falha ao gravar no banco: o pedido fica executando e a rotina o devolve à fila depois de 15 minutos
        res.erros++;
        await registrar(deps.sql, "ia", "agente_executar", null, null, "fila:" + it.id, false, limparErro(e));
        if (!(e instanceof Recusa)) console.error(e);
      }
    }
    return json(res);
  } catch (e) {
    const status = e instanceof Recusa ? e.status : 500;
    if (status >= 500) await registrar(deps.sql, "ia", "agente_executar", null, null, null, false, limparErro(e));
    if (!(e instanceof Recusa)) console.error(e);
    return json({ erro: e instanceof Recusa ? e.message : "falha interna na função agente", codigo: status }, status);
  }
}
