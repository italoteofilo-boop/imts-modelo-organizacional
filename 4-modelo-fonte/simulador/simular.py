# -*- coding: utf-8 -*-
"""E7 · Simulador de cenários. Separado do motor: lê uma cópia do modelo (saida/cN/circulo.json e os fluxos BPMN) e dos parâmetros,
roda carga sintética com fila por papel e devolve propostas de mudança, que seguem a ID-04. Nunca escreve no motor.

O que muda em relação ao motor: aqui as pessoas têm capacidade. Cada tarefa de pessoa do círculo (P) ocupa uma pessoa do papel da raia,
em horário de trabalho; quem chega com o papel ocupado espera na fila. Agentes e automações (A, R) não esperam; pessoa de fora, outro
círculo e assessoria (H, C, X) contam só o tempo de resposta. Os tempos são as hipóteses do protótipo (rt.parametro_simulacao, G9).

Uso: python3 simulador/simular.py [--cenarios base,dobro,reforco] [--meses 3] [--semente 7]
Saída: simulador/resultado/<cenario>.json e simulador/resultado/propostas.md"""
import argparse, glob, heapq, json, os, random, re, statistics, xml.etree.ElementTree as ET
from collections import defaultdict

AQUI = os.path.dirname(os.path.abspath(__file__)); BASE = os.path.dirname(AQUI)
NS = {'b': 'http://www.omg.org/spec/BPMN/20100524/MODEL'}
TAREFAS = {'task', 'userTask', 'scriptTask', 'serviceTask', 'manualTask', 'callActivity', 'receiveTask', 'businessRuleTask', 'sendTask'}
# hipóteses do protótipo, em minutos (as mesmas de rt.parametro_simulacao)
TEMPO = {'A': (2, 20), 'R': (0.1, 2), 'P': (30, 240), 'H': (60, 2880), 'C': (60, 2880), 'X': (1440, 7200)}
JORNADA_MIN = 8 * 60          # minutos de trabalho por dia
MES_MIN = 30 * 24 * 60        # minutos corridos num mês

FREQ = {}
# Volume por mês tirado da frequência escrita em cada jornada (hipótese do simulador, até haver dado real):
# a cadência mais frequente citada, mais 1 por mês quando a jornada também roda "por evento"
CADENCIA = [('diári', 22), ('semanal', 4), ('quinzenal', 2), ('mensal', 1), ('bimestral', 0.5), ('trimestral', 1 / 3), ('semestral', 1 / 6), ('anual', 1 / 12)]


def por_mes(f):
    f = (f or '').lower(); c = max([v for k, v in CADENCIA if k in f] or [0])
    return c + (1 if 'evento' in f else 0) or 1


CENARIOS = {
    'base':    dict(descricao='Uma pessoa por papel; o volume de cada jornada pela frequência do modelo', volume=1.0, capacidade={}),
    'dobro':   dict(descricao='O dobro do volume, com a mesma equipe', volume=2.0, capacidade={}),
    'reforco': dict(descricao='O dobro do volume, com duas pessoas em cada papel que passou de 85% de ocupação no cenário dobro', volume=2.0, capacidade='reforco'),
}


