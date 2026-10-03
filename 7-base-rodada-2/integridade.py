#!/usr/bin/env python3
"""Lê as abas do catálogo (como publicadas no doc), monta a base e roda os testes de integridade."""
import json, re, html, sys, collections

TR = "/root/.claude/projects/-home-claude/7a4d2de5-f42d-5914-a7de-871f2f268191/tool-results/"
SP = "/tmp/claude-0/-home-claude/7a4d2de5-f42d-5914-a7de-871f2f268191/scratchpad/"
XML_FILES = {
    "valor": TR + "mcp-Claude_Docs-read-1790855831684.txt",
    "corporativas": TR + "mcp-Claude_Docs-read-1790855833007.txt",
    "internas": TR + "mcp-Claude_Docs-read-1790855836040.txt",
}
if len(sys.argv) > 1:  # permite trocar os arquivos lidos: aba=caminho
    for a in sys.argv[1:]:
        k, v = a.split("=", 1)
        XML_FILES[k] = v
MD_FILES = {"entre": SP + "tab_e.md"}

CIRCULOS = ["Identidade", "Estratégia", "Inteligência", "Relações", "Negócios",
            "Integração", "Operações", "Gestão", "Governança"]
DONOS_ESPECIAIS = ["Executivo", "Círculo que presta", "Círculo dono", "Frente de origem", "Quem pediu"]
EXTERNOS = {"todos", "quem pediu", "frente de origem", "executivo", "cliente", "mercado", "fornecedor",
            "fisco", "sócios", "públicos", "pessoas", "banco", "órgão regulador"}
CORINGAS_SAIDA = {"todos", "quem pediu", "frente de origem"}
MODOS = ["Assistido", "Copiloto", "Autopiloto", "Autômato"]
RISCOS = ["baixo", "médio", "alto"]
SIGLAS = "ID|ES|IN|RE|NE|IT|OP|GE|GO"
RE_W = re.compile(rf"^W-((?:V|C|E)\d+|(?:{SIGLAS})\d+)\.(\d+)$")
RE_J = re.compile(rf"^((?:V|C|E)\d+|I-(?:{SIGLAS})\d+)$")


def text_of(fragment):
    return html.unescape("".join(re.findall(r"<text[^>]*>(.*?)</text>", fragment, flags=re.S))).strip()


def blocks_from_xml(path):
    xml = json.load(open(path))["data"]["xml"]
    out = []
    pos = 0
    for m in re.finditer(r"<table\b.*?</table>", xml, flags=re.S):
        out += paras(xml[pos:m.start()])
        rows = []
        for r in re.findall(r"<row\b.*?</row>", m.group(0), flags=re.S):
            rows.append([text_of(c) for c in re.findall(r"<cell\b.*?</cell>", r, flags=re.S)])
        out.append(("table", rows))
        pos = m.end()
    out += paras(xml[pos:])
    return out


def paras(chunk):
    res = []
    for m in re.finditer(r"<paragraph\b([^>]*)>(.*?)</paragraph>", chunk, flags=re.S):
        h = re.search(r"heading='(\d)'", m.group(1))
        res.append((f"h{h.group(1)}" if h else "p", text_of(m.group(2))))
    return res


def blocks_from_md(path):
    out, rows = [], []
    for line in open(path, encoding="utf-8").read().split("\n"):
        line = line.strip()
        if line.startswith("|"):
            rows.append([c.strip() for c in line.strip("|").split("|")])
            continue
        if rows:
            out.append(("table", [["Workflow", "Dono", "Entrada (de quem)", "Saída (para quem)", "Aceite", "Execução"]] + rows))
            rows = []
        if line.startswith("### "):
            out.append(("h3", line[4:]))
        elif line:
            out.append(("p", line))
    if rows:
        out.append(("table", [["Workflow", "Dono", "Entrada (de quem)", "Saída (para quem)", "Aceite", "Execução"]] + rows))
    return out


def split_items(cell):
    items, depth, cur = [], 0, ""
    for ch in cell:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == ";" and depth == 0:
            items.append(cur.strip()); cur = ""
        else:
            cur += ch
    if cur.strip():
        items.append(cur.strip())
    return items


def parse_items(cell):
    res = []
    for it in split_items(cell):
        refs = []
        for grp in re.findall(r"\(([^()]*)\)", it):
            refs += [t.strip() for t in grp.split(";") if t.strip()]
        what = re.sub(r"\s*\([^()]*\)", "", it).strip()
        res.append({"o_que": what, "refs": refs, "texto": it})
    return res


def journey_of(wcode):
    m = RE_W.match(wcode)
    j = m.group(1)
    return j if re.match(r"^(V|C|E)\d+$", j) else "I-" + j


