# -*- coding: utf-8 -*-
"""Confere se cada linha da tabela de alçadas aprovada tem, no fluxo, a tarefa de quem decide em cada nível.
Critério aprovado em 03/10/2026 (auditoria geral, M1). Lê saida/cN/circulo.json (rode gerar.py antes).
Uso: python3 alcadas_fluxo.py  — sai com código 1 se faltar algum nível."""
import json, os, re, sys

BASE = os.path.dirname(os.path.abspath(__file__))

# alçada -> lista de (jornada, raia exata, início do nome da tarefa)
REGRAS = {
    'Concessão comercial': [('NE-04', 'Executivo da empresa', 'Decidir a concessão negociada acima da alçada de quem vende'),
                            ('NE-04', 'Sócios', 'Decidir a concessão negociada pelos sócios')],
    'Recursos de aposta e limite das unidades': [('ES-04', 'Estratégia · pessoa', 'Decidir o destino da aposta'),
                                                 ('ES-04', 'Sócios', 'Decidir o destino da aposta pelos sócios')],
    'Limite do ajuste de oferta em uso': [('IN-07', 'Inteligência · pessoa', 'Decidir se o pedido é ajuste'),
                                          ('IN-07', 'Inteligência · automação', 'Enviar à Estratégia o pedido de revisão')],
    'Parceria e relação institucional': [('RE-06', 'Sócios', '')],
    'Critérios e limites dos agentes': [('ID-02', 'Sócios', 'Decidir sobre os critérios e os limites novos'),
                                        ('ID-02', 'Governança', 'Conferir os limites dos agentes com as alçadas')],
    'Cobertura de falta de capacidade': [('OP-01', 'Executivo da empresa', '')],
    'Solução e compensação de reclamação': [('OP-04', 'Operações · pessoa', 'Decidir a solução da reclamação'),
                                            ('OP-04', 'Governança', 'Avaliar a responsabilidade e o risco da solução acima da alçada'),
                                            ('OP-04', 'Executivo da empresa', 'Decidir a solução acima da alçada de Operações')],
    'Recurso e remanejamento no orçamento': [('GE-01', 'Executivo da empresa', ''), ('GE-01', 'Administrador do IMTS.OS', ''),
                                            ('GE-01', 'Gestão · automação', 'Registrar o pedido para a revisão do portfólio'), ('GE-01', 'Sócios', 'Decidir o aumento do total do orçamento aprovado')],
    'Ação no ritual de acompanhamento': [('GE-02', 'Líder do círculo', 'Decidir a ação na sua alçada'),
                                         ('GE-02', 'Executivo da empresa', 'Decidir a ação acima da alçada do líder'),
                                         ('GE-02', 'Gestão · automação', 'Levar a mudança de alvo'),
                                         ('GE-02', 'Gestão · automação', 'Abrir o pedido de recurso')],
    'Atraso na cobrança': [('GE-03', 'Executivo da empresa', 'Decidir a suspensão das novas entregas')],
    'Compra fora do orçamento e pagamento': [('GE-04', 'Executivo da empresa', 'Aprovar o pedido fora do orçamento'),
                                             ('GE-04', 'Sócios', 'Aprovar o pedido acima da reserva de contingência'),
                                             ('GE-04', 'Líder do círculo', 'Aprovar o pagamento')],
    # acrescentadas com as jornadas GE-14 e GE-15 e a etapa nova da NE-04 (aprovadas às 21:05 de 03/10/2026)
    'Dívida tributária': [('GE-14', 'Executivo da empresa', 'Decidir o parcelamento ou a transação'), ('GE-14', 'Sócios', 'Decidir o parcelamento ou a transação pelos sócios')],
    'Plano tributário do grupo': [('GE-15', 'Executivo da empresa', 'Aprovar o plano tributário'), ('GE-15', 'Sócios', 'Decidir o plano tributário do grupo')],
    'Margem do contrato fora da política': [('NE-04', 'Executivo da empresa', 'Decidir seguir com a margem fora da política comercial')],
    'Aportes, distribuição e contas': [('GE-05', 'Executivo da empresa', ''), ('GE-05', 'Governança', 'Conferir os poderes'),
                                       ('GE-05', 'Administrador do IMTS.OS', ''), ('GE-05', 'Líder do círculo', '')],
    'Vaga, movimentação e desligamento': [('GE-07', 'Executivo da empresa', ''), ('GE-07', 'Sócios', ''),
                                          ('GE-07', 'Administrador do IMTS.OS', '')],
    'O que a Governança decide sozinha': [('GO-01', 'Governança · pessoa', 'Decidir a regra dentro da alçada da Governança'),
                                          ('GO-01', 'Sócios', 'Decidir a regra')],
    # alçadas da matriz de riscos e da regra 10 dos contratos (aprovadas com as propostas de 13:51)
    'Risco de nota 15 ou mais': [('GO-03', 'Sócios', 'Decidir o tratamento dos riscos de nota 15 ou mais')],
    'Regra 10 dos contratos': [('GO-05', 'Sócios', ''), ('NE-04', 'Sócios', 'Decidir a cláusula de matéria dos sócios')],
    'Dono único da crise': [('GO-08', 'Executivo da empresa', ''), ('GO-08', 'Administrador do IMTS.OS', ''), ('GO-08', 'Sócios', '')],
}