def carregar():
    """Grafo de cada jornada (BPMN) com executor e raia de cada tarefa (circulo.json)."""
    tarefas, nome_j, circ_j = {}, {}, {}
    global FREQ
    for k in range(1, 10):
        d = json.load(open(os.path.join(BASE, 'saida', f'c{k}', 'circulo.json'), encoding='utf-8'))
        for j in d['jornadas']:
            nome_j[j['code']] = j['nome']; circ_j[j['code']] = k; FREQ[j['code']] = por_mes(j.get('frequencia', ''))
            for e in j['etapas']:
                for o, t in enumerate(e['tarefas'], 1):
                    tarefas[(j['code'], e['n'], o)] = t
    grafos = {}
    for arq in sorted(glob.glob(os.path.join(BASE, 'saida', 'c[1-9]', 'bpmn', '*.bpmn'))):
        jor = os.path.basename(arq)[:-5]
        proc = ET.parse(arq).getroot().find('b:process', NS)
        raia = {r.text: l.get('name') for l in proc.iter('{%s}lane' % NS['b']) for r in l.findall('b:flowNodeRef', NS)}
        nos, saem, entram = {}, defaultdict(list), defaultdict(int)
        for el in proc:
            tag = el.tag.split('}')[1]; i = el.get('id')
            if tag == 'sequenceFlow':
                saem[el.get('sourceRef')].append((i, el.get('targetRef'))); entram[el.get('targetRef')] += 1
            elif tag in TAREFAS or tag.endswith('Event') or tag.endswith('Gateway'):
                m = re.search(r'_E(\d+)_T(\d+)$', i)
                t = tarefas.get((jor, int(m.group(1)), int(m.group(2)))) if (m and tag in TAREFAS) else None
                nos[i] = dict(tipo=tag, raia=raia.get(i), exec=t['exec'] if t else None, nome=t['nome'] if t else el.get('name'),
                              etapa=int(m.group(1)) if m else None)
        # fluxos de volta (laço) e a saída de decisão que abre cada laço, como no motor (rt.fluxo.volta e rt.fluxo.laco)
        volta, cor = set(), {}
        for s in sorted(i for i, n in nos.items() if n['tipo'] == 'startEvent'):
            if cor.get(s): continue
            pilha = [(s, iter(saem.get(s, [])))]; cor[s] = 1
            while pilha:
                no, it = pilha[-1]; prox = next(it, None)
                if prox is None: cor[no] = 2; pilha.pop(); continue
                fid, alvo = prox; c = cor.get(alvo, 0)
                if c == 1: volta.add(fid)
                elif c == 0: cor[alvo] = 1; pilha.append((alvo, iter(saem.get(alvo, []))))
        laco = {}
        for d, lst in saem.items():
            if len(lst) < 2: continue
            for fid0, alvo0 in lst:
                fid, alvo, vistos = fid0, alvo0, set()
                while True:
                    if fid in volta: laco[fid0] = fid; break
                    prox = saem.get(alvo, [])
                    if len(prox) != 1 or alvo in vistos: break
                    vistos.add(alvo); fid, alvo = prox[0]
        grafos[jor] = dict(nos=nos, saem=dict(saem), entram=dict(entram), laco=laco)
    return grafos, nome_j, circ_j


