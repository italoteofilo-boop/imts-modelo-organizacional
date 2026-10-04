# -*- coding: utf-8 -*-
"""Empacota os fluxos BPMN de cada círculo num zip, com LEIA-ME e a fonte em dados.
Uso: python3 empacotar.py c1 c2"""
import json, os, sys, unicodedata, zipfile

BASE = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.join(BASE, 'saida'))


def sem_acento(t):
    return ''.join(c for c in unicodedata.normalize('NFD', t) if unicodedata.category(c) != 'Mn')


for mod in sys.argv[1:]:
    d = json.load(open(f'{mod}/circulo.json', encoding='utf-8'))
    t = json.load(open(f'{mod}/testes.json', encoding='utf-8'))
    c = d['circulo']
    fonte = {k: v for k, v in d.items() if k != 'bpmn'}
    slug = c['slug']
    with open(f'{mod}/{slug}-fonte.json', 'w', encoding='utf-8') as fh:
        json.dump(fonte, fh, ensure_ascii=False, indent=1)
    pref, n = c['pref'], len(d['jornadas'])
    linhas = [
        f'Círculo {c["num"]} · {c["nome"]} — fluxos em BPMN 2.0',
        f'Situação: {c["status"]}',
        '',
        'Conteúdo',
        f'- bpmn/{pref}-01.bpmn a {pref}-{n:02d}.bpmn: um arquivo por jornada, com o diagrama (raias, etapas, tarefas, decisões).',
        f'- {slug}-fonte.json: a mesma informação em dados (jornadas, etapas, tarefas, entradas, saídas, fontes, testes).',
        '',
        'Jornadas',
    ] + [f'- {j["code"]} · {j["nome"]}' for j in d['jornadas']] + [
        '',
        'Como abrir',
        '- Qualquer ferramenta de BPMN 2.0 lê os arquivos: Camunda Modeler, bpmn.io (demo.bpmn.io) e similares.',
        '- Os fluxos BPMN ficam descritivos (isExecutable="false"): o motor próprio sobre o Supabase lê o desenho e executa, por enquanto em simulação (piloto: Identidade). Falta trocar os adaptadores simulados pelos sistemas reais.',
        '',
        'Como ler',
        '- Cada raia é um papel ou sistema. As três últimas raias são do próprio círculo: pessoa, agente e automação.',
        '- Tarefa de usuário: pessoa. Tarefa manual: conversa ou reunião. Tarefa de serviço: agente. Tarefa de script: automação.',
        '  Tarefa de regra de negócio: decisão por tabela. Atividade de chamada: chama jornada de outro círculo.',
    ] + (['  Tarefa de recebimento: o fluxo espera ali a resposta de outra jornada ou de uma pessoa.']
         if any(tf['tipo'] == 'receive' for j in d['jornadas'] for e in j['etapas'] for tf in e['tarefas']) else []) + [
        '- As caixas tracejadas (grupos) são as etapas da jornada.',
        '',
        'Testes desta versão',
        f'- {t["integridade"]["verificacoes"]} verificações de integridade, {t["integridade"]["problemas"]} falhas.',
        f'- {t["lint"]["arquivos"]} arquivos lidos pelo metamodelo do BPMN 2.0 e conferidos por {t["lint"]["regras"]} regras do bpmnlint: {t["lint"]["apontamentos"]} apontamentos.',
        f'- {t["render"]["arquivos"]} fluxos desenhados no bpmn-js: {t["render"]["avisos"]} avisos; {t["rotulos"]["tarefas"]} nomes de tarefa conferidos, {t["rotulos"]["problemas"]} encobertos ou cortados.',
        f'- Trocas entre os círculos já desenhados: {t["cruzamento"]["trocas"]} produtos conferidos dos dois lados, {t["cruzamento"]["problemas"]} falhas.',
        '',
        'Gerado em 02/10/2026 a partir da fonte única do modelo.',
    ]
    with open(f'{mod}/LEIA-ME.txt', 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(linhas) + '\n')
    zname = f'bpmn-circulo-{c["num"]}-{sem_acento(c["nome"]).lower()}.zip'
    with zipfile.ZipFile(zname, 'w', zipfile.ZIP_DEFLATED) as z:
        for f in sorted(os.listdir(f'{mod}/bpmn')):
            z.write(f'{mod}/bpmn/{f}', f'bpmn/{f}')
        z.write(f'{mod}/LEIA-ME.txt', 'LEIA-ME.txt')
        z.write(f'{mod}/{slug}-fonte.json', f'{slug}-fonte.json')
    print(zname, round(os.path.getsize(zname) / 1024), 'KB', len(zipfile.ZipFile(zname).namelist()), 'arquivos')
