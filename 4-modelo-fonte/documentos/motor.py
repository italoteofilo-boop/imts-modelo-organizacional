"""Motor documental do Ecossistema (E12). Um motor para todos os tipos, marcas e modelos.

pedido (JSON) → validação (recusa) e gates de conteúdo → HTML (template único + modelo + marca; todo texto escapado; sem script e sem rede)
→ regra do terço no navegador → PDF no Chromium (Playwright), em passagens até o sumário bater com as páginas reais →
metadados institucionais e PDF determinístico → gates do PDF (texto visível igual ao pedido, nada a mais, página, sumário, âncoras,
título sozinho, página em branco) → registro da emissão (hashes, versões de modelo e marca, gates, alertas, situação).

Uso: python3 motor.py pedido.json [--saida DIR]      |  python3 motor.py --instalar-fontes
Saídas: <id>.pdf, <id>.html (autocontido) e <id>.emissao.json. Nenhum formato Microsoft.
"""
import base64, copy, datetime as dt, hashlib, html, io, json, os, re, shutil, subprocess, sys, unicodedata
from jinja2 import Environment, FileSystemLoader

AQUI = os.path.dirname(os.path.abspath(__file__))
MODELOS = os.path.join(AQUI, 'modelos'); MARCAS = os.path.join(AQUI, 'marcas'); FONTES = os.path.join(AQUI, 'fontes')
CATALOGO = os.path.join(AQUI, 'tipos', 'catalogo.json')

FORMAIS = {'contratual', 'licitacao', 'ata', 'oficio', 'politica'}
PREMIUM = {'institucional', 'proposta', 'relatorio', 'demonstrativo', 'certificado'}
COM_SUMARIO = {'contratual', 'licitacao', 'politica', 'relatorio', 'institucional'}
COM_CAPA = {'institucional', 'proposta', 'relatorio', 'demonstrativo'}
MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro']
CM = 72 / 2.54  # pontos por centímetro


# ---------- utilidades ----------
def sha(b): return hashlib.sha256(b).hexdigest()
def sem_acento(s): return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')
def compacto(s): return re.sub(r'\s+', '', unicodedata.normalize('NFC', s)).replace('\u00ad', '').casefold()

def inline(s):
    """escapa e aplica a marcação mínima: **negrito** e *itálico*."""
    s = html.escape(str(s), quote=False)
    s = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', s)
    return re.sub(r'(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])', r'<em>\1</em>', s)

def texto_puro(s): return re.sub(r'(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])', r'\1', re.sub(r'\*\*(.+?)\*\*', r'\1', str(s)))

def data_extenso(iso):
    d = dt.date.fromisoformat(iso); return f'{d.day} de {MESES[d.month - 1]} de {d.year}'

def data_br(iso): return dt.date.fromisoformat(iso).strftime('%d/%m/%Y')

def data_uri(caminho):
    ext = os.path.splitext(caminho)[1].lower().lstrip('.'); mime = {'png': 'image/png', 'jpg': 'image/jpeg', 'webp': 'image/webp', 'ttf': 'font/ttf'}[ext]
    return f'data:{mime};base64,' + base64.b64encode(open(caminho, 'rb').read()).decode()


def instalar_fontes():
    dst = os.path.expanduser('~/.local/share/fonts/imts'); os.makedirs(dst, exist_ok=True)
    for f in os.listdir(FONTES):
        if f.endswith('.ttf'): shutil.copy(os.path.join(FONTES, f), dst)
    subprocess.run(['fc-cache', '-f'], check=False, capture_output=True)
    return dst


def fontes_css(familias):
    """@font-face embutido (o HTML de saída é autocontido). Só as famílias que o documento usa."""
    mapa = {'Open Sans': [('Regular', 400, 'normal'), ('Italic', 400, 'italic'), ('SemiBold', 600, 'normal'), ('SemiBoldItalic', 600, 'italic'),
                          ('Bold', 700, 'normal'), ('BoldItalic', 700, 'italic')], 'Michroma': [('Regular', 400, 'normal')]}
    mapa['Poppins'] = [('Regular', 400, 'normal'), ('Italic', 400, 'italic'), ('Medium', '500 600', 'normal'), ('MediumItalic', '500 600', 'italic'),
                       ('Bold', 700, 'normal'), ('BoldItalic', 700, 'italic')]
    css = []
    for fam in familias:
        for suf, w, st in mapa.get(fam, []):
            arq = os.path.join(FONTES, f"{fam.replace(' ', '')}-{suf}.ttf")
            css.append(f"@font-face {{ font-family: '{fam}'; font-weight: {w}; font-style: {st}; src: url({data_uri(arq)}) format('truetype'); }}")
    return '\n'.join(css)


MODELOS_VALIDOS = FORMAIS | PREMIUM
ID_RE = re.compile(r'^[a-z0-9][a-z0-9-]{0,80}$')
TIPOS_BLOCO = {'secao', 'subsecao', 'p', 'item', 'alinea', 'lista', 'citacao', 'nota', 'destaque', 'kpis', 'campos', 'tabela'}
# texto que o próprio motor escreve (rótulos do template); entra no vocabulário do gate de "texto a mais"
TEXTO_DO_MOTOR = ('Sumário Anexo Glossário Legenda Referências normativas Disponível em Verificado TESTEMUNHA Nome CPF Assunto Página de '
                  'Emissão Emitente Capa ' + ' '.join(MESES) + ' I II III IV V VI VII VIII IX X XI XII')
# chaves que não são texto do documento (não passam por inline)
NAO_TEXTO = {'_modelo', '_marca_dados', 't', 'tipo', 'marca', 'modelo', 'id', 'data', 'verificado_em', 'longa', 'total', 'esq', 'densa', 'ordenada', 'sumario', 'capa',
             'titulo_linhas', 'testemunhas', 'pedido', 'empresa'}


