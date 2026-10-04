# -*- coding: utf-8 -*-
"""Auditoria de execução: classifica cada etapa e cada tarefa das jornadas pelo modo de execução
(exclusivamente humana, assistida, copiloto, autopiloto, autômata) e aponta o que não confere.
Lê saida/cN/circulo.json (gerado pelo gerar.py). Uso: python3 auditar.py"""
import json, os, re
from collections import Counter, defaultdict

BASE = os.path.dirname(os.path.abspath(__file__))
MODS = ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9']
HUMANO = {'P', 'H', 'X'}               # pessoa do círculo, pessoa de fora do círculo (sócio, executivo, líder, cliente), assessoria
# a tarefa de outro círculo (C) não conta como humana nem como máquina: o modo dela é decidido no círculo que a executa
MAQ = {'A', 'R'}                        # agente, automação
JULGA = re.compile(r'^(Decidir|Aprovar|Julgar|Escolher|Autorizar|Calibrar|Liberar)\b')
MECANICA = re.compile(r'^(Registrar|Publicar|Arquivar|Lembrar|Enviar|Avisar|Lançar|Versionar|Cadastrar|Notificar)\b')


def classe_real(main, todas):
    """O que a etapa é, pelas tarefas: sem máquina = exclusivamente humana; sem humano = autômata (só automação)
    ou autopiloto (com agente); humano só fora do caminho principal = autopiloto; humano e máquina no caminho
    principal = copiloto (máquina faz o grosso) ou assistida (pessoa faz o grosso)."""
    em = Counter(t['exec'] for t in main)
    et = Counter(t['exec'] for t in todas)
    maq_t = et['A'] + et['R']
    hum_m = sum(em[x] for x in HUMANO)
    hum_t = sum(et[x] for x in HUMANO)
    if main and all(t['exec'] == 'C' for t in main):
        return 'Conduzida por outros círculos'
    if maq_t == 0:
        return 'Exclusivamente humana'
    if hum_t == 0:
        return 'Autômata' if et['A'] == 0 else 'Autopiloto'
    if hum_m == 0:
        return 'Autopiloto'
    return 'Copiloto' if (em['A'] + em['R']) >= hum_m else 'Assistida'


