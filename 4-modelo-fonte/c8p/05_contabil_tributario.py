
# ---------------------------------------------------------------------------------------------------------------
# Jornadas GE-14 e GE-15: aprovadas por você em 03/10/2026, às 21:05 (cruzamento do dia a dia com o modelo, propostas 1 e 2)

PASSIVO = 'Passivo tributário e parcelas em dia'
PLANO_CONTAS = 'Plano de contas e centros de custo vigentes'
PLANO_TRIB = 'Plano tributário do grupo e regras das operações entre empresas'
DEMONSTR = 'Demonstrações e obrigações fiscais do período'

JORNADAS.append(dict(
    code='GE-14',
    nome='Gerir as dívidas tributárias: parcelamentos, transações, negociações e renegociações',
    dominio='Finanças', classe='essencial', onda=1,
    objetivo='Fazer cada débito tributário, autuação ou intimação ser registrado com a origem, o valor atualizado e o efeito na certidão; '
             'ter as opções levantadas (pagar, parcelar, transacionar ou contestar) com o efeito no caixa e a opinião da assessoria tributária; '
             'ter o caminho decidido na alçada (o executivo; acima dela, os sócios); e cada parcelamento ou transação ser pago em dia e acompanhado, '
             'com o risco de perder as condições levado a renegociação. A Gestão levanta, propõe e paga; a assessoria opina e defende; o executivo ou os sócios decidem.',
    frequencia='Por evento: débito, autuação ou intimação identificado; e na revisão periódica do passivo tributário (cadência: mensal, com o fechamento)',
    automacao=('baixa', 'Registrar o débito, levantar as opções, pagar as parcelas e acompanhar as condições são de agente e automação; '
                        'propor o caminho e formalizar são de pessoa da Gestão; opinar e defender são da assessoria tributária; decidir é do executivo ou dos sócios.'),
    base=['apqc', 'l13988'],
    lanes=['EXE', 'SOC', 'ASS', P, A, R],
    inicios=[I('Débito tributário, autuação ou intimação identificado', R, 'message'),
             I('Revisão periódica do passivo tributário iniciada', R, 'timer')],
    fins=[F('Débito pago, parcelado ou transacionado e acompanhado', R),
          F('Débito contestado e entregue à defesa', R)],
    etapas=[
        E('Levantar o débito e as opções', 'Gestão, com a assessoria tributária', 'Copiloto', 'médio',
          [(DEMONSTR, 'GE-05'), (CAIXA, 'GE-05')],
          [T('Registrar o débito, a origem, o valor atualizado e o efeito na certidão', R),
           T('Levantar as opções de pagar, parcelar, transacionar ou contestar, com o efeito no caixa', A),
           T('Opinar sobre a procedência do débito e as opções', 'ASS')],
          [('Débito tributário com as opções e o efeito no caixa', ['etapa 2'])]),
        E('Decidir o caminho e formalizar', 'Gestão propõe; o executivo decide; acima da alçada dele, os sócios', 'Assistido', 'alto',
          [('Débito tributário com as opções e o efeito no caixa', 'etapa 1'), (ALCADAS, 'Governança')],
          [T('Propor o caminho com o custo, o efeito no caixa e o efeito na certidão', P),
           D('Qual caminho foi proposto?', P,
             [S('Pagar à vista', 'seg', via=[T('Aprovar o pagamento do débito', 'EXE')]),
              S('Parcelar ou transacionar dentro da alçada do executivo', 'seg',
                via=[T('Decidir o parcelamento ou a transação', 'EXE')]),
              S('Parcelar ou transacionar acima da alçada do executivo', 'seg',
                via=[T('Decidir o parcelamento ou a transação pelos sócios', 'SOC', 'manual')]),
              S('Contestar o débito', 'F2', via=[T('Entregar o débito à defesa da assessoria tributária', 'ASS')])]),
           T('Formalizar o pagamento, o parcelamento ou a transação e registrar as condições', P)],
          [('Pagamento, parcelamento ou transação formalizado, com as condições', ['etapa 3']),
           ('Débito tributário e caminho decidido', ['Executivos'])]),
        E('Pagar as parcelas e acompanhar as condições', 'Gestão; a renegociação, o executivo', 'Autopiloto', 'médio',
          [('Pagamento, parcelamento ou transação formalizado, com as condições', 'etapa 2')],
          [T('Programar e pagar a quitação ou as parcelas e registrá-las', R),
           T('Acompanhar as condições do parcelamento ou da transação e o risco de perdê-las', A),
           D('Há risco de perder o parcelamento ou a transação?', A,
             [S('Não', 'prox'),
              S('Sim', 'prox', via=[T('Propor a renegociação ou a regularização ao executivo', P),
                                     T('Decidir a renegociação ou a regularização', 'EXE')])])],
          [(PASSIVO, ['GE-05', 'Executivos'])]),
    ]))