# ---------- validação (recusa antes de renderizar) ----------
def validar(p, cat):
    erros = []
    def exige(cond, msg):
        if not cond: erros.append(msg)
    for k in ('tipo', 'marca', 'titulo', 'data', 'local'):
        exige(isinstance(p.get(k), str) and p.get(k).strip(), f'campo obrigatório ausente: {k}')
    if erros: return erros
    exige(p['tipo'] in cat, f"tipo desconhecido no catálogo: {p['tipo']}")
    exige(bool(re.fullmatch(r'[a-z0-9-]+', p['marca'])) and os.path.exists(os.path.join(MARCAS, p['marca'], 'marca.json')), f"marca sem pacote: {p['marca']}")
    if p.get('id') is not None: exige(isinstance(p['id'], str) and bool(ID_RE.match(p['id'])), 'id fora do padrão (minúsculas, dígitos e hífen)')
    if p.get('modelo') is not None: exige(p['modelo'] in MODELOS_VALIDOS, f"modelo desconhecido: {p.get('modelo')}")
    try: dt.date.fromisoformat(p['data'])
    except ValueError: erros.append('data fora do formato AAAA-MM-DD')
    def pares(x, nome):
        exige(isinstance(x, list) and all(isinstance(r, (list, tuple)) and len(r) == 2 and all(isinstance(v, str) for v in r) for r in x), f'{nome}: cada linha com dois textos')
    def blocos(bs, onde):
        exige(isinstance(bs, list), f'{onde}: blocos em lista')
        for b in bs if isinstance(bs, list) else []:
            t = b.get('t') if isinstance(b, dict) else None
            if t not in TIPOS_BLOCO: erros.append(f'{onde}: bloco de tipo desconhecido: {t}'); continue
            if t in ('secao', 'subsecao'): exige(isinstance(b.get('titulo'), str) and b['titulo'].strip(), f'{onde}: {t} sem título')
            if t in ('p', 'nota', 'citacao', 'destaque'): exige(isinstance(b.get('texto'), str) and b['texto'].strip(), f'{onde}: {t} sem texto')
            if t == 'item': exige(isinstance(b.get('n'), str) and isinstance(b.get('texto'), str), f'{onde}: item sem número ou texto')
            if t == 'alinea': exige(isinstance(b.get('m'), str) and isinstance(b.get('texto'), str), f'{onde}: alínea sem marcador ou texto')
            if t == 'lista': exige(isinstance(b.get('itens'), list) and all(isinstance(i, str) for i in b['itens']) and b['itens'], f'{onde}: lista sem itens')
            if t == 'kpis': exige(isinstance(b.get('itens'), list) and all(isinstance(i, dict) and 'valor' in i and 'rotulo' in i for i in b['itens']), f'{onde}: indicadores com valor e rótulo')
            if t == 'campos': pares(b.get('itens'), f'{onde}: campos')
            if t == 'tabela':
                cab = b.get('cab'); linhas = b.get('linhas')
                exige(isinstance(cab, list) and cab and isinstance(linhas, list), f'{onde}: tabela sem cabeçalho ou linhas')
                if isinstance(cab, list) and isinstance(linhas, list):
                    exige(all(isinstance(l, list) and len(l) == len(cab) for l in linhas), f"{onde}: tabela com linhas de tamanho diferente do cabeçalho: {b.get('nome')}")
                exige(all(isinstance(i, int) for i in b.get('esq', [])), f'{onde}: colunas à esquerda por índice')
    blocos(p.get('blocos') or [], 'corpo')
    if p.get('campos') is not None: pares(p['campos'], 'campos')
    for i, a in enumerate(p.get('anexos') or []):
        exige(isinstance(a, dict) and isinstance(a.get('titulo'), str) and a['titulo'].strip(), f'anexo {i + 1} sem título')
        if isinstance(a, dict): blocos(a.get('blocos') or [], f'anexo {i + 1}')
    pf = p.get('parte_final') or {}
    for k in ('glossario', 'legenda'):
        if pf.get(k) is not None: pares(pf[k], k)
    for r in pf.get('referencias') or []:
        exige(isinstance(r, dict) and all(isinstance(r.get(k), str) for k in ('norma', 'fonte', 'verificado_em')), 'referência com norma, fonte e data de verificação')
        try: dt.date.fromisoformat(r.get('verificado_em', ''))
        except (ValueError, TypeError): erros.append('referência com data de verificação fora do formato')
    ass = p.get('assinaturas')
    if ass is not None:
        exige(isinstance(ass, dict) and isinstance(ass.get('partes'), list) and ass['partes'], 'assinaturas sem partes')
        for pt in (ass.get('partes') or []) if isinstance(ass, dict) else []:
            exige(isinstance(pt, dict) and isinstance(pt.get('nome'), str), 'parte sem nome')
    modelo = p.get('modelo') or (cat.get(p['tipo']) or {}).get('modelo')
    if modelo == 'certificado':
        c = p.get('certificado') or {}
        exige(all(isinstance(c.get(k), str) for k in ('preambulo', 'concedido_a', 'texto')), 'certificado: preâmbulo, nome e texto')
        exige(isinstance(ass, dict), 'certificado: assinaturas')
    if modelo == 'oficio':
        exige(isinstance(p.get('destinatario'), dict) and isinstance(p.get('assunto'), str) and isinstance(p.get('referencia'), str), 'ofício: referência, destinatário e assunto')
    return erros