def main():
    etapas, achados = [], []
    por_circ = defaultdict(lambda: dict(tarefas=Counter(), modos=Counter(), reais=Counter()))
    particip = Counter()
    jorn_aut = []
    for m in MODS:
        d = json.load(open(os.path.join(BASE, 'saida', m, 'circulo.json'), encoding='utf-8'))
        circ = d['circulo']['nome']
        for j in d['jornadas']:
            tj = Counter()
            for e in j['etapas']:
                todas = e['tarefas']
                main_ = [t for t in todas if not t['cond']]
                real = classe_real(main_, todas)
                modo = e['modo']
                tj.update(t['exec'] for t in todas)
                por_circ[circ]['tarefas'].update(t['exec'] for t in todas)
                por_circ[circ]['modos'][modo] += 1
                por_circ[circ]['reais'][real] += 1
                ref = f"{j['code']} etapa {e['n']}"
                etapas.append(dict(circulo=circ, ref=ref, nome=e['nome'], modo=modo, risco=e['risco'], real=real,
                                   n=len(todas), maq=sum(1 for t in todas if t['exec'] in MAQ)))
                for t in todas:
                    if t['exec'] == 'C':
                        particip[(t['raia'], circ)] += 1
                # 1. declarado x real
                esperado = {'Exclusivamente humana': {'Assistido'}, 'Assistida': {'Assistido'},
                            'Copiloto': {'Copiloto'}, 'Autopiloto': {'Autopiloto'}, 'Autômata': {'Autômato'},
                            'Conduzida por outros círculos': {'Assistido', 'Copiloto', 'Autopiloto', 'Autômato'}}[real]
                if modo not in esperado:
                    achados.append(('médio', 'Modo declarado diferente do que as tarefas fazem', ref,
                                    f'Declarado {modo}; pelas tarefas a etapa é {real.lower()}.'))
                # 2. risco alto precisa de pessoa do círculo no caminho principal
                if e['risco'] == 'alto' and not any(t['exec'] in ('P', 'H') for t in main_):
                    achados.append(('grave', 'Risco alto sem pessoa no caminho principal', ref,
                                    'Nenhuma pessoa (do círculo, sócio, executivo ou líder) decide no caminho principal da etapa de risco alto.'))
                elif e['risco'] == 'alto' and not any(t['exec'] == 'P' for t in main_) and not any(t['exec'] == 'H' and t['nome'].startswith(('Decidir', 'Aprovar', 'Assinar')) for t in main_):
                    achados.append(('médio', 'Risco alto sem pessoa do círculo dono nem decisão de sócio ou executivo', ref,
                                    'A etapa de risco alto é conduzida só por outros círculos ou papéis.'))
                # 3. agente ou automação julgando
                for t in main_:
                    if t['exec'] in MAQ and JULGA.match(t['nome']):
                        achados.append(('grave', 'Agente ou automação toma decisão de julgamento', ref, t['nome']))
                # 4. decisão de julgamento na raia de máquina em etapa de risco médio ou alto
                for dd in e.get('decisoes', []):
                    q, quem = dd['pergunta'], dd['quem']
                    if quem.endswith('agente') and e['risco'] in ('médio', 'alto') and len(dd['saidas']) >= 2:
                        achados.append(('leve', 'Decisão do caminho tomada pelo agente em etapa de risco médio ou alto', ref,
                                        f'{q} Conferir se é regra objetiva; se for julgamento, vai para pessoa.'))
                # 5. pessoa fazendo trabalho mecânico
                for t in main_:
                    if t['exec'] == 'P' and MECANICA.match(t['nome']):
                        achados.append(('leve', 'Pessoa do círculo faz tarefa mecânica que a automação pode fazer', ref, t['nome']))
                # 6. copiloto sem pessoa do próprio círculo
                if modo == 'Copiloto' and not any(t['exec'] == 'P' for t in main_) and any(t['exec'] == 'H' for t in main_):
                    achados.append(('leve', 'Copiloto em que a pessoa no caminho é de fora do círculo', ref,
                                    'Quem acompanha a máquina não é do círculo dono da etapa.'))
            n = sum(tj.values())
            jorn_aut.append(dict(code=j['code'], circulo=circ, declarado=j['automacao']['nivel'],
                                 maq=(tj['A'] + tj['R']) / n if n else 0, n=n))
    # 7. nível de automação declarado x faixa pela parcela de tarefas de máquina (até 1/3 baixa, até 2/3 média)
    for x in jorn_aut:
        fx = 'baixa' if x['maq'] <= 1 / 3 + 1e-9 else ('média' if x['maq'] <= 2 / 3 + 1e-9 else 'alta')
        if x['declarado'].split()[0].rstrip(',;') != fx:
            achados.append(('leve', 'Nível de automação declarado não bate com a parcela de tarefas de máquina', x['code'],
                            f"Declarado {x['declarado']}; {round(x['maq'] * 100)}% das tarefas são de agente ou automação: {fx}."))
    res = dict(etapas=etapas, achados=[dict(gravidade=a, tipo=b, onde=c, detalhe=d) for a, b, c, d in achados],
               por_circulo={k: {kk: dict(vv) for kk, vv in v.items()} for k, v in por_circ.items()},
               participacoes=[dict(quem=a, em=b, tarefas=n) for (a, b), n in particip.most_common()],
               automacao=jorn_aut)
    json.dump(res, open(os.path.join(BASE, 'saida', 'auditoria.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    reais = Counter(e['real'] for e in etapas)
    decl = Counter(e['modo'] for e in etapas)
    print('etapas', len(etapas), 'declarado', dict(decl), 'real', dict(reais))
    print('achados', Counter(a[0] for a in achados), Counter(a[1] for a in achados))
    return res


if __name__ == '__main__':
    main()
