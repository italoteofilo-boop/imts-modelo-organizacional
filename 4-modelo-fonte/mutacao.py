# -*- coding: utf-8 -*-
"""Prova dos testes: planta defeitos de propósito e confere se cada um é detectado.
Uso: python3 mutacao.py c1   (integridade do círculo)  |  python3 mutacao.py cruzar"""
import copy, json, os, sys

alvo = sys.argv[1]

if alvo == 'cruzar':
    import cruzar
    mods = [m for m in ('c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9') if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'saida', m, 'circulo.json'))]
    base = {m: cruzar.carregar(m) for m in mods}
    assert not cruzar.cruzar(base)['problemas']

    def m1(d):   # entrada da Estratégia com nome que a Identidade não entrega
        d['c2']['jornadas'][0]['etapas'][0]['entradas'].append(dict(o='Produto inexistente', de='Identidade'))

    def m2(d):   # Identidade deixa de endereçar a saída à Estratégia
        for j in d['c1']['jornadas']:
            for e in j['etapas']:
                for s in e['saidas']:
                    if s['o'] == 'Definição do que conta como impacto':
                        s['para'] = [p for p in s['para'] if p != 'Estratégia']

    def m3(d):   # Estratégia entrega à Identidade algo que ela não recebe
        d['c2']['jornadas'][0]['etapas'][4]['saidas'].append(dict(o='Produto sem destino', para=['Identidade']))

    def m4(d):   # Identidade troca o nome de uma entrada vinda da Estratégia
        for j in d['c1']['jornadas']:
            for e in j['etapas']:
                for x in e['entradas']:
                    if x['de'] == 'Estratégia' and x['o'].startswith('Pedido de identidade'):
                        x['o'] = 'Pedido de identidade'

    def m5(d):   # consulta deixa de ter resposta endereçada a quem pediu
        for j in d['c1']['jornadas']:
            for e in j['etapas']:
                e['saidas'] = [s for s in e['saidas'] if s['o'] != 'Resposta à consulta']

    def m6(d):   # Inteligência deixa de entregar a leitura de mercado à Identidade
        for j in d['c3']['jornadas']:
            for e in j['etapas']:
                for s in e['saidas']:
                    if s['o'] == 'Leitura de mercado, clientes e concorrentes':
                        s['para'] = [p for p in s['para'] if p != 'Identidade']

    def m7(d):   # Inteligência troca o nome do pacote que a Estratégia espera no portão
        for j in d['c3']['jornadas']:
            for e in j['etapas']:
                for s in e['saidas']:
                    if s['o'] == 'Pacote da oferta pronta para lançamento':
                        s['o'] = 'Pacote da oferta'

    def m8(d):   # Inteligência deixa de receber um produto que a Estratégia lhe endereça
        for j in d['c3']['jornadas']:
            for e in j['etapas']:
                e['entradas'] = [x for x in e['entradas'] if x['o'] != 'Lições da revisão da estratégia']

    def m9(d):   # Inteligência entrega à Estratégia algo que ela não recebe
        d['c3']['jornadas'][0]['etapas'][0]['saidas'].append(dict(o='Produto sem destino', para=['Estratégia']))

    def m10(d):  # Relações deixa de entregar a escuta dos públicos à Identidade
        for j in d['c4']['jornadas']:
            for e in j['etapas']:
                for s in e['saidas']:
                    if s['o'] == 'Escuta dos públicos':
                        s['para'] = [p for p in s['para'] if p != 'Identidade']

    def m11(d):  # Relações espera da Estratégia um produto com nome trocado
        for j in d['c4']['jornadas']:
            for e in j['etapas']:
                for x in e['entradas']:
                    if x['o'] == 'Oferta aprovada para lançamento':
                        x['o'] = 'Oferta aprovada'

    def m12(d):  # Relações deixa de receber o protocolo de crise que a Identidade lhe entrega
        for j in d['c4']['jornadas']:
            for e in j['etapas']:
                e['entradas'] = [x for x in e['entradas'] if x['o'] != 'Protocolo de crise']

    muts = [m1, m2, m3, m4, m5] + ([m6, m7, m8, m9] if 'c3' in base else []) + ([m10, m11, m12] if 'c4' in base else [])
    ok = 0
    for m in muts:
        d = copy.deepcopy(base)
        m(d)
        p = cruzar.cruzar(d)['problemas']
        ok += bool(p)
        print(m.__name__, 'detectado' if p else 'NÃO DETECTADO', '|', p[0] if p else '')
    print(f'DEFEITOS DETECTADOS: {ok} de {len(muts)}')
    sys.exit(0 if ok == len(muts) else 1)

sys.argv = ['gerar.py', alvo]
import gerar

orig = copy.deepcopy(gerar.M.JORNADAS)