# ---------- textos do pedido ----------
def textos_do_pedido(p):
    """(texto, contíguo) de tudo o que o pedido manda escrever. Contíguo = um parágrafo que tem de sair inteiro e na ordem;
    não contíguo = texto em colunas lado a lado (tabela, indicadores, campos, assinaturas), que a extração pode intercalar."""
    out = []
    def add(t, cont=True):
        if t: out.append((texto_puro(t), cont))
    add(p.get('titulo'))
    def de_blocos(bs):
        for b in bs or []:
            if b['t'] in ('secao', 'subsecao'): add(b.get('titulo'))
            elif b['t'] in ('p', 'nota', 'citacao'): add(b.get('texto'))
            elif b['t'] in ('item', 'alinea'): add(b.get('n') or b.get('m'), False); add(b.get('texto'))
            elif b['t'] == 'destaque': add(b.get('titulo')); add(b.get('texto'))
            elif b['t'] == 'lista': [add(i) for i in b['itens']]
            elif b['t'] == 'kpis': [add(str(v), False) for i in b['itens'] for v in (i['valor'], i['rotulo'])]
            elif b['t'] == 'campos': [add(v, False) for r in b['itens'] for v in r]
            elif b['t'] == 'tabela':
                add(b.get('nome')); [add(c, False) for c in b['cab']]; [add(c, False) for l in b['linhas'] for c in l]
    for r in p.get('campos') or []: [add(v, False) for v in r]
    de_blocos(p.get('blocos'))
    for a in p.get('anexos') or []: add(a.get('titulo')); de_blocos(a.get('blocos'))
    pf = p.get('parte_final') or {}
    for g in (pf.get('glossario') or []) + (pf.get('legenda') or []): add(g[0] + ': ' + g[1])
    for r in pf.get('referencias') or []: add(r['norma']); add(r['fonte'], False)
    ass = p.get('assinaturas') or {}
    for pt in ass.get('partes', []):
        for k in ('papel', 'razao', 'nome', 'cargo', 'cpf'):
            if pt.get(k): add(str(pt[k]), False)
    if ass.get('nota'): add(ass['nota'])
    modelo = p.get('_modelo')
    imprime_local = bool(p.get('assinaturas')) or modelo in ('oficio', 'certificado') or (modelo in COM_CAPA and p.get('capa', True) is not False)
    for k in ('assunto', 'referencia', 'subtitulo'):
        if p.get(k): add(p[k])
    if p.get('emitente') and modelo in COM_CAPA and p.get('capa', True) is not False: add(p['emitente'])
    if p.get('local') and imprime_local: add(p['local'], False)
    for v in (p.get('destinatario') or {}).values(): add(str(v), False)
    for v in (p.get('certificado') or {}).values(): add(str(v))
    return out


def gates_conteudo(p, tipo, modelo):
    """gates sobre o pedido, antes de renderizar."""
    res = []
    def g(nome, onde, nivel='bloqueia'): res.append({'gate': nome, 'onde': str(onde)[:80], 'nivel': nivel})
    textos = [t for t, _ in textos_do_pedido(p)] + [p.get('tipo', ''), tipo['nome']]
    for t in textos:
        if '[●' in t: g('campo pendente [●]', t)
        if '\u2014' in t: g('travessão longo (—) em texto', t)
        if '\u00ad' in t: g('hífen suave (quebra de palavra) no texto', t)
        if any(x in t for x in ('{{', '{%', '%}', '}}')): g('sinal de modelo ({{ }} ou {% %})', t)
        if re.search(r'\b(v|vers[aã]o|rev\.?)\s?\d+(\.\d+)*\b', t, re.I): g('número de versão no documento (a versão é a data de vigência e de revisão)', t)
    if modelo == 'contratual':
        ass = p.get('assinaturas') or {}
        if (ass.get('testemunhas') or 0) < 2: g('contrato sem duas testemunhas', 'assinaturas')
        if not ass.get('nota'): g('contrato sem a nota de assinatura física e eletrônica', 'assinaturas')
        # remissões internas: cláusula, item e anexo citados existem
        todos = (p.get('blocos') or []) + [x for a in p.get('anexos') or [] for x in a.get('blocos', [])]
        clausulas = {m.group(1) for b in p.get('blocos') or [] if b['t'] == 'secao' for m in [re.search(r'Cl[aá]usula (\d+)', b['titulo'])] if m}
        itens = {b['n'].rstrip('.') for b in todos if b['t'] == 'item'}
        n_anexos = len(p.get('anexos') or [])
        for b in todos:
            t = b.get('texto') or ''
            for m in re.finditer(r'Cl[aá]usula (\d+)[ªa]', t):
                if m.group(1) not in clausulas: g('remissão a cláusula inexistente', m.group(0))
            for m in re.finditer(r'\bitem (\d+(?:\.\d+)+)', t):
                if m.group(1) not in itens: g('remissão a item inexistente', m.group(0))
            for m in re.finditer(r'\bAnexo ([IVX]+)\b', t):
                if m.group(1) not in ROMANOS[:n_anexos]: g('remissão a anexo inexistente', m.group(0))
        # definições em ordem alfabética (alerta)
        em_def = False; termos = []
        for b in p.get('blocos') or []:
            if b['t'] == 'secao': em_def = 'defini' in b['titulo'].lower()
            elif em_def and b['t'] == 'item':
                m = re.match(r'\*\*(.+?)[:*]', b['texto'])
                if m: termos.append(sem_acento(m.group(1)).lower())
        if termos != sorted(termos): g('definições fora da ordem alfabética', ', '.join(termos), 'alerta')
    # quadros em numeração única e crescente (alerta)
    nums = [int(m.group(1)) for b in (p.get('blocos') or []) + [x for a in p.get('anexos') or [] for x in a.get('blocos', [])]
            if b['t'] == 'tabela' and b.get('nome') for m in [re.match(r'(?:Quadro|Tabela) (\d+)', texto_puro(b['nome']))] if m]
    if nums and nums != list(range(1, len(nums) + 1)): g('quadros fora da numeração única', str(nums), 'alerta')
    # citação normativa conferida há no máximo 30 dias (alerta)
    for r in (p.get('parte_final') or {}).get('referencias') or []:
        if (dt.date.fromisoformat(p['data']) - dt.date.fromisoformat(r['verificado_em'])).days > 30: g('referência normativa conferida há mais de 30 dias', r['norma'], 'alerta')
    return res