problemas = []
jornadas = collections.OrderedDict()
for aba, loader, files in (("valor", blocks_from_xml, XML_FILES), ("corporativas", blocks_from_xml, XML_FILES),
                           ("entre", blocks_from_md, MD_FILES), ("internas", blocks_from_xml, XML_FILES)):
    blocks = loader(files[aba])
    cur = None
    for kind, val in blocks:
        if kind == "h3" and val.startswith("J-"):
            code, name = val[2:].split(" · ", 1)
            cur = {"codigo": code.strip(), "nome": name.strip(), "aba": aba, "workflows": [], "lider": None,
                   "vale_para": None, "situacao": "", "gatilho": None, "resultado": None}
            if cur["codigo"] in jornadas:
                problemas.append(f"jornada duplicada: {cur['codigo']}")
            jornadas[cur["codigo"]] = cur
        elif kind == "p" and cur is not None and val.startswith("Líder:"):
            for part in val.split(" · "):
                k, v = part.split(":", 1)
                cur[{"Líder": "lider", "Vale para": "vale_para", "Situação": "situacao"}[k.strip()]] = v.strip()
        elif kind == "p" and cur is not None and val.startswith("Gatilho:"):
            m = re.match(r"Gatilho: (.*?)\. Resultado: (.*)$", val, flags=re.S)
            if not m:
                problemas.append(f"{cur['codigo']}: gatilho/resultado fora do formato")
            else:
                cur["gatilho"], cur["resultado"] = m.group(1), m.group(2)
        elif kind == "table" and cur is not None:
            header, rows = val[0], val[1:]
            if header != ["Workflow", "Dono", "Entrada (de quem)", "Saída (para quem)", "Aceite", "Execução"]:
                problemas.append(f"{cur['codigo']}: cabeçalho inesperado {header}")
            for r in rows:
                if len(r) != 6:
                    problemas.append(f"{cur['codigo']}: linha com {len(r)} colunas: {r[:1]}")
                    continue
                wcode, wname = r[0].split(" ", 1)
                ex = r[5]
                m = re.match(r"^(\w+) · (\w+)\. Pessoa: (.*?) Agente: (.*?)(?: Assessoria: (.*))?$", ex, flags=re.S)
                w = {"codigo": wcode, "nome": wname, "jornada": cur["codigo"], "dono": r[1],
                     "entradas": parse_items(r[2]), "saidas": parse_items(r[3]), "aceite": r[4], "execucao": ex}
                if not m:
                    problemas.append(f"{wcode}: execução fora do formato: {ex[:60]}")
                else:
                    w.update(modo=m.group(1), risco=m.group(2), pessoa=m.group(3).strip(), agente=m.group(4).strip(),
                             assessoria=(m.group(5) or "").strip())
                cur["workflows"].append(w)

W = collections.OrderedDict()
for j in jornadas.values():
    for w in j["workflows"]:
        if w["codigo"] in W:
            problemas.append(f"workflow duplicado: {w['codigo']}")
        W[w["codigo"]] = w

# ---------- testes ----------
def kind(tok):
    if RE_W.match(tok): return "w"
    if RE_J.match(tok): return "j"
    return "x"

def all_refs(items):
    return [t for it in items for t in it["refs"]]

for j in jornadas.values():
    if j["lider"] not in CIRCULOS: problemas.append(f"{j['codigo']}: líder inválido {j['lider']}")
    if not j["gatilho"] or not j["resultado"] or not j["vale_para"]: problemas.append(f"{j['codigo']}: cabeçalho incompleto")
    if len(j["workflows"]) < 3: problemas.append(f"{j['codigo']}: menos de 3 workflows")
    for i, w in enumerate(j["workflows"], 1):
        m = RE_W.match(w["codigo"])
        if not m: problemas.append(f"código de workflow inválido: {w['codigo']}"); continue
        if journey_of(w["codigo"]) != j["codigo"]: problemas.append(f"{w['codigo']} fora da jornada {j['codigo']}")
        if int(m.group(2)) != i: problemas.append(f"{w['codigo']}: numeração fora de ordem")

