# IMTS.OS · Runbook de operação

Para o time de Integração. Toda ação aqui é feita pela Administração do aplicativo ou pelo SQL Editor do Supabase, com conta de administrador.

## Rotina

| Quando | O quê | Onde |
| --- | --- | --- |
| Todo dia | Alertas abertos | Administração > Alertas (também chegam no Telegram e por e-mail) |
| Toda semana | Conferência da implantação | `./aplicar.sh --conferir` ou Administração > Implantação |
| Toda semana | Uso da IA no mês | `select sum(tokens_entrada + tokens_saida) from adm.registro_servidor where funcao = 'ia' and em >= date_trunc('month', now());` |
| Todo mês | Saúde das conexões | Administração > Conexões > verificar |
| Todo mês | Pessoas que saíram | Administração: encerrar acessos (fim) no mesmo dia da saída |
| A cada 90 dias | Trocar os segredos | Ver "Segredos" abaixo |

## Rotinas agendadas (pg_cron)

| Rotina | Frequência | O que faz |
| --- | --- | --- |
| `imts-vigia` | 10 min | Abre e fecha alertas (erros, conexões, rotinas, filas, armazenamento) |
| `imts-alertas-email` | 10 min | Chama a função `alertas` quando há alerta sem e-mail |
| `imts-telegram-manutencao` | 10 min | Esvazia a fila do bot e apaga mensagens vencidas |
| `imts-agentes` | 5 min | Acorda os agentes residentes |
| `imts-adm-verificacao` | 30 min | Verifica conexões e destrava pedidos de documento parados |
| `imts-atendimento-tacito` | de hora em hora | Encerra atendimentos não confirmados no prazo |
| `imts-retencao-eventos` | diária | Apaga eventos antigos de execuções encerradas (desligada com o padrão 0) |
| `imts-limpeza-updates` | diária | Limpa atualizações antigas do Telegram |

Conferir execuções: `select j.jobname, d.status, d.start_time from cron.job_run_details d join cron.job j using (jobid) order by d.start_time desc limit 20;`

## Alertas: causa e o que fazer

| Alerta | Causa provável | Ação |
| --- | --- | --- |
| `erro:<origem>` | Falha numa função ou rotina | Ler o detalhe em `adm.erro` (`select * from adm.erro order by em desc limit 20;`); corrigir a causa; o alerta fecha sozinho uma hora depois sem repetir |
| `erro:google.<ação>` | Conta de serviço, delegação ou parâmetro do Google | Conferir segredo `google_conta_servico`, escopos da delegação e `google.usuario_sistema` / `google.drive_raiz` |
| `erro:ia.ata_rascunho` | Chave da IA inválida ou API fora | Conferir `anthropic_chave`; a tela oferece escrever a ata à mão |
| `erro:alertas.email` | Gmail ou parâmetros de alerta | Conferir `alerta.emails`, `google.usuario_sistema` e o escopo `gmail.send` |
| `conexao:<código>` | Conexão ativa com falha na verificação | Administração > Conexões: ver o detalhe; corrigir endereço ou segredo |
| `rotina:<nome>` | Rotina do pg_cron falhando | Ver `cron.job_run_details`; corrigir e conferir na próxima execução |
| `fila:documentos` | Worker parado ou sem rede | `docker ps`, `docker logs imts-worker`; reiniciar com `docker restart imts-worker`; conferir `DOC_WORKER_CHAVE` |
| `fila:envio` | Bot do Telegram sem token ou fora | Conferir `telegram_bot_token`; rodar `select rt.telegram_configurar();` |
| `armazenamento:documentos` | PDFs no banco acima de `documentos.limite_mb` | Planejar a ida dos PDFs ao Storage (item B25 do backlog) ou subir o limite com motivo |

Resolver à mão (depois de corrigir): Administração > Alertas > Resolver.

## Incidentes

1. **Acesso indevido ou vazamento suspeito:** encerre o acesso da pessoa (fim = hoje) e troque os segredos envolvidos. Registre o incidente pela Governança (círculo 9) e avalie a comunicação à ANPD e aos titulares com o encarregado (LGPD).
2. **Aplicativo fora:** confira a hospedagem e o DNS de www.imts.global, e a página de status do Supabase.
3. **Login Google falhando para todos:** confira o cliente OAuth e o segredo em Authentication > Providers > Google, e as URLs de redirecionamento.
4. **Link de e-mail não chega:** confira o SMTP próprio e o limite de envio em Authentication.

## Backup e recuperação

- Backups do Supabase conforme o plano contratado. Para recuperar a qualquer instante, avalie o PITR: https://supabase.com/docs/guides/platform/backups
- Antes de qualquer mudança de modelo (troca de versão), anote o horário: é o ponto de volta.
- O repositório guarda todo o código e todas as migrações. O banco se reconstrói com `aplicar.sh` num projeto novo, mais o backup dos dados.

## Segredos (cofre)

| Segredo | Para quê | Como trocar |
| --- | --- | --- |
| `google_conta_servico` | Drive, Agenda e Gmail | Nova chave JSON na conta de serviço; `vault.update_secret(<id>, '<json>')`; apagar a chave antiga no Google Cloud |
| `anthropic_chave` | IA | Nova chave no Console da Anthropic; `vault.update_secret`; revogar a antiga |
| `telegram_bot_token` | Bot | `/revoke` no @BotFather; `vault.update_secret`; `select rt.telegram_configurar();` |
| `telegram_webhook_segredo` | Webhook do bot | `vault.update_secret` com valor novo aleatório; `select rt.telegram_configurar();` |
| `imts_funcao_chave` | Rotinas que chamam funções | `vault.update_secret` com valor novo aleatório (as rotinas leem na hora) |
| `doc_worker_chave` | Worker de documentos | `vault.update_secret`; atualizar `DOC_WORKER_CHAVE` no contêiner e reiniciar |

Id de um segredo: `select id, name from vault.secrets order by name;`. Valor aleatório: `select encode(extensions.gen_random_bytes(32), 'hex');`.

## Mudanças

- **Parâmetro:** Administração > Parâmetros, sempre com motivo (fica no histórico). Parâmetro sensível pede segunda aprovação.
- **Código do banco:** só por migração nova no repositório, aplicada primeiro num projeto de teste com `aplicar.sh` e com a rodada de testes do protótipo verde.
- **Aplicativo:** `app/testes/rodar_todos.sh` verde no ensaio local, depois `montar.sh` e publicação.