# ---------- preparação do HTML ----------
def esc_profundo(x, chave=None):
    """escapa todo texto do pedido (com **negrito** e *itálico*); valores de controle ficam como estão."""
    if chave in NAO_TEXTO: return x
    if isinstance(x, str): return inline(x)
    if isinstance(x, list): return [esc_profundo(v) for v in x]
    if isinstance(x, dict): return {k: esc_profundo(v, k) for k, v in x.items()}
    return x


def agrupar(bs):
    """título preso ao que introduz: secao/subsecao + bloco seguinte num grupo indivisível (exceto tabela longa)."""
    grupos, i = [], 0
    while i < len(bs):
        b = bs[i]
        if b['t'] in ('secao', 'subsecao') and i + 1 < len(bs) and not bs[i + 1].get('longa'):
            j = i + 1
            if bs[j]['t'] == 'subsecao' and j + 1 < len(bs) and not bs[j + 1].get('longa'): j += 1
            grupos.append({'preso': bs[i:j + 1]}); i = j + 1
        else: grupos.append(b); i += 1
    return grupos


ROMANOS = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII']


def itens_sumario(p, modelo):
    itens = [texto_puro(b['titulo']) for b in p.get('blocos') or [] if b['t'] == 'secao']
    itens += [f"Anexo {ROMANOS[i]} – {texto_puro(a['titulo'])}" for i, a in enumerate(p.get('anexos') or [])]
    pf = p.get('parte_final') or {}
    itens += [n for k, n in (('glossario', 'Glossário'), ('legenda', 'Legenda'), ('referencias', 'Referências normativas')) if pf.get(k)]
    return itens if (p.get('sumario', modelo in COM_SUMARIO) and len(itens) >= 3) else []


def pagina_css(p, marca, tipo, modelo):
    """@page por modelo. Formais: margens para o quadro de controle (desenhado pelo Chromium). Premium: caixas de margem do CSS,
    com a capa numa página nomeada sem margens. Certificado: A4 paisagem sem margens."""
    if modelo == 'certificado': return '@page { size: A4 landscape; margin: 0; }'
    if modelo in FORMAIS: return '@page { size: A4; }'
    c = marca['cores']; fam = marca['tipografia']['texto']
    q = lambda s: '"' + str(s).replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ') + '"'
    logo = data_uri(os.path.join(MARCAS, marca['id'], marca['logos']['horizontal'])) if marca.get('logos') else None
    topo_esq = (f'@top-left {{ content: ""; background: url({logo}) no-repeat left bottom / auto 0.95cm; width: 3.2cm; }}' if logo
                else f'@top-left {{ content: {q(marca["nome"])}; font: 700 10pt "{fam}"; color: {c["primaria"]}; vertical-align: bottom; }}')
    return (f'@page {{ size: A4; margin: 2.3cm 1.8cm 2.0cm 1.8cm; {topo_esq} '
            f'@top-right {{ content: {q(texto_puro(p["titulo"]))}; font: 8.5pt "{fam}"; color: {c["texto"]}; vertical-align: bottom; }} '
            f'@bottom-left {{ content: {q(marca["autor_institucional"] + " · " + tipo["nome"])}; font: 7.5pt "{fam}"; color: {c["texto"]}; }} '
            f'@bottom-right {{ content: counter(page) " de " counter(pages); font: 7.5pt "{fam}"; color: {c["texto"]}; }} }} '
            '@page capa { margin: 0; @top-left { content: none; background: none; } @top-right { content: none; } @bottom-left { content: none; } @bottom-right { content: none; } }')


def montar(p, marca, tipo, modelo, sumario_paginas=None):
    """devolve (html_documento, itens_do_sumário, tem_capa)."""
    env = Environment(loader=FileSystemLoader(MODELOS), autoescape=False, trim_blocks=False)
    tpl = env.get_template('documento.html.j2')
    c = marca['cores']
    fam_txt = marca['tipografia']['texto']; fam_disp = marca['tipografia']['display']
    tokens = {'--cor-primaria': c['primaria'], '--cor-texto': c['texto'], '--cor-destaque': c['destaque'], '--cor-apoio': c['apoio'],
              '--cor-barra': c['barra'], '--cor-linha': c['linha'], '--cor-claro': c.get('claro', '#F2F4F7'),
              '--cor-capa': c['primaria'], '--cor-acento-capa': c['destaque'] if c['destaque'] != c['primaria'] else '#FFFFFF',
              '--fonte-texto': f"'{fam_txt}', {marca['tipografia']['fallback']}",
              '--fonte-display': f"'{fam_disp if modelo in PREMIUM else fam_txt}', {marca['tipografia']['fallback']}"}
    familias = sorted({fam_txt} | ({fam_disp} if modelo in PREMIUM else set()))
    d = esc_profundo(copy.deepcopy(p))
    d['blocos'] = agrupar(d.get('blocos') or [])
    for i, a in enumerate(d.get('anexos') or []):
        a['numero'] = ROMANOS[i]; a['blocos'] = agrupar(a.get('blocos') or [])
    for r in (d.get('parte_final') or {}).get('referencias') or []: r['verificado_br'] = data_br(r['verificado_em'])
    itens = itens_sumario(p, modelo)
    sumario = [{'titulo': html.escape(t), 'pagina': (sumario_paginas[i] if sumario_paginas else '00')} for i, t in enumerate(itens)] or None
    logo = data_uri(os.path.join(MARCAS, marca['id'], marca['logos']['horizontal'])) if marca.get('logos') else None
    logo_neg = data_uri(os.path.join(MARCAS, marca['id'], marca['logos']['horizontal_negativo'])) if marca.get('logos') else None
    capa = modelo in COM_CAPA and p.get('capa', True) is not False
    doc = tpl.render(d=d, m=marca, tokens=tokens, css=open(os.path.join(MODELOS, 'base.css')).read(), fontes_css=fontes_css(familias),
                     pagina_css=pagina_css(p, marca, tipo, modelo), classe='formal' if modelo in FORMAIS else 'premium', modelo=modelo,
                     sumario=sumario, data_extenso=data_extenso(p['data']), data_br=data_br(p['data']), logo=logo, logo_negativo=logo_neg, capa=capa,
                     marca_nome=html.escape(marca['nome']), marca_dagua=html.escape(marca.get('marca_dagua') or ''), autor=html.escape(marca['autor_institucional']),
                     autor_attr=html.escape(marca['autor_institucional'], quote=True), tipo_nome=html.escape(tipo['nome']))
    return doc, itens, capa