for w in W.values():
    c = w["codigo"]
    dono1 = re.split(r",| com ", w["dono"])[0].strip()
    if dono1 not in CIRCULOS + DONOS_ESPECIAIS: problemas.append(f"{c}: dono inválido '{w['dono']}'")
    if not w["entradas"]: problemas.append(f"{c}: sem entrada")
    if not w["saidas"]: problemas.append(f"{c}: sem saída")
    if not w["aceite"]: problemas.append(f"{c}: sem aceite")
    if w.get("modo") not in MODOS: problemas.append(f"{c}: modo inválido {w.get('modo')}")
    if w.get("risco") not in RISCOS: problemas.append(f"{c}: risco inválido {w.get('risco')}")
    if w.get("risco") == "alto" and w.get("modo") not in ("Assistido", "Copiloto"):
        problemas.append(f"{c}: risco alto com modo {w.get('modo')}")
    if not w.get("pessoa") or not w.get("agente"): problemas.append(f"{c}: falta pessoa ou agente")
    for lado in ("entradas", "saidas"):
        for it in w[lado]:
            if not it["refs"]: problemas.append(f"{c}: item sem origem/destino em {lado}: '{it['texto']}'")
            for t in it["refs"]:
                k = kind(t)
                if k == "w" and t not in W: problemas.append(f"{c}: referência a workflow inexistente {t}")
                if k == "j" and t not in jornadas: problemas.append(f"{c}: referência a jornada inexistente {t}")
                if k == "x" and t not in EXTERNOS: problemas.append(f"{c}: termo fora do vocabulário '{t}' em {lado}")
                if t == c: problemas.append(f"{c}: referência a si mesmo")

def consumes(b, a):
    """workflow b declara entrada vinda de a (workflow), da jornada de a, ou de todos"""
    r = set(all_refs(W[b]["entradas"]))
    return a in r or journey_of(a) in r or "todos" in r

def produces_for(a, b):
    """workflow a declara saída para b (workflow), para a jornada de b, ou para todos / quem pediu / frente de origem"""
    r = set(all_refs(W[a]["saidas"]))
    return b in r or journey_of(b) in r or bool(r & CORINGAS_SAIDA)

for w in W.values():
    a = w["codigo"]
    for t in all_refs(w["saidas"]):
        k = kind(t)
        if k == "w" and t in W and not consumes(t, a):
            problemas.append(f"saída sem consumo: {a} -> {t}, mas {t} não declara entrada de {a}")
        if k == "j" and t in jornadas and not any(consumes(x["codigo"], a) for x in jornadas[t]["workflows"]):
            problemas.append(f"saída sem consumo: {a} -> jornada {t}, mas nenhum workflow dela declara entrada de {a}")
    for t in all_refs(w["entradas"]):
        k = kind(t)
        if k == "w" and t in W and not produces_for(t, a):
            problemas.append(f"entrada sem origem: {a} <- {t}, mas {t} não declara saída para {a}")
        if k == "j" and t in jornadas and not any(produces_for(x["codigo"], a) for x in jornadas[t]["workflows"]):
            problemas.append(f"entrada sem origem: {a} <- jornada {t}, mas nenhum workflow dela declara saída para {a}")

lid = collections.Counter(j["lider"] for j in jornadas.values())
dono = collections.Counter(re.split(r",| com ", w["dono"])[0].strip() for w in W.values())
for c in CIRCULOS:
    if lid[c] == 0: problemas.append(f"círculo sem jornada liderada: {c}")
    if dono[c] == 0: problemas.append(f"círculo sem workflow próprio: {c}")

# ---------- saída ----------
print(f"jornadas: {len(jornadas)}  workflows: {len(W)}")
for aba in ("valor", "corporativas", "entre", "internas"):
    js = [j for j in jornadas.values() if j["aba"] == aba]
    print(f"  {aba}: {len(js)} jornadas, {sum(len(j['workflows']) for j in js)} workflows")
print(f"problemas: {len(problemas)}")
for p in problemas: print("  -", p)

print("\nmodo x aba")
for aba in ("valor", "corporativas", "entre", "internas"):
    cnt = collections.Counter(w.get("modo") for w in W.values() if jornadas[w["jornada"]]["aba"] == aba)
    print(" ", aba, [cnt[m] for m in MODOS])
tot = collections.Counter(w.get("modo") for w in W.values())
print("  total", [tot[m] for m in MODOS], {m: round(100 * tot[m] / len(W)) for m in MODOS})
print("risco", collections.Counter(w.get("risco") for w in W.values()))
print("modo x risco", sorted(collections.Counter((w.get("modo"), w.get("risco")) for w in W.values()).items()))
print("com assessoria:", sum(1 for w in W.values() if w.get("assessoria")))
print("\nlidera jornadas:", {c: lid[c] for c in CIRCULOS})
print("dono de workflows:", dict(dono))
print("\nmodo por círculo dono")
for c in CIRCULOS + DONOS_ESPECIAIS:
    cnt = collections.Counter(w.get("modo") for w in W.values() if re.split(r",| com ", w["dono"])[0].strip() == c)
    if sum(cnt.values()): print(f"  {c}: {[cnt[m] for m in MODOS]} = {sum(cnt.values())}")

json.dump({"jornadas": list(jornadas.values())}, open(SP + "catalogo.json", "w"), ensure_ascii=False, indent=1)
print("\nbase salva em catalogo.json")
