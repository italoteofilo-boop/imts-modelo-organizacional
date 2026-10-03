# -*- coding: utf-8 -*-
"""Vocabulário comum a todos os círculos do modelo: raias, partes e construtores."""

# raias dos outros círculos e dos papéis (o círculo dono usa <XX>P, <XX>A, <XX>R)
CIRC = {
    'IDE': 'Identidade', 'EST': 'Estratégia', 'INT': 'Inteligência', 'REL': 'Relações', 'NEG': 'Negócios',
    'ITG': 'Integração', 'OPE': 'Operações', 'GES': 'Gestão', 'GOV': 'Governança',
}
PAPEIS = {
    'SOC': 'Sócios', 'EXE': 'Executivo da empresa', 'LCI': 'Líder do círculo', 'LID': 'Líder da equipe',
    'PES': 'Pessoa', 'SOL': 'Solicitante', 'ASS': 'Assessoria externa',
}
# papel (raia) -> parte que gera entrada ou recebe saída
PAPEL_PARTE = {'SOC': 'Sócios', 'EXE': 'Executivos', 'LCI': 'Líderes dos círculos', 'LID': 'Líderes',
               'PES': 'Pessoas', 'SOL': 'Solicitante', 'ASS': 'Assessoria externa'}
# quem pode gerar entrada ou receber saída fora do círculo
PARTES_BASE = ['Identidade', 'Estratégia', 'Inteligência', 'Relações', 'Negócios', 'Integração', 'Operações',
               'Gestão', 'Governança', 'Sócios', 'Executivos', 'Líderes dos círculos', 'Líderes', 'Pessoas',
               'Solicitante', 'Assessoria externa', 'Todos (pessoas e agentes)']
TODOS = 'Todos (pessoas e agentes)'

# como o nome do círculo entra numa frase: (o círculo, do círculo, ao círculo)
ARTIGO = {
    'Identidade': ('a Identidade', 'da Identidade', 'à Identidade'),
    'Estratégia': ('a Estratégia', 'da Estratégia', 'à Estratégia'),
    'Inteligência': ('a Inteligência', 'da Inteligência', 'à Inteligência'),
    'Relações': ('Relações', 'de Relações', 'a Relações'),
    'Negócios': ('Negócios', 'de Negócios', 'a Negócios'),
    'Integração': ('a Integração', 'da Integração', 'à Integração'),
    'Operações': ('Operações', 'de Operações', 'a Operações'),
    'Gestão': ('a Gestão', 'da Gestão', 'à Gestão'),
    'Governança': ('a Governança', 'da Governança', 'à Governança'),
}

_cfg = {}


def configurar(nome, sigla, prefixo):
    """nome: 'Identidade'; sigla: 'ID' (raias IDP, IDA, IDR); prefixo dos códigos: 'ID'."""
    _cfg.update(nome=nome, sigla=sigla, prefixo=prefixo)
    lanes = {f'{sigla}P': f'{nome} · pessoa', f'{sigla}A': f'{nome} · agente', f'{sigla}R': f'{nome} · automação'}
    lanes.update({k: v for k, v in CIRC.items() if v != nome})
    lanes.update(PAPEIS)
    partes = [p for p in PARTES_BASE if p != nome]
    return lanes, partes


def T(nome, lane, tipo=None):
    """Tarefa. tipo: user | manual | service | rule | script | call | task | receive (espera resposta)"""
    sg = _cfg['sigla']
    if lane == sg + 'P':
        ex, tp = 'P', 'user'
    elif lane == sg + 'A':
        ex, tp = 'A', 'service'
    elif lane == sg + 'R':
        ex, tp = 'R', 'script'
    elif lane in CIRC:
        ex, tp = 'C', 'task'
    elif lane == 'ASS':
        ex, tp = 'X', 'task'
    else:
        ex, tp = 'H', 'user'      # pessoa de fora do círculo: sócio, executivo, líder, pessoa, solicitante
    return {'k': 'T', 'nome': nome, 'lane': lane, 'exec': ex, 'tipo': tipo or tp}


def PAR(*ramos):
    return {'k': 'PAR', 'ramos': [list(r) for r in ramos]}


def S(rotulo, destino, via=None):
    return {'rotulo': rotulo, 'destino': destino, 'via': via or []}


def D(pergunta, lane, saidas):
    return {'k': 'D', 'pergunta': pergunta, 'lane': lane, 'saidas': saidas}


def E(nome, dono, modo, risco, entradas, fluxo, saidas):
    return {'nome': nome, 'dono': dono, 'modo': modo, 'risco': risco,
            'entradas': entradas, 'fluxo': fluxo, 'saidas': saidas}


def I(nome, lane, tipo):
    return {'nome': nome, 'lane': lane, 'tipo': tipo}


def F(nome, lane):
    return {'nome': nome, 'lane': lane}