# ---------- quadro de controle e rodapé de aprovação dos formais (Chromium desenha fora da página; só fontes do sistema) ----------
def cabecalho_rodape(p, marca, tipo, modelo):
    if modelo not in FORMAIS: return None, None, None
    c = marca['cores']; fam = marca['tipografia']['texto']
    estilo = f"font-family:'{fam}',sans-serif;color:{c['texto']};-webkit-print-color-adjust:exact;"
    logo = data_uri(os.path.join(MARCAS, marca['id'], marca['logos']['horizontal'])) if marca.get('logos') else None
    marca_html = f'<img src="{logo}" style="height:0.95cm">' if logo else f'<span style="font-weight:700;font-size:11pt;color:{c["primaria"]}">{html.escape(marca["nome"])}</span>'
    linhas_nome = p.get('titulo_linhas') or [texto_puro(p['titulo'])]
    nome = '<br>'.join(f'<b>{html.escape(texto_puro(l))}</b>' for l in linhas_nome)
    emitente = html.escape(texto_puro(p.get('emitente') or marca['autor_institucional']))
    cab = (f'<div style="{estilo}width:100%;padding:0 1.6cm;font-size:10.5pt;line-height:1.22;">'
           f'<table style="width:100%;border-collapse:collapse;border-bottom:.6pt solid {c["linha"]};"><tr>'
           f'<td style="width:24%;vertical-align:middle;padding:0 0 4pt;">{marca_html}</td>'
           f'<td style="vertical-align:middle;padding:0 8pt 4pt;"><i>{html.escape(tipo["nome"])}</i><br>{nome}</td>'
           f'<td style="width:24%;vertical-align:middle;text-align:right;padding:0 0 4pt;"><i>Emitente</i> <b>{emitente}</b><br>'
           f'<i>Emissão</i> <b>{data_br(p["data"])}</b><br><i>Página</i> <b><span class="pageNumber"></span> de <span class="totalPages"></span></b></td></tr></table></div>')
    rf = marca['rodape_aprovacao']
    cel = lambda xs, b: ''.join(f'<td style="width:33.3%;text-align:center;{"font-weight:700;" if b else ""}">{html.escape(x)}</td>' for x in xs)
    rod = (f'<div style="{estilo}width:100%;padding:0 1.6cm;font-size:7pt;line-height:1.3;">'
           f'<table style="width:100%;border-collapse:collapse;border-top:.6pt solid {c["linha"]};"><tr>{cel(rf["etapas"], True)}</tr><tr>{cel(rf["areas"], False)}</tr></table></div>')
    return cab, rod, {'top': '3.0cm', 'bottom': '1.9cm', 'left': '1.6cm', 'right': '1.6cm'}


# corpo (região entre as margens) por modelo, em cm: (superior, inferior, laterais)
CORPO = {'formal': (3.0, 1.9, 1.6), 'premium': (2.3, 2.0, 1.8), 'certificado': (0, 0, 0)}
def grupo(modelo): return 'certificado' if modelo == 'certificado' else ('formal' if modelo in FORMAIS else 'premium')


# ---------- renderização ----------
def renderizar(navegador, html_doc, modelo, cab, rod, margens):
    sup, inf, lat = CORPO[grupo(modelo)]
    larg_cm = (29.7 if modelo == 'certificado' else 21.0) - 2 * lat
    pg = navegador.new_page(viewport={'width': round(larg_cm * 96 / 2.54), 'height': 1100})
    try:
        pg.route('**/*', lambda r: r.abort())          # nenhuma rede: o documento é autocontido
        pg.emulate_media(media='print')
        pg.set_content(html_doc, wait_until='load', timeout=20000)
        pg.evaluate('document.fonts.ready')
        ajuste = pg.evaluate(open(os.path.join(MODELOS, 'ajuste.js')).read())
        opts = dict(print_background=True, outline=True, tagged=True)
        if modelo in FORMAIS: opts.update(format='A4', margin=margens, display_header_footer=True, header_template=cab, footer_template=rod)
        else: opts.update(prefer_css_page_size=True, display_header_footer=False)
        return pg.pdf(**opts), ajuste, pg.content()
    finally:
        pg.close()


def paginas_dos_marcadores(pdf_bytes):
    from pypdf import PdfReader
    r = PdfReader(io.BytesIO(pdf_bytes)); out = []
    def andar(ol):
        for o in ol:
            if isinstance(o, list): andar(o)
            else: out.append((re.sub(r'\s+', ' ', o.title).strip(), r.get_destination_page_number(o) + 1))
    andar(r.outline)
    return out


