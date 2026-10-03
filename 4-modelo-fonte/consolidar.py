# -*- coding: utf-8 -*-
"""Consolida as jornadas cross da rodada 2 (V1-V8, C1-C13, E1-E5) nas jornadas dos nove círculos fechados.
Cada cross vira uma cadeia de jornadas; cada elo da cadeia é conferido nos dados: a jornada de origem entrega um
produto que a jornada seguinte recebe (pelo código da jornada ou pelo nome do círculo).
Uso: python3 consolidar.py  (grava saida/consolidacao.json e saida/consolidacao.md)"""
import json, os

BASE = os.path.dirname(os.path.abspath(__file__))
MODS = ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9']
CIRC = {}
J = {}
for m in MODS:
    d = json.load(open(os.path.join(BASE, 'saida', m, 'circulo.json'), encoding='utf-8'))
    for j in d['jornadas']:
        J[j['code']] = j
        CIRC[j['code']] = d['circulo']['nome']

# cross da rodada 2 -> (nome, líder antes, cadeia nova, dono do resultado agora, nota)
CROSS = [
    ('V1', 'Do problema à oferta', 'Inteligência', ['IN-07', 'ES-04', 'IT-03'], 'Inteligência desenha; Estratégia decide no portão; Integração lança',
     'A decisão de lançamento passou à Estratégia (ES-04) no fechamento do círculo 2.'),
    ('V2', 'Do mercado à oportunidade', 'Relações', ['RE-01', 'RE-02', 'RE-03', 'NE-03'], 'Relações', ''),
    ('V3', 'Da oportunidade ao contrato', 'Negócios', ['NE-03', 'NE-04', 'GO-05'], 'Negócios', 'Na licitação, NE-05 no lugar de NE-03 e NE-04.'),
    ('V4', 'Do contrato à operação', 'Integração', ['NE-04', 'IT-02', 'OP-02'], 'Integração', ''),
    ('V5', 'Da entrega ao recebimento', 'Operações', ['OP-02', 'GE-03'], 'Operações entrega; Gestão fatura e recebe', ''),
    ('V6', 'Do chamado à solução', 'Operações', ['OP-03', 'OP-04', 'OP-05'], 'Operações', 'O problema de tecnologia segue para a IT-07.'),
    ('V7', 'Do resultado à renovação', 'Relações', ['OP-02', 'RE-05', 'NE-06'], 'Relações acompanha; Negócios renova', ''),
    ('V8', 'Da previsão ao produto entregue', 'Operações', ['NE-02', 'OP-01', 'OP-06', 'GE-03'], 'Operações', 'Só onde há produto físico.'),
    ('C1', 'Da estratégia ao resultado', 'Estratégia', ['ES-01', 'ES-03', 'GE-01', 'GE-02', 'ES-06'], 'Estratégia; a Gestão roda o orçamento e o ritual', ''),
    ('C2', 'Do propósito ao padrão', 'Identidade', ['ID-01', 'ID-02', 'IT-06'], 'Identidade', 'O padrão chega aos agentes pela IT-06 e às pessoas pela Gestão (GE-07 a GE-10).'),
    ('C3', 'Do dado ao aprendizado', 'Inteligência', ['IN-03', 'IN-04', 'IN-08'], 'Inteligência', ''),
    ('C4', 'Do contato à parceria ativa', 'Relações', ['RE-06', 'NE-07'], 'Relações', ''),
    ('C5', 'Da necessidade à capacidade', 'Integração', ['IT-05', 'IT-06'], 'Integração', ''),
    ('C6', 'Da vaga ao talento', 'Gestão', ['GE-07', 'GE-08', 'GE-09'], 'Gestão', ''),
    ('C7', 'Da compra ao pagamento', 'Gestão', ['OP-06', 'GE-04', 'GE-05'], 'Gestão', 'Qualquer círculo pede compra à GE-04.'),
    ('C8', 'Do registro à prestação de contas', 'Gestão', ['GE-05', 'GO-03'], 'Gestão; a Governança relata riscos e conformidade', ''),
    ('C9', 'Do risco ao controle', 'Governança', ['GO-03', 'GO-01'], 'Governança', ''),
    ('C10', 'Do pedido de tecnologia ao serviço estável', 'Integração', ['OP-03', 'IT-07'], 'Integração', 'Qualquer círculo pede à IT-07.'),
    ('C11', 'Da marca à reputação', 'Identidade', ['ID-04', 'RE-08', 'GO-08'], 'Identidade cria a marca e o posicionamento; Relações monitora; a Governança decide a crise', 'A marca nasce na ID-03; a percepção é medida contra o posicionamento da ID-04.'),
    ('C12', 'Do valor declarado à cultura vivida', 'Identidade', ['ID-02', 'GE-10', 'GE-09', 'ID-05'], 'Identidade; a Gestão executa', ''),
    ('C13', 'Da minuta ao contrato encerrado', 'Governança', ['GO-01', 'NE-04', 'GO-05'], 'Governança', 'O contrato é originado pela frente dona.'),
    ('E1', 'Do pedido ao serviço', 'Integração', ['IT-05'], 'Integração', 'O pedido de serviço de uma empresa a um círculo fica na IT-05, com acordo de serviço.'),
    ('E2', 'Da oportunidade cruzada à oferta conjunta', 'Negócios', ['NE-07', 'GE-03'], 'Negócios', 'O acordo entre as empresas vai também à guarda na GO-05.'),
    ('E3', 'Do custo corporativo ao rateio', 'Gestão', ['GO-01', 'GE-06', 'GE-05'], 'Governança define com a Estratégia; Gestão aplica', ''),
    ('E4', 'Do resultado da empresa à decisão do Ecossistema', 'Estratégia', ['GE-05', 'ES-02'], 'Estratégia', ''),
    ('E5', 'Da aposta à empresa nova', 'Estratégia', ['ES-04', 'ES-05', 'IT-04'], 'Estratégia', 'A IT-04 abre o projeto de ligar a empresa nova.'),
]


