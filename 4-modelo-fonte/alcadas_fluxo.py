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


def main():
    tarefas = {}
    for n in range(1, 10):
        d = json.load(open(os.path.join(BASE, 'saida', f'c{n}', 'circulo.json'), encoding='utf-8'))
        for j in d['jornadas']:
            tarefas[j['code']] = [t for e in j['etapas'] for t in e['tarefas']]
    falhas = 0
    for alc, regras in REGRAS.items():
        for jor, raia, nome in regras:
            ok = any(t['raia'] == raia and t['nome'].startswith(nome) for t in tarefas.get(jor, []))
            if not ok:
                falhas += 1
                print(f'FALTA  {alc}: {jor}, {raia}, "{nome}"')
    total = sum(len(r) for r in REGRAS.values())
    print(f'ALÇADAS: {len(REGRAS)} | NÍVEIS CONFERIDOS: {total} | FALTAS: {falhas}')
    sys.exit(1 if falhas else 0)


if __name__ == '__main__':
    main()