def casar_sumario(itens, marcadores):
    """liga cada item do sumário ao marcador correspondente, na ordem (anexo: o marcador é 'ANEXO N')."""
    pags, j = [], 0
    for it in itens:
        alvo = sem_acento(it).lower()
        m = re.match(r'anexo ([ivx]+) –', alvo)
        chave = f'anexo {m.group(1)}' if m else alvo
        while j < len(marcadores) and sem_acento(marcadores[j][0]).lower() != chave: j += 1
        if j >= len(marcadores): return None
        pags.append(marcadores[j][1]); j += 1
    return pags


def metadados(pdf_bytes, marca, p, tipo, html_final):
    """metadados institucionais e PDF determinístico: datas da emissão e identificador derivado do HTML final."""
    from pypdf import PdfReader, PdfWriter
    from pypdf.generic import ArrayObject, ByteStringObject, NameObject
    r = PdfReader(io.BytesIO(pdf_bytes)); w = PdfWriter(clone_from=r)
    quando = 'D:' + p['data'].replace('-', '') + "000000-03'00'"
    w.add_metadata({'/Title': texto_puro(p['titulo']), '/Author': marca['autor_institucional'], '/Subject': tipo['nome'],
                    '/Creator': 'Motor documental do Ecossistema', '/Producer': 'Chromium (Playwright) e pypdf',
                    '/CreationDate': quando, '/ModDate': quando})
    w._root_object[NameObject('/Lang')] = __import__('pypdf').generic.TextStringObject('pt-BR')
    # o Chromium numera os elementos da estrutura de acessibilidade com um contador que cresce a cada página aberta no mesmo
    # navegador; renumera mantendo a ordem (a árvore de nomes /IDTree continua ordenada) para o PDF sair igual a cada emissão
    from pypdf.generic import DictionaryObject, TextStringObject, ByteStringObject as BS, IndirectObject
    elems = []
    for o in w._objects:
        if isinstance(o, DictionaryObject) and o.get('/Type') == '/StructElem' and '/ID' in o: elems.append(o)
    antigos = sorted({str(o['/ID']) for o in elems})
    novo = {a: f'n{i:08d}' for i, a in enumerate(antigos)}
    for o in elems: o[NameObject('/ID')] = TextStringObject(novo[str(o['/ID'])])
    # células de tabela apontam para os cabeçalhos pelo mesmo identificador (/A … /Headers)
    for o in w._objects:
        if isinstance(o, DictionaryObject) and o.get('/Type') == '/StructElem' and '/A' in o:
            atribs = o['/A'] if isinstance(o['/A'], list) else [o['/A']]
            for at in atribs:
                at = at.get_object() if isinstance(at, IndirectObject) else at
                if isinstance(at, DictionaryObject) and '/Headers' in at:
                    at[NameObject('/Headers')] = ArrayObject([TextStringObject(novo.get(str(x), str(x))) for x in at['/Headers']])
    def arvore(no):
        no = no.get_object() if isinstance(no, IndirectObject) else no
        if '/Names' in no:
            arr = no['/Names']
            for k in range(0, len(arr), 2):
                if str(arr[k]) in novo: arr[k] = TextStringObject(novo[str(arr[k])])
        if '/Limits' in no:
            no[NameObject('/Limits')] = ArrayObject([TextStringObject(novo.get(str(x), str(x))) for x in no['/Limits']])
        for kid in no.get('/Kids', []): arvore(kid)
    raiz = w._root_object.get('/StructTreeRoot')
    if raiz is not None and '/IDTree' in raiz.get_object(): arvore(raiz.get_object()['/IDTree'])
    ident = hashlib.md5(html_final.encode()).digest()
    w._ID = ArrayObject([ByteStringObject(ident), ByteStringObject(ident)])
    b = io.BytesIO(); w.write(b); return b.getvalue()


# ---------- gates do PDF ----------
def palavras(s): return re.findall(r'\w+', unicodedata.normalize('NFC', html.unescape(s)).casefold())

def contiguo(alvo, fichas):
    n = len(alvo)
    return any(fichas[i:i + n] == alvo for i in range(len(fichas) - n + 1) if fichas[i] == alvo[0])

def em_janela(alvo, fichas):
    """para texto em colunas: todas as palavras, na ordem, numa janela curta."""
    n = len(alvo)
    for i in range(len(fichas) - n + 1):
        if fichas[i] == alvo[0]:
            j, k = i, 0
            while j < len(fichas) and j < i + 3 * n + 12 and k < n:
                if fichas[j] == alvo[k]: k += 1
                j += 1
            if k == n: return True
    return False


def _visivel(o):
    """caractere que uma pessoa vê: não girado (marca d'água), com corpo de 2 pt ou mais (âncoras têm 1 pt) e não branco."""
    if o.get('object_type') != 'char': return True
    if not (o.get('upright', True) and abs(o['matrix'][1]) < 0.01) or o.get('size', 0) < 2: return False
    cor = o.get('non_stroking_color')
    if isinstance(cor, (list, tuple)) and cor:
        if len(cor) == 1 and cor[0] >= 0.97: return False
        if len(cor) == 3 and min(cor) >= 0.97: return False
        if len(cor) == 4 and max(cor) <= 0.03: return False
    return True


