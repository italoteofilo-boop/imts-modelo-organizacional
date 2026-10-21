#!/usr/bin/env python3
"""Achata uma edge function e suas dependências locais numa pasta só (para o deploy pelo painel ou pela API).

Uso: python3 empacotar.py <funcao> <saida.json>
Regra de nomes: arquivos da própria função ficam como estão; _comum/x.ts vira x.ts; outra/x.ts vira outra_x.ts.
"""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent
func = sys.argv[1]
IMP = re.compile(r'''(from\s+|import\s+)(["'])(\.{1,2}/[^"']+)\2''')


def nome_plano(p: pathlib.Path) -> str:
    pasta = p.parent.name
    if pasta == func:
        return p.name
    if pasta == "_comum":
        return p.name
    return f"{pasta}_{p.name}"


arquivos: dict[str, str] = {}
fila = [RAIZ / func / "index.ts"]
while fila:
    p = fila.pop().resolve()
    n = nome_plano(p)
    if n in arquivos:
        continue
    txt = p.read_text(encoding="utf-8")

    def troca(m: re.Match) -> str:
        alvo = (p.parent / m.group(3)).resolve()
        fila.append(alvo)
        return f"{m.group(1)}{m.group(2)}./{nome_plano(alvo)}{m.group(2)}"

    arquivos[n] = IMP.sub(troca, txt)

saida = [{"name": k, "content": v} for k, v in sorted(arquivos.items(), key=lambda kv: kv[0] != "index.ts")]
pathlib.Path(sys.argv[2]).write_text(json.dumps(saida, ensure_ascii=False), encoding="utf-8")
print(func, [f["name"] for f in saida], sum(len(f["content"]) for f in saida), "caracteres")
