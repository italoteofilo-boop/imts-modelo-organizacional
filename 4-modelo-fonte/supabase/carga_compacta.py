# -*- coding: utf-8 -*-
"""Gera a carga em lotes compactos (jsonb_to_recordset), para aplicar por partes no Supabase.
Mesmo conteúdo do 002_carga.sql. Escreve supabase/lotes/NN_<tabela>.sql. Uso: python3 supabase/carga_compacta.py"""
import json, os, re, glob

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, 'supabase', 'lotes')
MODS = ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9']
LIM = 90000


def tabela_md(texto, cab):
    i = texto.index(cab)
    out = []
    for l in texto[i:].split('\n')[2:]:
        if not l.startswith('|'):
            break
        out.append([c.strip() for c in l.strip().strip('|').split('|')])
    return out


def main():
    T = {k: [] for k in ['executor_tipo', 'circulo', 'dominio', 'fonte', 'fonte_uso', 'decisao_registrada', 'limite', 'jornada',
                         'jornada_fonte', 'evento', 'etapa', 'tarefa', 'decisao_caminho', 'entrada', 'saida', 'troca', 'cadeia',
                         'cadeia_elo', 'achado_auditoria', 'parametro', 'gate']}
    T['executor_tipo'] = [dict(codigo=c, nome=n, e_pessoa=p, e_maquina=m) for c, n, p, m in
                          [('P', 'Pessoa do círculo', True, False), ('A', 'Agente', False, True), ('R', 'Automação', False, True),
                           ('H', 'Pessoa de fora do círculo', True, False), ('C', 'Outro círculo', False, False), ('X', 'Assessoria', True, False)]]
    aud = json.load(open(os.path.join(BASE, 'saida', 'auditoria.json'), encoding='utf-8'))
    real = {e['ref']: e['real'] for e in aud['etapas']}
    vistas = set()
    for m in MODS:
        d = json.load(open(os.path.join(BASE, 'saida', m, 'circulo.json'), encoding='utf-8'))
        c = d['circulo']; n = c['num']
        T['circulo'].append(dict(numero=n, nome=c['nome'], sigla=c['sigla'], prefixo=c['pref'], descricao=c['lead'], principio=d['principio'], situacao=c['status']))
        T['dominio'] += [dict(circulo=n, nome=x['nome'], descricao=x['desc']) for x in d['dominios']]
        for k, f in d['fontes'].items():
            if k not in vistas:
                vistas.add(k); T['fonte'].append(dict(chave=k, referencia=f['ref'], conferencia=f['conf'], links=f['links']))
            T['fonte_uso'].append(dict(circulo=n, fonte=k, uso=f['uso']))
        T['decisao_registrada'] += [dict(circulo=n, ordem=i, decisao=x['o'], origem=x['origem'], efeito=x['efeito']) for i, x in enumerate(d['decisoes'], 1)]
        T['limite'] += [dict(circulo=n, ordem=i, texto=x) for i, x in enumerate(d['limites'], 1)]
        for j in d['jornadas']:
            cj = j['code']
            T['jornada'].append(dict(codigo=cj, circulo=n, nome=j['nome'], dominio=j['dominio'], classe=j['classe'], onda=j['onda'], objetivo=j['objetivo'],
                                     frequencia=j['frequencia'], automacao_nivel=j['automacao']['nivel'], automacao_motivo=j['automacao']['motivo'], raias=j['raias']))
            T['jornada_fonte'] += [dict(jornada=cj, fonte=b) for b in j['base']]
            T['evento'] += [dict(jornada=cj, tipo='início', nome=ev['nome'], raia=ev['raia'], gatilho=ev['tipo']) for ev in j['inicios']]
            T['evento'] += [dict(jornada=cj, tipo='fim', nome=(ev if isinstance(ev, str) else ev['nome']), raia=None, gatilho=None) for ev in j['fins']]
            for e in j['etapas']:
                k = dict(jornada=cj, numero=e['n'])
                T['etapa'].append(dict(k, nome=e['nome'], dono=e['dono'], modo=e['modo'], risco=e['risco'], classe_real=real[f"{cj} etapa {e['n']}"]))
                T['tarefa'] += [dict(k, ordem=i, nome=t['nome'], executor=t['exec'], raia=t['raia'], tipo_bpmn=t['tipo'], condicao=t['cond']) for i, t in enumerate(e['tarefas'], 1)]
                T['decisao_caminho'] += [dict(k, ordem=i, pergunta=x['pergunta'], quem=x['quem'], saidas=x['saidas']) for i, x in enumerate(e.get('decisoes') or [], 1)]
                T['entrada'] += [dict(k, produto=x['o'], origem=x['de']) for x in e['entradas']]
                T['saida'] += [dict(k, produto=x['o'], destinos=x['para']) for x in e['saidas']]
    cz = json.load(open(os.path.join(BASE, 'saida', 'cruzamento.json'), encoding='utf-8'))
    T['troca'] = [dict(produto=t['o'], de_circulo=t['de'], para_circulo=t['para'], via=t.get('via'), sai_em=t['sai'], entra_em=t['entra']) for t in cz['trocas']]
    co = json.load(open(os.path.join(BASE, 'saida', 'consolidacao.json'), encoding='utf-8'))
    for x in co['cross']:
        T['cadeia'].append(dict(codigo=x['codigo'], nome=x['nome'], dono=x.get('dono'), nota=x.get('nota'), circulos=x['circulos'], jornadas=x['cadeia']))
        T['cadeia_elo'] += [dict(cadeia=x['codigo'], ordem=i, de_jornada=el['de'], para_jornada=el['para'], produtos=el['produtos']) for i, el in enumerate(x['elos'], 1)]
    T['achado_auditoria'] = [dict(gravidade=a['gravidade'], tipo=a['tipo'], onde=a['onde'], detalhe=a['detalhe']) for a in aud['achados']]
    pm = open(os.path.join(BASE, 'saida', 'revisao', 'parametros_em_aberto.md'), encoding='utf-8').read()
    P = T['parametro']
    P += [dict(tipo='alçada', nome=r[0], onde=r[1], quem_propoe=r[2], quem_decide=r[3], valor=r[4]) for r in tabela_md(pm, '| Alçada | Onde é usada')]
    P += [dict(tipo='cadência', nome=r[0], onde=r[1], quem_propoe=None, quem_decide=r[2], valor=r[3]) for r in tabela_md(pm, '| Jornada | O que tem ciclo')]
    P += [dict(tipo='conteúdo', nome=r[0], onde=r[1], quem_propoe=r[2], quem_decide=r[3], valor=r[4]) for r in tabela_md(pm, '| Conteúdo | Onde é usado')]
    P += [dict(tipo='fonte', nome=r[0], onde=r[1], quem_propoe=None, quem_decide=None, valor=r[2]) for r in tabela_md(pm, '| Fonte | Para quê')]
    gt = open(os.path.join(BASE, 'saida', 'revisao', 'gates_implantacao.md'), encoding='utf-8').read()
    for r in tabela_md(gt, '| Gate | O que entra'):
        cod, nome = r[0].split('. ', 1)
        T['gate'].append(dict(codigo=cod, nome=nome, entra=r[1], quem_fornece=r[2], criterio_saida=r[3], desbloqueia=r[4]))

    COLS = {
        'executor_tipo': 'codigo org.executor, nome text, e_pessoa boolean, e_maquina boolean',
        'circulo': 'numero smallint, nome text, sigla text, prefixo text, descricao text, principio text, situacao text',
        'dominio': 'circulo smallint, nome text, descricao text',
        'fonte': 'chave text, referencia text, conferencia text, links jsonb',
        'fonte_uso': 'circulo smallint, fonte text, uso text',
        'decisao_registrada': 'circulo smallint, ordem smallint, decisao text, origem text, efeito text',
        'limite': 'circulo smallint, ordem smallint, texto text',
        'jornada': 'codigo text, circulo smallint, nome text, dominio text, classe text, onda smallint, objetivo text, frequencia text, automacao_nivel text, automacao_motivo text, raias text[]',
        'jornada_fonte': 'jornada text, fonte text',
        'evento': 'jornada text, tipo text, nome text, raia text, gatilho text',
        'etapa': 'jornada text, numero smallint, nome text, dono text, modo org.modo, risco org.risco, classe_real text',
        'troca': 'produto text, de_circulo text, para_circulo text, via text, sai_em text[], entra_em text[]',
        'cadeia': 'codigo text, nome text, dono text, nota text, circulos text[], jornadas text[]',
        'cadeia_elo': 'cadeia text, ordem smallint, de_jornada text, para_jornada text, produtos text[]',
        'achado_auditoria': 'gravidade text, tipo text, onde text, detalhe text',
        'parametro': 'tipo org.tipo_parametro, nome text, onde text, quem_propoe text, quem_decide text, valor text',
        'gate': 'codigo text, nome text, entra text, quem_fornece text, criterio_saida text, desbloqueia text',
    }
    FILHAS = {
        'tarefa': ('ordem smallint, nome text, executor org.executor, raia text, tipo_bpmn text, condicao text', 'ordem, nome, executor, raia, tipo_bpmn, condicao'),
        'decisao_caminho': ('ordem smallint, pergunta text, quem text, saidas jsonb', 'ordem, pergunta, quem, saidas'),
        'entrada': ('produto text, origem text', 'produto, origem'),
        'saida': ('produto text, destinos text[]', 'produto, destinos'),
    }
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, '*.sql')):
        os.remove(f)

    def lotes(rows):
        lote, tam = [], 2
        for r in rows:
            s = len(json.dumps(r, ensure_ascii=False)) + 1
            if lote and tam + s > LIM:
                yield lote; lote, tam = [], 2
            lote.append(r); tam += s
        if lote:
            yield lote

    n = 0
    ordem = ['executor_tipo', 'circulo', 'dominio', 'fonte', 'fonte_uso', 'decisao_registrada', 'limite', 'jornada', 'jornada_fonte', 'evento',
             'etapa', 'tarefa', 'decisao_caminho', 'entrada', 'saida', 'troca', 'cadeia', 'cadeia_elo', 'achado_auditoria', 'parametro', 'gate']
    for t in ordem:
        for lote in lotes(T[t]):
            n += 1
            js = json.dumps(lote, ensure_ascii=False)
            assert '$j$' not in js
            if t in FILHAS:
                cols, lista = FILHAS[t]
                sql = (f"insert into org.{t} (etapa, {lista}) select e.id, {', '.join('x.' + c.strip() for c in lista.split(','))} "
                       f"from jsonb_to_recordset($j${js}$j$::jsonb) as x(jornada text, numero smallint, {cols}) "
                       f"join org.etapa e on e.jornada = x.jornada and e.numero = x.numero;")
            else:
                cols = COLS[t]
                names = ', '.join(c.split()[0] for c in cols.split(', '))
                sql = f"insert into org.{t} ({names}) select {names} from jsonb_to_recordset($j${js}$j$::jsonb) as x({cols});"
            open(os.path.join(OUT, f'{n:02d}_{t}.sql'), 'w', encoding='utf-8').write(sql + '\n')
    tot = sum(os.path.getsize(f) for f in glob.glob(os.path.join(OUT, '*.sql')))
    print('lotes', n, 'bytes', tot, {k: len(v) for k, v in T.items()})


if __name__ == '__main__':
    main()