def gates_pdf(pdf_bytes, p, marca, tipo, modelo, itens, pags_impressas, tem_capa):
    import pdfplumber
    from pypdf import PdfReader
    res = []
    def g(nome, onde=''): res.append({'gate': nome, 'nivel': 'bloqueia', 'onde': str(onde)[:120]})
    r = PdfReader(io.BytesIO(pdf_bytes)); meta = r.metadata or {}
    if meta.get('/Author') != marca['autor_institucional']: g('metadados: autor institucional', meta.get('/Author'))
    if meta.get('/Title') != texto_puro(p['titulo']): g('metadados: título', meta.get('/Title'))
    if meta.get('/Subject') != tipo['nome']: g('metadados: assunto', meta.get('/Subject'))
    sup, inf, _ = CORPO[grupo(modelo)]
    corpo_txt, bruto, titulos = [], '', {compacto(t) for t in itens}
    titulos |= {compacto(texto_puro(b['titulo'])) for b in (p.get('blocos') or []) + [x for a in p.get('anexos') or [] for x in a.get('blocos', [])] if b['t'] in ('secao', 'subsecao')}
    titulos |= {compacto(texto_puro(b['nome'])) for b in (p.get('blocos') or []) + [x for a in p.get('anexos') or [] for x in a.get('blocos', [])] if b['t'] == 'tabela' and b.get('nome')}
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for i, pg in enumerate(pdf.pages):
            w_, h_ = float(pg.width), float(pg.height)
            if modelo == 'certificado' and not w_ > h_: g('página fora da orientação do modelo (paisagem)', f'página {i + 1}: {w_:.0f} x {h_:.0f}')
            if modelo != 'certificado' and not (abs(w_ - 595.3) < 2 and abs(h_ - 841.9) < 2): g('página fora do formato A4 retrato', f'página {i + 1}: {w_:.0f} x {h_:.0f}')
            bruto += (pg.extract_text() or '') + '\n'
            capa = tem_capa and i == 0
            vis = pg.filter(_visivel) if not capa else pg.filter(lambda o: o.get('object_type') != 'char' or (o.get('upright', True) and abs(o['matrix'][1]) < 0.01 and o.get('size', 0) >= 2))
            corpo = vis if (capa or modelo == 'certificado') else vis.crop((0, sup * CM - 2, w_, h_ - inf * CM + 2))
            corpo_txt.append(corpo.extract_text() or '')
            if capa: continue
            palavras_pg = [w for w in corpo.extract_words() if w.get('upright', True)]
            if not palavras_pg: g('página em branco', f'página {i + 1}'); continue
            linhas = {}
            for w in palavras_pg: linhas.setdefault(round(w['top'] / 3), []).append(w)
            ordem = [' '.join(x['text'] for x in sorted(linhas[k], key=lambda w: w['x0'])) for k in sorted(linhas)]
            ult = compacto(ordem[-1]); ult2 = compacto(' '.join(ordem[-2:])) if len(ordem) > 1 else ult
            if i < len(pdf.pages) - 1 and (ult in titulos or ult2 in titulos):
                g('título sozinho no fim da página', f'página {i + 1}: {ordem[-1][:60]}')
    fichas = palavras('\n'.join(corpo_txt))
    sem_espaco = compacto('\n'.join(corpo_txt))
    # 1. tudo o que o pedido manda escrever está visível; parágrafo contíguo (D03/D04). Título em fonte de exibição, com letras
    #    espaçadas, sai separado na extração: a conferência sem espaços (ainda contígua e na ordem) cobre esse caso.
    for t, cont in textos_do_pedido(p):
        if modelo == 'oficio' and t == texto_puro(p['titulo']): continue
        alvo = palavras(t)
        if not alvo: continue
        ok = (contiguo(alvo, fichas) if cont else em_janela(alvo, fichas)) or compacto(html.unescape(t)) in sem_espaco
        if not ok: g('texto do PDF diferente dos blocos (faltando, escondido ou fora de ordem)', t)
    # 2. nada além do pedido e dos rótulos do motor (D01: texto acrescentado)
    vocab = set(palavras(' '.join(t for t, _ in textos_do_pedido(p)) + ' ' + TEXTO_DO_MOTOR + ' ' + marca['nome'] + ' ' + marca['autor_institucional'] + ' '
                         + tipo['nome'] + ' ' + data_extenso(p['data']) + ' ' + ' '.join(itens) + ' ' + ' '.join(p.get('titulo_linhas') or [])
                         + ' ' + (marca.get('marca_dagua') or '')))
    vocab_junto = ''.join(sorted(vocab))
    texto_esperado_junto = compacto(' '.join(t for t, _ in textos_do_pedido(p)) + ' ' + TEXTO_DO_MOTOR + ' ' + tipo['nome'] + ' ' + marca['nome'])
    # palavra de uma letra ou pedaço de palavra partida pela extração (letras espaçadas) não conta como texto a mais
    a_mais = sorted({f for f in fichas if f not in vocab and not f.isdigit() and len(f) > 1 and f not in texto_esperado_junto})
    if a_mais: g('texto a mais no PDF, fora do pedido', ', '.join(a_mais[:12]))
    for sinal in ('{{', '{%', '[●', '\u2014', '\u00ad'):
        if sinal in bruto: g(f'sinal proibido no PDF: {sinal!r}')
    # 3. âncoras de assinatura literais no PDF
    for pt in (p.get('assinaturas') or {}).get('partes', []):
        if pt.get('ancora') and pt['ancora'] not in bruto.replace(' ', ''): g('âncora de assinatura ausente no PDF', pt['ancora'])
    for k in range((p.get('assinaturas') or {}).get('testemunhas') or 0):
        if f'/ass_T{k + 1}/' not in bruto.replace(' ', ''): g('âncora de testemunha ausente no PDF', f'/ass_T{k + 1}/')
    # 4. sumário: as páginas impressas são as do PDF final (D10)
    if itens:
        finais = casar_sumario(itens, paginas_dos_marcadores(pdf_bytes))
        if not finais: g('sumário íntegro', 'título sem marcador no PDF')
        elif finais != pags_impressas: g('sumário com páginas diferentes do PDF final', f'impresso {pags_impressas} · real {finais}')
        elif any(b < a for a, b in zip(finais, finais[1:])): g('sumário íntegro', 'páginas fora de ordem')
    return res


