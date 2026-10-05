# IMTS.OS · Roteiro de homologação

Execute depois do manual de implantação, com o cadastro real carregado. Cada passo tem quem faz, a ação e o resultado esperado. Marque **ok** ou descreva a diferença. Um passo que falha volta ao time de tecnologia com a mensagem da tela.

## A. Base (time de tecnologia)

| Nº | Ação | Resultado esperado |
| --- | --- | --- |
| A1 | `./aplicar.sh --conferir` | `pronto=true` |
| A2 | `psql "$DB_URL" -f homologar_banco.sql` | `homologação do banco: 7 de 7 ok` |
| A3 | Abrir https://www.imts.global sem login | Tela de entrada com "Entrar com Google" e "Receber link" |
| A4 | Entrar com uma conta Google fora de @imts.email | Google recusa (consentimento interno) ou o sistema mostra "Acesso não liberado" |
| A5 | Pedir link com um e-mail sem convite | Mensagem neutra; ao entrar pelo link, "Acesso não liberado" |
| A6 | Administração > Alertas | Sem alerta aberto |
| A7 | Pedir um documento qualquer pela Mesa ou pelo Acervo | O PDF sai em até 1 minuto (worker ativo) |

## B. Por círculo (líder de cada círculo, com uma pessoa do círculo)

Para todos os círculos (1 Identidade, 2 Estratégia, 3 Inteligência, 4 Relações, 5 Negócios, 6 Integração, 7 Operações, 8 Gestão e 9 Governança):

| Nº | Quem | Ação | Resultado esperado |
| --- | --- | --- | --- |
| B1 | Pessoa | Entrar com o Google | Início com o seu nome, papel e empresa; menu com Mesa, Painel, Central, Acervo e Biblioteca |
| B2 | Pessoa | Mesa > Iniciar jornada: escolher uma jornada do círculo | Recibo "Execução N iniciada"; aparece um cartão no quadro (tarefa de máquina aparece com a etiqueta "assistida") |
| B3 | Pessoa | Mover o cartão para Fazendo e concluir | O cartão vai para Feito; a próxima tarefa da jornada aparece para quem é dono |
| B4 | Pessoa | Delegar um cartão a um colega do círculo | O colega vê em "Precisa de você", aceita e conclui |
| B5 | Pessoa | Criar uma tarefa avulsa com prazo | Aparece em A fazer; o texto que lembra uma jornada traz a sugestão "isso já existe na jornada X" |
| B6 | Líder | Mesa > Círculo | Vê o quadro do círculo e a carga por pessoa |
| B7 | Líder | Decidir um cartão em Decidir | O caminho escolhido segue; a decisão fica registrada na execução (Painel) |
| B8 | Pessoa | Painel > círculo > jornada > execução | Linha do tempo com os eventos dos passos B2 a B7 |
| B9 | Pessoa de outro círculo | Tentar iniciar uma jornada deste círculo | A tela não oferece; o banco recusa com motivo |

## C. Relações e atendimento (círculo 4, com um cliente convidado)

| Nº | Quem | Ação | Resultado esperado |
| --- | --- | --- | --- |
| C1 | Cliente | Entrar pelo link do e-mail | Vai direto ao Portal, com o nome da sua organização |
| C2 | Cliente | Abrir uma dúvida e um chamado | Aparecem na lista com prazo |
| C3 | Relações | Central > Atendimento: responder a dúvida e encaminhar o chamado a Operações | Cliente vê a resposta; Operações recebe o cartão do encaminhamento |
| C4 | Cliente | Confirmar o atendimento com avaliação | Pedido encerrado como confirmado |
| C5 | Cliente | Ouvidoria anônima | Registrada sem nome; só Governança lê |
| C6 | Relações | Marcar reunião com o cliente, com Meet | Evento na agenda de quem marcou, convite no e-mail do cliente, link do Meet na Central e no Portal |
| C7 | Relações | Depois da reunião: transcrição pelo link do Drive, rascunho da ata pela IA, aprovar | Ata aprovada com os encaminhamentos; nada é gravado antes da aprovação |
| C8 | Cliente | Tentar abrir a Mesa (www.imts.global/mesa.html) | Volta à entrada |

## D. Negócios e parceiros (círculo 5, com um parceiro convidado)

| Nº | Quem | Ação | Resultado esperado |
| --- | --- | --- | --- |
| D1 | Parceiro | Registrar uma oportunidade | Aparece em Negócios (Central > Parceiros) |
| D2 | Negócios | Pôr em negociação e responder na sala | Parceiro vê a mensagem na sala |
| D3 | Negócios | Fechar a oportunidade com valor e parcelas | As comissões nascem pela regra do contrato de parceria (E13) |
| D4 | Parceiro | Enviar nota fiscal na prestação de contas | O arquivo vai à pasta 07 do acervo; a nota é conferida contra a comissão |
| D5 | Gestão (círculo 8) | Aprovar e pagar a prestação | Situação paga, com o comprovante |

## E. Acervo e documentos (Integração ou quem opera o acervo)

| Nº | Ação | Resultado esperado |
| --- | --- | --- |
| E1 | Acervo > enviar o cartão CNPJ de uma empresa | Arquivo no Drive na pasta 00, texto lido, CNPJ e razão social propostos |
| E2 | Aprovar o dado (duas pessoas que aprovam) | Campo confirmado; vai para a marca da empresa |
| E3 | Enviar o mesmo arquivo de novo | Recusado como duplicado |
| E4 | Mover para a pasta certa | O arquivo muda de pasta no Drive |
| E5 | Aprovar uma minuta e pedir um documento pela minuta | O PDF sai pelo worker com a marca da empresa |

## F. Administração (primeiro administrador)

| Nº | Ação | Resultado esperado |
| --- | --- | --- |
| F1 | Implantação | Todos os itens ok; nenhum papel sem pessoa |
| F2 | Alterar um parâmetro com motivo | Fica no histórico com antes e depois |
| F3 | Desligar e religar um agente | O estado muda; o motivo fica no histórico |
| F4 | Cadastro: prévia com um erro proposital | A carga é bloqueada e o erro aponta a aba e a linha |
| F5 | Convidar um usuário de fora | O convite aparece em aberto; ao entrar, vira usuário do Portal |
| F6 | Forçar um erro de rotina (com o time) | Um alerta no painel, uma mensagem no Telegram de alertas e um e-mail; sem repetição |

## Aceite

Homologação aprovada quando A, B (todos os círculos), C, D, E e F estiverem ok. Diferenças de processo (não de sistema) vão para o modelo, pelo caminho de mudança do modelo.
