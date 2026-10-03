# -*- coding: utf-8 -*-
"""Prova dos testes: planta defeitos de propósito e confere se cada um é detectado.
Uso: python3 mutacao.py c1   (integridade do círculo)  |  python3 mutacao.py cruzar"""
import copy, json, os, sys

alvo = sys.argv[1]

if alvo == 'cruzar':
    import cruzar
    base = {m: cruzar.carregar(m) for m in ('c1', 'c2')}
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

    muts = [m1, m2, m3, m4, m5]
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