def gravar(caminho, dados, modo='wb'):
    """gravação atômica: arquivo temporário e troca de nome."""
    tmp = caminho + '.tmp'
    with open(tmp, modo) as f: f.write(dados)
    os.replace(tmp, caminho)


# ---------- emissão ----------
def emitir(pedido, saida, navegador=None):
    cat = {t['id']: t for t in json.load(open(CATALOGO))['tipos']}
    erros = validar(pedido, cat)
    if erros: return {'situacao': 'recusado', 'erros': erros, 'gates': [], 'alertas': []}
    tipo = cat[pedido['tipo']]; modelo = pedido.get('modelo') or tipo['modelo']
    pedido = {**pedido, '_modelo': modelo}
    # pacote de marca: o aprovado no banco (o worker manda em _marca_dados); sem banco, o arquivo de semente
    marca = pedido.get('_marca_dados') if isinstance(pedido.get('_marca_dados'), dict) and pedido['_marca_dados'].get('id') == pedido['marca'] \
        else json.load(open(os.path.join(MARCAS, pedido['marca'], 'marca.json')))
    achados = gates_conteudo(pedido, tipo, modelo)
    gates = [a for a in achados if a['nivel'] == 'bloqueia']
    alertas = [{'alerta': a['gate'], 'onde': a['onde']} for a in achados if a['nivel'] == 'alerta']
    if marca['situacao'] == 'provisoria' and tipo['alcance'] == 'externo':
        gates.append({'gate': 'marca provisória em documento externo', 'nivel': 'bloqueia', 'onde': marca['id']})
    if marca['tipografia'].get('substituicao'): alertas.append({'alerta': 'fonte substituta', 'onde': marca['tipografia']['substituicao']})
    os.makedirs(saida, exist_ok=True)
    pid = pedido.get('id') or f"{pedido['tipo']}-{pedido['marca']}-{sha(json.dumps({k: v for k, v in pedido.items() if k not in ('_modelo', '_marca_dados')}, sort_keys=True).encode())[:8]}"
    cab, rod, margens = cabecalho_rodape(pedido, marca, tipo, modelo)
    from playwright.sync_api import sync_playwright
    dono = None
    if navegador is None:
        dono = sync_playwright().start(); navegador = dono.chromium.launch()
    try:
        doc, itens, tem_capa = montar(pedido, marca, tipo, modelo)
        pdf, ajuste, html_final = renderizar(navegador, doc, modelo, cab, rod, margens)
        pags = casar_sumario(itens, paginas_dos_marcadores(pdf)) if itens else []
        for _ in range(3):  # passagens com as páginas reais até estabilizar
            if not itens or pags is None: break
            doc, itens, tem_capa = montar(pedido, marca, tipo, modelo, sumario_paginas=pags)
            pdf, ajuste, html_final = renderizar(navegador, doc, modelo, cab, rod, margens)
            novas = casar_sumario(itens, paginas_dos_marcadores(pdf))
            if novas == pags: break
            pags = novas
        pdf = metadados(pdf, marca, pedido, tipo, html_final)
    finally:
        if dono: navegador.close(); dono.stop()
    gates += gates_pdf(pdf, pedido, marca, tipo, modelo, itens, pags, tem_capa)
    alertas = [{'alerta': 'regra do terço', 'onde': a['texto'], 'motivo': a['motivo']} for a in ajuste['alertas']] + alertas
    situacao = 'bloqueado' if gates else ('emitido_com_alertas' if alertas else 'emitido')
    from pypdf import PdfReader
    n_pag = len(PdfReader(io.BytesIO(pdf)).pages)
    gravar(os.path.join(saida, f'{pid}.pdf'), pdf)
    gravar(os.path.join(saida, f'{pid}.html'), html_final, 'w')
    versoes = {f: sha(open(os.path.join(MODELOS, f), 'rb').read()) for f in ('base.css', 'documento.html.j2', 'ajuste.js')}
    versoes['marca.json'] = sha(json.dumps(marca, sort_keys=True, ensure_ascii=False).encode())
    versoes['motor.py'] = sha(open(os.path.abspath(__file__), 'rb').read())
    reg = {'id': pid, 'tipo': pedido['tipo'], 'tipo_nome': tipo['nome'], 'marca': pedido['marca'], 'modelo': modelo, 'emitido_em': dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds'),
           'situacao': situacao, 'paginas': n_pag, 'sumario': dict(zip(itens, pags or [])),
           'hash_pedido': sha(json.dumps({k: v for k, v in pedido.items() if k not in ('_modelo', '_marca_dados')}, sort_keys=True, ensure_ascii=False).encode()), 'hash_pdf': sha(pdf), 'hash_html': sha(html_final.encode()),
           'versoes': versoes, 'ajustes_terco': ajuste['ajustados'], 'gates': gates, 'alertas': alertas, 'arquivos': [f'{pid}.pdf', f'{pid}.html']}
    gravar(os.path.join(saida, f'{pid}.emissao.json'), json.dumps(reg, ensure_ascii=False, indent=1), 'w')
    return reg


if __name__ == '__main__':
    if '--instalar-fontes' in sys.argv: print(instalar_fontes()); sys.exit(0)
    arq = sys.argv[1]; saida = sys.argv[sys.argv.index('--saida') + 1] if '--saida' in sys.argv else os.path.join(AQUI, 'saida')
    r = emitir(json.load(open(arq)), saida)
    print(json.dumps({k: r[k] for k in r if k in ('id', 'situacao', 'paginas', 'gates', 'alertas', 'erros', 'sumario')}, ensure_ascii=False, indent=1))
