# Converte a planilha preenchida no JSON de adm.importar_cadastro (sem a coluna observacao; linhas sem nome/email ficam fora)
import sys, json, datetime
from openpyxl import load_workbook
wb=load_workbook(sys.argv[1], data_only=True); out={}
chave={'empresas':'nome','pessoas':'email','contrapartes':'nome','usuarios_externos':'email','contratos_parceria':'parceiro'}
for aba,k in chave.items():
    ws=wb[aba]; cab=[c.value for c in ws[1]]; linhas=[]
    for row in ws.iter_rows(min_row=2, values_only=True):
        o={}
        for h,v in zip(cab,row):
            if h in (None,'observacao') or v in (None,''): continue
            if isinstance(v,float) and v.is_integer(): v=int(v)
            if isinstance(v,(datetime.date,datetime.datetime)): v=v.strftime('%Y-%m-%d')
            if h=='setor_publico': v = str(v).strip().lower() in ('sim','s','true','1','x')
            elif h in ('percentual','parcelas_max'): v = float(str(v).replace(',','.')) if h=='percentual' else int(v)
            else: v=str(v).strip()
            o[h]=v
        if o.get(k): linhas.append(o)
    if linhas: out[aba]=linhas
print(json.dumps(out, ensure_ascii=False))