JORNADAS.append(dict(
    code='GE-15',
    nome='Manter a estrutura contábil e o plano tributário do grupo: plano de contas, centros de custo e operações entre as empresas',
    dominio='Finanças', classe='essencial', onda=1,
    objetivo='Fazer o grupo ter um plano de contas comum, com as contas de cada empresa, e centros de custo por empresa, círculo e projeto, '
             'conferidos pela assessoria contábil; e um plano tributário do grupo, com o regime de cada empresa, as operações entre as empresas '
             'e as regras de preço entre elas, simulado pela Gestão, recomendado pela assessoria tributária, conferido pela Governança e decidido '
             'pelo executivo ou, quando muda o regime ou a estrutura, pelos sócios. A Gestão mantém; a assessoria recomenda; a Governança confere; o executivo ou os sócios decidem.',
    frequencia='Por evento: empresa, projeto ou operação entre empresas criado ou mudado; e na revisão anual da estrutura contábil e tributária',
    automacao=('média', 'Manter o plano de contas, abrir e encerrar centros de custo, simular os tributos e registrar são de agente e automação; '
                        'conferir é da assessoria e da Governança; decidir é do executivo ou dos sócios.'),
    base=['apqc', 'cc2002'],
    lanes=['GOV', 'EXE', 'SOC', 'ASS', P, A, R],
    inicios=[I('Empresa, projeto ou operação entre empresas criado ou mudado', R, 'message'),
             I('Revisão anual da estrutura contábil e tributária iniciada', R, 'timer')],
    fins=[F('Estrutura contábil e plano tributário do grupo vigentes', R)],
    etapas=[
        E('Manter o plano de contas e os centros de custo', 'Gestão, com a assessoria contábil', 'Copiloto', 'médio',
          [(PORTFOLIO, 'Estratégia'), (SITUACAO, 'Integração')],
          [T('Manter o plano de contas comum, com as contas de cada empresa', A),
           T('Abrir e encerrar os centros de custo por empresa, círculo e projeto', R),
           T('Conferir o plano de contas e os centros de custo', 'ASS')],
          [(PLANO_CONTAS, ['etapa 2', 'GE-05', 'GE-06'])]),
        E('Planejar os tributos do grupo e as operações entre as empresas', 'Gestão simula; a assessoria recomenda; a Governança confere; o executivo ou os sócios decidem', 'Copiloto', 'alto',
          [(PLANO_CONTAS, 'etapa 1'), (RESULTADO, 'GE-05'), (ACORDO_CONJ, 'Negócios'), (ALCADAS, 'Governança')],
          [T('Simular o regime e os tributos de cada empresa e das operações entre elas', A),
           T('Recomendar o regime, as operações entre empresas e os preços entre elas', 'ASS'),
           T('Conferir a recomendação com as regras e o risco', 'GOV'),
           T('Preparar a proposta de plano tributário para quem decide', P),
           D('A mudança altera o regime de uma empresa ou a estrutura do grupo?', P,
             [S('Não', 'seg', via=[T('Aprovar o plano tributário na alçada do executivo', 'EXE')]),
              S('Sim', 'seg', via=[T('Decidir o plano tributário do grupo', 'SOC', 'manual')])]),
           T('Registrar o plano tributário e as regras das operações entre empresas', R)],
          [(PLANO_TRIB, ['GE-05', 'GE-06', 'Executivos'])]),
    ]))