def carregar():
    tarefas = {}
    for n in range(1, 10):
        d = json.load(open(os.path.join(BASE, 'saida', f'c{n}', 'circulo.json'), encoding='utf-8'))
        for j in d['jornadas']:
            tarefas[j['code']] = [t for e in j['etapas'] for t in e['tarefas']]
    prop = open(os.path.join(BASE, 'saida', 'revisao', 'propostas_parametros.md'), encoding='utf-8').read()
    return tarefas, prop[prop.index('## 5. Matéria × órgão'):]


def conferir(tarefas, sec, mostrar=True):
    falhas = 0
    for alc, regras in REGRAS.items():
        for jor, raia, nome in regras:
            if not any(t['raia'] == raia and t['nome'].startswith(nome) for t in tarefas.get(jor, [])):
                falhas += 1
                if mostrar:
                    print(f'FALTA  {alc}: {jor}, {raia}, "{nome}"')
    # cada decisão na raia Sócios precisa estar na tabela matéria × órgão (propostas_parametros.md, seção 5)
    cob = set(re.findall(r'[A-Z]{2}-\d{2}', sec))
    for pref, ini, fim in re.findall(r'([A-Z]{2})-(\d{2}) a [A-Z]{2}-(\d{2})', sec):
        cob.update(f'{pref}-{n:02d}' for n in range(int(ini), int(fim) + 1))
    for j in sorted({j for j, ts in tarefas.items() if any(t['raia'] == 'Sócios' for t in ts)} - cob):
        falhas += 1
        if mostrar:
            print(f'FALTA  matéria × órgão: {j} tem decisão dos sócios e não está na tabela')
    return falhas


def prova(tarefas, sec):
    """Defeitos plantados: o teste tem de achar cada um."""
    import copy
    casos = []
    t1 = copy.deepcopy(tarefas); t1['GE-04'] = [t for t in t1['GE-04'] if t['raia'] != 'Sócios']; casos.append((t1, sec))
    t2 = copy.deepcopy(tarefas); t2['OP-04'] = [t for t in t2['OP-04'] if t['raia'] != 'Governança']; casos.append((t2, sec))
    t3 = copy.deepcopy(tarefas); t3['GO-08'] = [t for t in t3['GO-08'] if t['raia'] != 'Administrador do IMTS.OS']; casos.append((t3, sec))
    casos.append((tarefas, sec.replace('GO-10', 'XX-99')))
    return sum(1 for t, s_ in casos if conferir(t, s_, False) > 0), len(casos)


def main():
    tarefas, sec = carregar()
    falhas = conferir(tarefas, sec)
    det, tot = prova(tarefas, sec)
    total = sum(len(r) for r in REGRAS.values())
    print(f'ALÇADAS: {len(REGRAS)} | NÍVEIS CONFERIDOS: {total} | FALTAS: {falhas} | DEFEITOS PLANTADOS DETECTADOS: {det} de {tot}')
    sys.exit(1 if falhas or det < tot else 0)


if __name__ == '__main__':
    main()