def roda(mut):
    js = copy.deepcopy(orig)
    mut(js)
    gerar.JORNADAS[:] = js
    gerar.BYCODE.clear(); gerar.BYCODE.update({j['code']: j for j in js})
    gerar.CODES[:] = [j['code'] for j in js]
    try:
        graphs = {j['code']: gerar.build(j) for j in js}
        probs, _ = gerar.integridade(graphs)
    except Exception as ex:           # defeito que quebra a montagem do grafo também conta como detectado
        probs = [f'erro na montagem: {type(ex).__name__}: {ex}']
    return probs


def primeira_tarefa(js, k=0):
    for it in js[k]['etapas'][0]['fluxo']:
        if it['k'] == 'T':
            return it


def m_nome_sem_verbo(js): primeira_tarefa(js)['nome'] = 'Evidências consolidadas'
def m_saida_sem_destino(js): js[0]['etapas'][0]['saidas'][0] = (js[0]['etapas'][0]['saidas'][0][0], [])
def m_saida_orfa(js): js[0]['etapas'][0]['saidas'].append(('Produto que ninguém recebe', ['etapa 2']))
def m_entrada_orfa(js): js[1]['etapas'][1]['entradas'].append(('Produto que ninguém gera', 'etapa 1'))
def m_entrada_outra_jornada(js): js[1]['etapas'][0]['entradas'].append(('Produto que a outra jornada não gera', js[0]['code']))
def m_destino_fora_vocabulario(js): js[0]['etapas'][0]['saidas'].append(('Produto para parte inexistente', ['Marketing']))
def m_risco_alto_autopiloto(js):
    js[0]['etapas'][0]['risco'] = 'alto'; js[0]['etapas'][0]['modo'] = 'Autopiloto'
def m_tarefa_repetida(js):
    a = primeira_tarefa(js)
    js[0]['etapas'][1]['fluxo'].insert(0, dict(a))
def m_jornada_sem_verbo(js): js[0]['nome'] = 'Estratégia do Ecossistema'
def m_decisao_sem_pergunta(js):
    for j in js:
        for et in j['etapas']:
            for it in et['fluxo']:
                if it['k'] == 'D':
                    it['pergunta'] = it['pergunta'].rstrip('?'); return
def m_decisao_uma_saida(js):
    for j in js:
        for et in j['etapas']:
            for it in et['fluxo']:
                if it['k'] == 'D':
                    it['saidas'] = it['saidas'][:1]; return
def m_fim_nao_usado(js): js[0]['fins'].append(dict(nome='Fim que ninguém alcança', lane=js[0]['fins'][0]['lane']))
def m_raia_inexistente(js): primeira_tarefa(js)['lane'] = 'XXX'
def m_fonte_sem_uso(js): js[0]['base'].append('fonte_inexistente')
def m_etapa_sem_entrada(js): js[0]['etapas'][2]['entradas'] = []
def m_automato_com_pessoa(js):
    sg = gerar.SIGLA
    for j in js:
        for et in j['etapas']:
            if et['modo'] == 'Copiloto':
                et['modo'] = 'Autômato'; et['risco'] = 'baixo'; return
def m_agente_decide(js):
    for j in js:
        for et in j['etapas']:
            for it in et['fluxo']:
                if it['k'] == 'T' and it['lane'] == gerar.PREF + 'A':
                    it['nome'] = 'Decidir ' + it['nome'][0].lower() + it['nome'][1:]; return
def m_nivel_automacao_errado(js):
    n = js[0]['automacao'][0].split()[0].rstrip(',;')
    js[0]['automacao'] = ({'baixa': 'alta', 'média': 'baixa', 'alta': 'baixa'}[n], js[0]['automacao'][1])
def m_copiloto_vira_assistido(js):
    for j in js:
        for et in j['etapas']:
            if et['modo'] == 'Copiloto':
                et['modo'] = 'Assistido'; return
def m_dinheiro_sem_segunda_pessoa(js):
    for j in js:
        for et in j['etapas']:
            itens = [it for it in et['fluxo'] if it['k'] == 'T']
            if any(gerar.DINHEIRO.match(it['nome']) for it in itens):
                for it in itens:
                    if gerar.APROVA.match(it['nome']):
                        it['lane'] = gerar.PREF + 'P'; it['exec'] = 'P'
                return
    js[0]['etapas'][0]['fluxo'].append(dict(k='T', nome='Pagar o fornecedor sem aprovação', lane=gerar.PREF + 'R', exec='R', tipo='script'))
def m_volta_para_etapa_inexistente(js):
    for j in js:
        for et in j['etapas']:
            for it in et['fluxo']:
                if it['k'] == 'D':
                    it['saidas'][-1]['destino'] = 'E99'; return


muts = [v for k, v in sorted(globals().items()) if k.startswith('m_')]
assert not roda(lambda js: None), 'a versão sem defeito deveria passar'
ok = 0
for m in muts:
    p = roda(m)
    ok += bool(p)
    print(m.__name__[2:], '|', 'detectado' if p else 'NÃO DETECTADO', '|', (p[0][:110] if p else ''))
print(f'DEFEITOS DETECTADOS: {ok} de {len(muts)}')
sys.exit(0 if ok == len(muts) else 1)