class Sim:
    def __init__(self, grafos, circ_j, cap, rnd):
        self.g, self.circ, self.cap, self.rnd = grafos, circ_j, cap, rnd
        self.livre = {}            # papel -> lista de instantes em que cada pessoa fica livre
        self.uso = defaultdict(float); self.espera = defaultdict(list); self.feitas = defaultdict(int)

    def papel(self, jor, raia):
        return f'{raia} · círculo {self.circ[jor]}' if raia in ('Líder do círculo', 'Pessoa', 'Líder da equipe', 'Solicitante') else raia

    def horario(self, t):
        """Avança t para dentro do horário de trabalho (8h às 16h de cada dia corrido)."""
        dia, h = divmod(t, 24 * 60)
        if h < 8 * 60: return dia * 24 * 60 + 8 * 60
        if h >= 16 * 60: return (dia + 1) * 24 * 60 + 8 * 60
        return t

    def trabalho(self, t, minutos):
        """Fim de um trabalho de 'minutos' começando em t, só em horário de trabalho."""
        t = self.horario(t)
        while minutos > 0:
            fim_dia = (t // (24 * 60)) * 24 * 60 + 16 * 60
            passo = min(minutos, fim_dia - t); t += passo; minutos -= passo
            if minutos > 0: t = self.horario(t + 1e-9)
        return t

    def executar(self, jor, t0):
        G = self.g[jor]; nos, saem = G['nos'], G['saem']
        voltas = defaultdict(int); chegadas = defaultdict(int)
        fila = [(t0, i) for i, n in nos.items() if n['tipo'] == 'startEvent'][:1]
        fim, passos = t0, 0
        while fila and passos < 2000:
            passos += 1
            t, no = heapq.heappop(fila); n = nos[no]
            if n['exec']:
                lo, hi = TEMPO[n['exec']]; dur = self.rnd.uniform(lo, hi)
                if n['exec'] == 'P':
                    p = self.papel(jor, n['raia']); pessoas = self.livre.setdefault(p, [0.0] * self.cap.get(p, 1))
                    k = min(range(len(pessoas)), key=lambda x: pessoas[x])
                    inicio = self.horario(max(t, pessoas[k])); fim_t = self.trabalho(inicio, dur)
                    pessoas[k] = fim_t; self.uso[p] += dur; self.espera[p].append(inicio - t); self.feitas[p] += 1
                    t = fim_t
                else:
                    t += dur
                for _, alvo in saem.get(no, []): heapq.heappush(fila, (t, alvo))
            elif n['tipo'] == 'exclusiveGateway' and len(saem.get(no, [])) > 1:
                ops = [(f, a) for f, a in saem[no] if f not in G['laco'] or voltas[G['laco'][f]] < 2]
                if not ops: ops = sorted(saem[no], key=lambda x: voltas.get(G['laco'].get(x[0]), 0))[:1]
                pesos = [1.0 if f not in G['laco'] else 1.0 / (1 + voltas[G['laco'][f]]) ** 2 for f, _ in ops]
                f, a = self.rnd.choices(ops, weights=pesos)[0]
                if f in G['laco']: voltas[G['laco'][f]] += 1
                heapq.heappush(fila, (t, a))
            elif n['tipo'] == 'parallelGateway' and G['entram'].get(no, 0) > 1:
                chegadas[no] += 1
                if chegadas[no] >= G['entram'][no]:
                    chegadas[no] = 0
                    for _, alvo in saem.get(no, []): heapq.heappush(fila, (t, alvo))
            else:
                for _, alvo in saem.get(no, []): heapq.heappush(fila, (t, alvo))
            fim = max(fim, t)
        return fim - t0


def rodar(nome, cfg, grafos, circ_j, meses, semente, cap):
    rnd = random.Random(semente); s = Sim(grafos, circ_j, cap, rnd)
    chegadas = []
    for jor in grafos:
        n = max(1, int(round(FREQ[jor] * cfg['volume'] * meses)))
        chegadas += [(rnd.uniform(0, meses * MES_MIN), jor) for _ in range(n)]
    lead = defaultdict(list)
    for t, jor in sorted(chegadas):
        lead[jor].append(s.executar(jor, t) / 60)
    horas_disp = meses * 22 * JORNADA_MIN   # minutos de trabalho por pessoa no período (22 dias úteis por mês, aproximado)
    papeis = {p: dict(pessoas=len(v), ocupacao=round(s.uso[p] / (horas_disp * len(v)), 3), tarefas=s.feitas[p],
                      espera_media_h=round(statistics.mean(s.espera[p]) / 60, 1) if s.espera[p] else 0.0,
                      espera_p90_h=round(sorted(s.espera[p])[int(0.9 * (len(s.espera[p]) - 1))] / 60, 1) if s.espera[p] else 0.0)
              for p, v in s.livre.items()}
    jornadas = {j: dict(execucoes=len(v), lead_mediana_h=round(statistics.median(v), 1), lead_p90_h=round(sorted(v)[int(0.9 * (len(v) - 1))], 1))
                for j, v in lead.items() if v}
    return dict(cenario=nome, descricao=cfg['descricao'], meses=meses, semente=semente, papeis=papeis, jornadas=jornadas)


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--cenarios', default='base,dobro,reforco'); ap.add_argument('--meses', type=int, default=3)
    ap.add_argument('--semente', type=int, default=7); a = ap.parse_args()
    grafos, nome_j, circ_j = carregar()
    os.makedirs(os.path.join(AQUI, 'resultado'), exist_ok=True)
    res = {}
    for nome in a.cenarios.split(','):
        cfg = CENARIOS[nome]; cap = {}
        if cfg['capacidade'] == 'reforco':
            cap = {p: 2 for p, v in res['dobro']['papeis'].items() if v['ocupacao'] > 0.85}
        res[nome] = rodar(nome, cfg, grafos, circ_j, a.meses, a.semente, cap)
        json.dump(res[nome], open(os.path.join(AQUI, 'resultado', f'{nome}.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        top = sorted(res[nome]['papeis'].items(), key=lambda x: -x[1]['ocupacao'])[:3]
        print(nome, 'jornadas', len(res[nome]['jornadas']), 'papéis', len(res[nome]['papeis']), 'mais ocupados', [(p, v['ocupacao']) for p, v in top])
    escrever_propostas(res, nome_j)


def escrever_propostas(res, nome_j):
    L = ['# Propostas do simulador de cenários (E7)', '',
         'Gerado por simulador/simular.py. O simulador lê uma cópia do modelo e não escreve no motor. As propostas seguem a ID-04, que decide.',
         'Os tempos são hipóteses do protótipo (rt.parametro_simulacao, a calibrar no G9); o volume vem da frequência escrita em cada jornada (a cadência mais frequente citada, mais 1 por mês quando a jornada também roda "por evento"), e também é hipótese até haver dado real.', '']
    for nome, r in res.items():
        L += [f'## Cenário {nome}: {r["descricao"]}', '', '| Papel | Pessoas | Ocupação | Espera média (h) | Espera p90 (h) |', '|---|---|---|---|---|']
        for p, v in sorted(r['papeis'].items(), key=lambda x: -x[1]['ocupacao'])[:10]:
            L.append(f'| {p} | {v["pessoas"]} | {round(v["ocupacao"] * 100)}% | {v["espera_media_h"]} | {v["espera_p90_h"]} |')
        L.append('')
    base, dobro = res.get('base'), res.get('dobro')
    L += ['## Propostas', '']
    k = 0
    if dobro:
        for p, v in sorted(dobro['papeis'].items(), key=lambda x: -x[1]['ocupacao']):
            if v['ocupacao'] > 0.85:
                k += 1
                ref = res.get('reforco', {}).get('papeis', {}).get(p)
                L.append(f'{k}. **{p}**: no volume dobrado, a ocupação chega a {round(v["ocupacao"] * 100)}% e a espera p90 a {v["espera_p90_h"]} h. '
                         + (f'Com uma segunda pessoa no papel, a ocupação cai para {round(ref["ocupacao"] * 100)}% e a espera p90 para {ref["espera_p90_h"]} h. ' if ref else '')
                         + 'Proposta à ID-04: prever a segunda pessoa no G2 ou levar tarefas do papel para Copiloto ou Autopiloto onde a etapa permitir.')
    if base:
        lentas = sorted(base['jornadas'].items(), key=lambda x: -x[1]['lead_p90_h'])[:5]
        for j, v in lentas:
            k += 1
            L.append(f'{k}. **{j} · {nome_j[j]}**: no cenário base, o p90 de duração é {v["lead_p90_h"]} h (mediana {v["lead_mediana_h"]} h). '
                     'Proposta à ID-04: rever as esperas de quem é de fora (H, C, X) nesta jornada e o alvo de prazo dela.')
    if not k:
        L.append('Nenhum papel passou de 85% de ocupação e nenhuma proposta foi gerada.')
    open(os.path.join(AQUI, 'resultado', 'propostas.md'), 'w', encoding='utf-8').write('\n'.join(L) + '\n')
    print('propostas', k)


if __name__ == '__main__':
    main()
