"""Motor documental do Ecossistema (E12). Um motor para todos os tipos, marcas e modelos.

pedido (JSON) → validação e gates de conteúdo → HTML (template único + modelo + marca) → regra do terço no navegador →
PDF no Chromium (Playwright) em duas passagens (a segunda escreve o sumário com as páginas lidas dos marcadores do PDF) →
metadados institucionais → gates do PDF → registro da emissão (hashes, gates, alertas, situação).

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


# ---------- validação e gates de conteúdo (antes de renderizar) ----------
def textos_do_pedido(p):
    """todos os textos visíveis do pedido, na ordem, para os gates de conteúdo e a conferência do PDF."""
    out = [p.get('titulo', '')]
    def de_blocos(bs):
        for b in bs or []:
            for k in ('titulo', 'texto', 'n', 'm', 'nome'):
                if b.get(k): out.append(str(b[k]))
            for i in b.get('itens', []) or []:
                if isinstance(i, dict): out.extend(str(v) for v in i.values())
                elif isinstance(i, (list, tuple)): out.extend(str(v) for v in i)
                else: out.append(str(i))
            for c in b.get('cab', []) or []: out.append(str(c))
            for l in b.get('linhas', []) or []: out.extend(str(c) for c in l)
    for r in p.get('campos') or []: out.extend(str(v) for v in r)
    de_blocos(p.get('blocos'))
    for a in p.get('anexos') or []: out.append(a.get('titulo', '')); de_blocos(a.get('blocos'))
    pf = p.get('parte_final') or {}
    for g in (pf.get('glossario') or []) + (pf.get('legenda') or []): out.extend(g)
    for r in pf.get('referencias') or []: out.extend([r['norma'], r['fonte']])
    for pt in (p.get('assinaturas') or {}).get('partes', []):
        out.extend(str(pt.get(k)) for k in ('papel', 'razao', 'nome', 'cargo') if pt.get(k))
    if p.get('assinaturas', {}).get('nota'): out.append(p['assinaturas']['nota'])
    for k in ('assunto', 'referencia'):
        if p.get(k): out.append(p[k])
    for k, v in (p.get('destinatario') or {}).items(): out.append(str(v))
    for k, v in (p.get('certificado') or {}).items(): out.append(str(v))
    return [texto_puro(t) for t in out if t]


def gates_conteudo(p, tipo_nome):
    achados = []
    textos = textos_do_pedido(p) + [p.get('tipo', ''), tipo_nome or '']
    for t in textos:
        if '[●' in t: achados.append(('campo pendente [●]', t[:80]))
        if '—' in t: achados.append(('travessão longo (—) em texto', t[:80]))
        if '{{' in t or '{%' in t or '%}' in t or '}}' in t: achados.append(('sinal de modelo ({{ }} ou {% %})', t[:80]))
        if re.search(r'\bv(ers[aã]o)?\s?\d+(\.\d+)+\b', t, re.I): achados.append(('número de versão no documento', t[:80]))
    return [{'gate': g, 'onde': o, 'nivel': 'bloqueia'} for g, o in achados]


def validar(p, cat):
    erros = []
    for k in ('tipo', 'marca', 'titulo', 'data', 'local'):
        if not p.get(k): erros.append(f'campo obrigatório ausente: {k}')
    if p.get('tipo') and p['tipo'] not in cat: erros.append(f"tipo desconhecido no catálogo: {p['tipo']}")
    if p.get('marca') and not os.path.exists(os.path.join(MARCAS, p['marca'], 'marca.json')): erros.append(f"marca sem pacote: {p['marca']}")
    try: dt.date.fromisoformat(p.get('data', ''))
    except ValueError: erros.append('data fora do formato AAAA-MM-DD')
    tipos_ok = {'secao', 'subsecao', 'p', 'item', 'alinea', 'lista', 'citacao', 'nota', 'destaque', 'kpis', 'campos', 'tabela'}
    for b in (p.get('blocos') or []) + [x for a in p.get('anexos') or [] for x in a.get('blocos', [])]:
        if b.get('t') not in tipos_ok: erros.append(f"bloco de tipo desconhecido: {b.get('t')}")
        if b.get('t') == 'tabela':
            n = len(b.get('cab', []))
            if any(len(l) != n for l in b.get('linhas', [])): erros.append(f"tabela com linhas de tamanho diferente do cabeçalho: {b.get('nome')}")
    return erros


# ---------- preparação do HTML ----------
def escapar_blocos(bs):
    out = []
    for b in bs or []:
        b = copy.deepcopy(b)
        for k in ('titulo', 'texto', 'nome'):
            if k in b: b[k] = inline(b[k])
        if 'itens' in b:
            b['itens'] = [({kk: inline(vv) for kk, vv in i.items()} if isinstance(i, dict) else [inline(v) for v in i] if isinstance(i, (list, tuple)) else inline(i)) for i in b['itens']]
        if 'cab' in b: b['cab'] = [inline(c) for c in b['cab']]
        if 'linhas' in b: b['linhas'] = [[inline(c) for c in l] for l in b['linhas']]
        out.append(b)
    # título preso ao que introduz: secao/subsecao + bloco seguinte num grupo indivisível (exceto tabela longa)
    grupos, i = [], 0
    while i < len(out):
        b = out[i]
        if b['t'] in ('secao', 'subsecao') and i + 1 < len(out) and not out[i + 1].get('longa'):
            j = i + 1
            if out[j]['t'] == 'subsecao' and j + 1 < len(out) and not out[j + 1].get('longa'): j += 1
            grupos.append({'preso': out[i:j + 1]}); i = j + 1
        else: grupos.append(b); i += 1
    return grupos


ROMANOS = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII']

def montar(p, marca, tipo, modelo, sumario_paginas=None):
    """devolve (html_documento, html_capa | None, itens_do_sumário)."""
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
    d = copy.deepcopy(p)
    d['titulo'] = inline(p['titulo'])
    d['blocos'] = escapar_blocos(p.get('blocos'))
    for k in ('assunto', 'referencia'):
        if k in d: d[k] = inline(d[k])
    if d.get('campos'): d['campos'] = [[inline(a), inline(b)] for a, b in d['campos']]
    for i, a in enumerate(d.get('anexos') or []):
        a['numero'] = ROMANOS[i]; a['titulo_simples'] = texto_puro(a['titulo']); a['titulo'] = inline(a['titulo']); a['blocos'] = escapar_blocos(a.get('blocos'))
    pf = d.get('parte_final')
    if pf:
        for k in ('glossario', 'legenda'):
            if pf.get(k): pf[k] = [[inline(a), inline(b)] for a, b in pf[k]]
        for r in pf.get('referencias') or []:
            r['norma'] = inline(r['norma']); r['fonte'] = html.escape(r['fonte']); r['verificado_em'] = data_br(r['verificado_em'])
    if d.get('assinaturas'):
        for pt in d['assinaturas']['partes']:
            for k in list(pt): pt[k] = inline(pt[k])
        if d['assinaturas'].get('nota'): d['assinaturas']['nota'] = inline(d['assinaturas']['nota'])
    for grupo in ('destinatario', 'certificado'):
        if d.get(grupo): d[grupo] = {k: inline(v) for k, v in d[grupo].items()}

    # sumário: títulos de seção, anexos e parte final, na ordem; páginas da passagem anterior (ou 00)
    itens = [texto_puro(b['titulo']) for b in p.get('blocos') or [] if b['t'] == 'secao']
    itens += [f"Anexo {ROMANOS[i]} – {texto_puro(a['titulo'])}" for i, a in enumerate(p.get('anexos') or [])]
    pfp = p.get('parte_final') or {}
    itens += [n for k, n in (('glossario', 'Glossário'), ('legenda', 'Legenda'), ('referencias', 'Referências normativas')) if pfp.get(k)]
    quer_sumario = p.get('sumario', modelo in COM_SUMARIO) and len(itens) >= 3
    sumario = [{'titulo': html.escape(t), 'pagina': (sumario_paginas[i] if sumario_paginas else '00')} for i, t in enumerate(itens)] if quer_sumario else None

    logo = None
    if marca.get('logos'):
        chave = 'horizontal' if modelo != 'certificado' else 'horizontal'
        logo = data_uri(os.path.join(MARCAS, marca['id'], marca['logos'][chave]))
    css = open(os.path.join(MODELOS, 'base.css')).read()
    classe = 'formal' if modelo in FORMAIS else 'premium'
    doc = tpl.render(d=d, m=marca, tokens=tokens, css=css, fontes_css=fontes_css(familias), classe=classe, modelo=modelo,
                     sumario=sumario, data_extenso=data_extenso(p['data']), logo=logo)
    capa = None
    if modelo in COM_CAPA and p.get('capa', True):
        logo_neg = data_uri(os.path.join(MARCAS, marca['id'], marca['logos']['horizontal_negativo'])) if marca.get('logos') else None
        topo = (f'<img class="logo" src="{logo_neg}" alt="{html.escape(marca["nome"])}">' if logo_neg
                else f'<div class="marca-txt">{html.escape(marca["nome"])}</div>')
        capa = (f'<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>{d["titulo"]}</title><style>{fontes_css(familias)}'
                f':root {{ {"; ".join(f"{k}: {v}" for k, v in tokens.items())} }} {css} @page {{ margin: 0; }}</style></head>'
                f'<body class="premium">{topo}'
                f'<div class="capa">{topo}<div class="tipo">{html.escape(tipo["nome"])}</div><div class="faixa"></div><h1>{d["titulo"]}</h1>'
                f'<div class="sub">{inline(p.get("subtitulo", ""))}</div>'
                f'<div class="rodape"><span>{html.escape(p.get("emitente", marca["autor_institucional"]))}</span><span>{html.escape(p["local"])}, {data_br(p["data"])}</span></div>'
                f'{"<div class=dagua>" + html.escape(marca["marca_dagua"]) + "</div>" if marca.get("marca_dagua") else ""}</div></body></html>')
        capa = capa.replace(f'<body class="premium">{topo}', '<body class="premium">', 1)
    return doc, capa, (itens if quer_sumario else [])


# ---------- cabeçalho e rodapé (Chromium desenha fora da página; só fontes do sistema) ----------
def cabecalho_rodape(p, marca, tipo, modelo):
    c = marca['cores']; fam = marca['tipografia']['texto']
    estilo = f"font-family:'{fam}',sans-serif;color:{c['texto']};-webkit-print-color-adjust:exact;"
    logo = data_uri(os.path.join(MARCAS, marca['id'], marca['logos']['horizontal'])) if marca.get('logos') else None
    marca_html = f'<img src="{logo}" style="height:0.95cm">' if logo else f'<span style="font-weight:700;font-size:11pt;color:{c["primaria"]}">{html.escape(marca["nome"])}</span>'
    linhas_nome = p.get('titulo_linhas') or [texto_puro(p['titulo'])]
    nome = '<br>'.join(f'<b>{html.escape(l)}</b>' for l in linhas_nome)
    if modelo in FORMAIS:
        cab = (f'<div style="{estilo}width:100%;padding:0 1.6cm;font-size:10.5pt;line-height:1.22;">'
               f'<table style="width:100%;border-collapse:collapse;border-bottom:.6pt solid {c["linha"]};"><tr>'
               f'<td style="width:24%;vertical-align:middle;padding:0 0 4pt;">{marca_html}</td>'
               f'<td style="vertical-align:middle;padding:0 8pt 4pt;"><i>{html.escape(tipo["nome"])}</i><br>{nome}</td>'
               f'<td style="width:22%;vertical-align:middle;text-align:right;padding:0 0 4pt;"><i>Emissão</i> <b>{data_br(p["data"])}</b><br>'
               f'<i>Página</i> <b><span class="pageNumber"></span> de <span class="totalPages"></span></b></td></tr></table></div>')
        rf = marca['rodape_aprovacao']
        cel = lambda xs, b: ''.join(f'<td style="width:33.3%;text-align:center;{"font-weight:700;" if b else ""}">{html.escape(x)}</td>' for x in xs)
        rod = (f'<div style="{estilo}width:100%;padding:0 1.6cm;font-size:7pt;line-height:1.3;">'
               f'<table style="width:100%;border-collapse:collapse;border-top:.6pt solid {c["linha"]};"><tr>{cel(rf["etapas"], True)}</tr><tr>{cel(rf["areas"], False)}</tr></table></div>')
        margens = {'top': '3.0cm', 'bottom': '1.9cm', 'left': '1.6cm', 'right': '1.6cm'}
    else:
        cab = (f'<div style="{estilo}width:100%;padding:0 1.8cm;font-size:8.5pt;display:flex;justify-content:space-between;align-items:center;">'
               f'<span>{marca_html.replace("0.95cm", "0.7cm")}</span><span style="color:{c["apoio"]}">{html.escape(texto_puro(p["titulo"]))}</span></div>')
        rod = (f'<div style="{estilo}width:100%;padding:0 1.8cm;font-size:7.5pt;display:flex;justify-content:space-between;color:{c["apoio"]};">'
               f'<span>{html.escape(marca["autor_institucional"])} · {html.escape(tipo["nome"])}</span>'
               f'<span><span class="pageNumber"></span> de <span class="totalPages"></span></span></div>')
        margens = {'top': '2.3cm', 'bottom': '2.0cm', 'left': '1.8cm', 'right': '1.8cm'}
    return cab, rod, margens


# ---------- renderização ----------
def renderizar(navegador, html_doc, cab, rod, margens, paisagem=False, sem_moldura=False):
    # o ajuste do terço mede no navegador: a largura da tela tem de ser a da coluna de texto impressa
    larg_cm = (29.7 if paisagem else 21.0) - (0 if sem_moldura else float(margens['left'].rstrip('cm')) + float(margens['right'].rstrip('cm')))
    pg = navegador.new_page(viewport={'width': round(larg_cm * 96 / 2.54), 'height': 1100})
    pg.emulate_media(media='print')
    pg.set_content(html_doc, wait_until='load')
    pg.evaluate('document.fonts.ready')
    ajuste = pg.evaluate(open(os.path.join(MODELOS, 'ajuste.js')).read())
    opts = dict(format='A4', landscape=paisagem, print_background=True, outline=True, tagged=True, prefer_css_page_size=False)
    if sem_moldura: opts.update(margin={'top': '0', 'bottom': '0', 'left': '0', 'right': '0'}, display_header_footer=False)
    else: opts.update(margin=margens, display_header_footer=True, header_template=cab, footer_template=rod)
    pdf = pg.pdf(**opts); html_final = pg.content(); pg.close()
    return pdf, ajuste, html_final


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


def metadados(pdf_bytes, marca, p, tipo):
    from pypdf import PdfReader, PdfWriter
    r = PdfReader(io.BytesIO(pdf_bytes)); w = PdfWriter(clone_from=r)
    w.add_metadata({'/Title': texto_puro(p['titulo']), '/Author': marca['autor_institucional'], '/Subject': tipo['nome'],
                    '/Creator': 'Motor documental do Ecossistema', '/Producer': 'Chromium (Playwright) e pypdf'})
    b = io.BytesIO(); w.write(b); return b.getvalue()


def juntar(capa_pdf, corpo_pdf):
    from pypdf import PdfReader, PdfWriter
    w = PdfWriter()
    w.append(PdfReader(io.BytesIO(capa_pdf)), import_outline=False)
    w.append(PdfReader(io.BytesIO(corpo_pdf)))
    b = io.BytesIO(); w.write(b); return b.getvalue()


# ---------- gates do PDF ----------
def palavras(s): return re.findall(r'\w+', unicodedata.normalize('NFC', html.unescape(s)).casefold())

def em_ordem(alvo, fichas):
    """alvo aparece em fichas como sequência contígua, ou, se não, como subsequência dentro de uma janela curta."""
    n = len(alvo)
    for i in range(len(fichas) - n + 1):
        if fichas[i] == alvo[0]:
            if fichas[i:i + n] == alvo: return True
            j, k = i, 0
            while j < len(fichas) and j < i + 4 * n + 20 and k < n:
                if fichas[j] == alvo[k]: k += 1
                j += 1
            if k == n: return True
    return False


def gates_pdf(pdf_bytes, p, marca, tipo, itens_sumario, sumario_paginas, desloc, margem_sup_cm, margem_inf_cm, formal, modelo=''):
    import pdfplumber
    from pypdf import PdfReader
    res = []
    r = PdfReader(io.BytesIO(pdf_bytes)); meta = r.metadata or {}
    if meta.get('/Author') != marca['autor_institucional']: res.append({'gate': 'metadados: autor institucional', 'nivel': 'bloqueia', 'onde': str(meta.get('/Author'))})
    if meta.get('/Title') != texto_puro(p['titulo']): res.append({'gate': 'metadados: título', 'nivel': 'bloqueia', 'onde': str(meta.get('/Title'))})
    if meta.get('/Subject') != tipo['nome']: res.append({'gate': 'metadados: assunto', 'nivel': 'bloqueia', 'onde': str(meta.get('/Subject'))})
    texto_total = ''; titulos = {compacto(t) for t in itens_sumario}
    titulos |= {compacto(texto_puro(b['titulo'])) for b in (p.get('blocos') or []) + [x for a in p.get('anexos') or [] for x in a.get('blocos', [])] if b['t'] in ('secao', 'subsecao')}
    titulos |= {compacto(texto_puro(b['nome'])) for b in (p.get('blocos') or []) + [x for a in p.get('anexos') or [] for x in a.get('blocos', [])] if b['t'] == 'tabela' and b.get('nome')}
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for i, pg in enumerate(pdf.pages):
            # texto girado (marca d'água) fica fora da conferência
            pg = pg.filter(lambda o: o.get('object_type') != 'char' or (o.get('upright', True) and abs(o['matrix'][1]) < 0.01))
            texto_total += (pg.extract_text() or '') + '\n'
            if i < desloc: continue
            topo = margem_sup_cm * CM; base = pg.height - margem_inf_cm * CM
            corpo = [w for w in pg.extract_words(keep_blank_chars=False) if w['top'] >= topo - 2 and w['bottom'] <= base + 2 and w.get('upright', True)]
            corpo = [w for w in corpo if not (w['bottom'] - w['top'] < 2)]  # âncoras de 1 pt não contam
            if not corpo:
                res.append({'gate': 'página em branco', 'nivel': 'bloqueia', 'onde': f'página {i + 1}'}); continue
            ult_top = max(w['top'] for w in corpo)
            ultima = compacto(' '.join(w['text'] for w in sorted([w for w in corpo if abs(w['top'] - ult_top) < 3], key=lambda w: w['x0'])))
            if i < len(pdf.pages) - 1 and any(ultima and (ultima == t or (len(ultima) > 6 and t.endswith(ultima))) for t in titulos):
                res.append({'gate': 'título sozinho no fim da página', 'nivel': 'bloqueia', 'onde': f'página {i + 1}: {ultima[:60]}'})
    # cada texto do pedido tem de estar no PDF com todas as palavras, na ordem (colunas lado a lado podem intercalar linhas)
    fichas = palavras(texto_total)
    esperados = textos_do_pedido(p)
    if modelo == 'oficio': esperados[0] = ' '.join(p.get('titulo_linhas') or [p['titulo']])
    faltam = [t for t in esperados if palavras(t) and not em_ordem(palavras(t), fichas)]
    for f in faltam[:10]: res.append({'gate': 'texto do PDF diferente dos blocos', 'nivel': 'bloqueia', 'onde': f[:80]})
    for sinal in ('{{', '{%', '[●', '—'):
        if sinal in texto_total: res.append({'gate': f'sinal proibido no PDF: {sinal}', 'nivel': 'bloqueia', 'onde': ''})
    if itens_sumario:
        if not sumario_paginas: res.append({'gate': 'sumário íntegro', 'nivel': 'bloqueia', 'onde': 'título sem marcador no PDF'})
        else:
            if any(b < a for a, b in zip(sumario_paginas, sumario_paginas[1:])) or any(x < 1 for x in sumario_paginas):
                res.append({'gate': 'sumário íntegro', 'nivel': 'bloqueia', 'onde': 'páginas fora de ordem'})
    return res


# ---------- emissão ----------
def emitir(pedido, saida, navegador=None):
    cat = {t['id']: t for t in json.load(open(CATALOGO))['tipos']}
    erros = validar(pedido, cat)
    if erros: return {'situacao': 'recusado', 'erros': erros}
    tipo = cat[pedido['tipo']]; modelo = pedido.get('modelo') or tipo['modelo']
    marca = json.load(open(os.path.join(MARCAS, pedido['marca'], 'marca.json')))
    gates = gates_conteudo(pedido, tipo['nome'])
    alertas_marca = []
    if marca['situacao'] == 'provisoria' and tipo['alcance'] == 'externo':
        gates.append({'gate': 'marca provisória em documento externo', 'nivel': 'bloqueia', 'onde': marca['id']})
    if marca['tipografia'].get('substituicao'): alertas_marca.append({'alerta': 'fonte substituta', 'onde': marca['tipografia']['substituicao']})
    os.makedirs(saida, exist_ok=True)
    pid = pedido.get('id') or f"{pedido['tipo']}-{pedido['marca']}-{sha(json.dumps(pedido, sort_keys=True).encode())[:8]}"
    cab, rod, margens = cabecalho_rodape(pedido, marca, tipo, modelo)
    from playwright.sync_api import sync_playwright
    dono = None
    if navegador is None:
        dono = sync_playwright().start(); navegador = dono.chromium.launch()
    try:
        if modelo == 'certificado':
            doc, _, itens = montar(pedido, marca, tipo, modelo)
            pdf, ajuste, html_final = renderizar(navegador, doc, cab, rod, margens, paisagem=True, sem_moldura=True)
            pags, desloc, capa_pdf = [], 0, None
        else:
            doc, capa, itens = montar(pedido, marca, tipo, modelo)
            pdf, ajuste, html_final = renderizar(navegador, doc, cab, rod, margens)
            pags = casar_sumario(itens, paginas_dos_marcadores(pdf)) if itens else []
            for _ in range(2):  # segunda passagem com as páginas reais; terceira só se a paginação mudar
                if not itens or pags is None: break
                doc, capa, itens = montar(pedido, marca, tipo, modelo, sumario_paginas=pags)
                pdf, ajuste, html_final = renderizar(navegador, doc, cab, rod, margens)
                novas = casar_sumario(itens, paginas_dos_marcadores(pdf))
                if novas == pags: break
                pags = novas
            desloc = 0; capa_pdf = None
            if capa:
                capa_pdf, _, _ = renderizar(navegador, capa, '', '', margens, sem_moldura=True)
                pdf = juntar(capa_pdf, pdf); desloc = 1
        pdf = metadados(pdf, marca, pedido, tipo)
    finally:
        if dono: navegador.close(); dono.stop()
    ms = float(margens['top'].rstrip('cm')) if modelo != 'certificado' else 0
    mi = float(margens['bottom'].rstrip('cm')) if modelo != 'certificado' else 0
    gates += gates_pdf(pdf, pedido, marca, tipo, itens, pags, desloc, ms, mi, modelo in FORMAIS, modelo)
    alertas = [{'alerta': 'regra do terço', 'onde': a['texto'], 'motivo': a['motivo']} for a in ajuste['alertas']] + alertas_marca
    situacao = 'bloqueado' if any(g['nivel'] == 'bloqueia' for g in gates) else ('emitido_com_alertas' if alertas else 'emitido')
    from pypdf import PdfReader
    n_pag = len(PdfReader(io.BytesIO(pdf)).pages)
    # o HTML de saída é o documento final (com o ajuste do terço aplicado), autocontido
    open(os.path.join(saida, f'{pid}.pdf'), 'wb').write(pdf)
    open(os.path.join(saida, f'{pid}.html'), 'w').write(html_final)
    reg = {'id': pid, 'tipo': pedido['tipo'], 'tipo_nome': tipo['nome'], 'marca': pedido['marca'], 'modelo': modelo, 'emitido_em': dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds'),
           'situacao': situacao, 'paginas': n_pag, 'sumario': dict(zip(itens, pags or [])),
           'hash_pedido': sha(json.dumps(pedido, sort_keys=True, ensure_ascii=False).encode()), 'hash_pdf': sha(pdf), 'hash_html': sha(html_final.encode()),
           'ajustes_terco': ajuste['ajustados'], 'gates': gates, 'alertas': alertas, 'arquivos': [f'{pid}.pdf', f'{pid}.html']}
    json.dump(reg, open(os.path.join(saida, f'{pid}.emissao.json'), 'w'), ensure_ascii=False, indent=1)
    return reg


if __name__ == '__main__':
    if '--instalar-fontes' in sys.argv: print(instalar_fontes()); sys.exit(0)
    arq = sys.argv[1]; saida = sys.argv[sys.argv.index('--saida') + 1] if '--saida' in sys.argv else os.path.join(AQUI, 'saida')
    r = emitir(json.load(open(arq)), saida)
    print(json.dumps({k: r[k] for k in r if k in ('id', 'situacao', 'paginas', 'gates', 'alertas', 'erros', 'sumario')}, ensure_ascii=False, indent=1))