def elo(a, b):
    """Produtos que a jornada a entrega e a jornada b recebe."""
    ja, jb = J[a], J[b]
    ca, cb = CIRC[a], CIRC[b]
    prods = set()
    for e in ja['etapas']:
        for x in e['saidas']:
            alvo = set(x['para'])
            if b in alvo or (ca != cb and (cb in alvo or 'Todos (pessoas e agentes)' in alvo)):
                for f in jb['etapas']:
                    for y in f['entradas']:
                        if y['o'] == x['o'] and (y['de'] in (a, ca) or (ca != cb and y['de'] == 'Solicitante')):
                            prods.add(x['o'])
    return sorted(prods)


def main():
    res, falhas = [], []
    for code, nome, lider, cadeia, dono, nota in CROSS:
        for c in cadeia:
            assert c in J, (code, c)
        elos = []
        for a, b in zip(cadeia, cadeia[1:]):
            p = elo(a, b)
            elos.append(dict(de=a, para=b, produtos=p))
            if not p:
                falhas.append(f'{code}: {a} -> {b} sem produto em comum')
        res.append(dict(codigo=code, nome=nome, lider_antes=lider, cadeia=cadeia,
                        circulos=sorted({CIRC[c] for c in cadeia}, key=lambda n: [CIRC[x] for x in J].index(n)),
                        dono=dono, nota=nota, elos=elos))
    out = dict(jornadas=len(J), por_circulo={}, cross=res, falhas=falhas)
    for c, n in CIRC.items():
        out['por_circulo'][n] = out['por_circulo'].get(n, 0) + 1
    json.dump(out, open(os.path.join(BASE, 'saida', 'consolidacao.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    md = ['# Consolidação das jornadas cross', '',
          f'Jornadas nos nove círculos: {len(J)}. Cada jornada cross da rodada 2 virou uma cadeia de jornadas dos círculos; '
          'cada elo foi conferido nos dados (a jornada de origem entrega um produto que a seguinte recebe).', '',
          '| Cross | Nome | Cadeia nova | Dono do resultado | Elos conferidos | Nota |', '|---|---|---|---|---|---|']
    for r in res:
        ok = sum(1 for e in r['elos'] if e['produtos'])
        md.append(f"| {r['codigo']} | {r['nome']} | {' → '.join(r['cadeia'])} | {r['dono']} | {ok} de {len(r['elos'])} | {r['nota']} |")
    open(os.path.join(BASE, 'saida', 'consolidacao.md'), 'w', encoding='utf-8').write('\n'.join(md) + '\n')
    print('jornadas', len(J), out['por_circulo'])
    for r in res:
        print(r['codigo'], ' -> '.join(r['cadeia']), [len(e['produtos']) for e in r['elos']])
    for f in falhas:
        print(' FALHA', f)
    return 1 if falhas else 0


if __name__ == '__main__':
    raise SystemExit(main())
