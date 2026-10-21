#!/usr/bin/env python3
"""Monta um pacote único de migrações para colar no SQL Editor do Supabase.

Uso: python3 montar_pacote.py <saida.sql> <arquivo1.sql> [arquivo2.sql ...]
Tira o begin/commit de cada arquivo e envolve tudo numa transação só:
ou entra tudo, ou nada muda.
"""
import pathlib
import re
import sys

saida, *arquivos = sys.argv[1:]
partes = ["-- Pacote IMTS.OS: colar inteiro no SQL Editor e executar (uma transação só).", "begin;"]
for a in arquivos:
    txt = pathlib.Path(a).read_text(encoding="utf-8")
    txt = re.sub(r"(?m)^\s*(begin|commit)\s*;\s*$", "", txt)
    partes.append(f"\n-- ===== {pathlib.Path(a).name} =====\n{txt.strip()}\n")
partes.append("commit;\n")
pathlib.Path(saida).write_text("\n".join(partes), encoding="utf-8")
print(saida, sum(len(p) for p in partes), "caracteres")
