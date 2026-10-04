"""Worker do motor documental: lê a fila do Supabase (doc.pedido), emite com o motor (Chromium) e registra a emissão.

Configuração por ambiente (nada de segredo no código nem no repositório):
  SUPABASE_URL          https://<projeto>.supabase.co
  SUPABASE_CHAVE_PUB    chave publicável do projeto (as funções do worker só respondem com a chave abaixo)
  DOC_WORKER_CHAVE      mesma chave gravada no Vault com o nome doc_worker_chave
  DOC_WORKER_NOME       nome deste worker no registro (padrão: nome da máquina)
Uso: python3 worker.py [--uma-vez] [--intervalo 10]
No protótipo roda aqui; em produção, no serviço escolhido (contêiner com Chromium e as fontes de documentos/fontes).
"""
import base64, json, os, socket, sys, tempfile, time, traceback, urllib.error, urllib.request
import motor

URL = os.environ.get('SUPABASE_URL', '').rstrip('/'); PUB = os.environ.get('SUPABASE_CHAVE_PUB', '')
CHAVE = os.environ.get('DOC_WORKER_CHAVE', ''); NOME = os.environ.get('DOC_WORKER_NOME', socket.gethostname())


def rpc(fn, corpo):
    req = urllib.request.Request(f'{URL}/rest/v1/rpc/{fn}', data=json.dumps(corpo).encode(), method='POST',
                                 headers={'apikey': PUB, 'Authorization': f'Bearer {PUB}', 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=120) as r: return json.loads(r.read().decode() or 'null')
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{fn}: HTTP {e.code} {e.read().decode()[:300]}')


def uma_rodada(navegador):
    p = rpc('doc_worker_proximo', {'p_chave': CHAVE, 'p_worker': NOME})
    if not p: return None
    pid = p.pop('pedido')
    try:
        with tempfile.TemporaryDirectory() as tmp:
            reg = motor.emitir(p, tmp, navegador)
            if reg['situacao'] == 'recusado':
                rpc('doc_worker_registrar', {'p_chave': CHAVE, 'p_pedido': pid, 'p_registro': reg, 'p_pdf': '', 'p_html': ''}); return (pid, reg)
            pdf = open(os.path.join(tmp, reg['arquivos'][0]), 'rb').read(); html = open(os.path.join(tmp, reg['arquivos'][1]), 'rb').read()
            em = rpc('doc_worker_registrar', {'p_chave': CHAVE, 'p_pedido': pid, 'p_registro': reg,
                                              'p_pdf': base64.b64encode(pdf).decode(), 'p_html': base64.b64encode(html).decode()})
            reg['emissao'] = em; return (pid, reg)
    except Exception as e:
        rpc('doc_worker_falhar', {'p_chave': CHAVE, 'p_pedido': pid, 'p_erro': f'{type(e).__name__}: {e}'[:1900]})
        traceback.print_exc(); return (pid, {'situacao': 'falha', 'erro': str(e)})


def main():
    if not (URL and PUB and CHAVE): sys.exit('configure SUPABASE_URL, SUPABASE_CHAVE_PUB e DOC_WORKER_CHAVE')
    uma = '--uma-vez' in sys.argv
    intervalo = int(sys.argv[sys.argv.index('--intervalo') + 1]) if '--intervalo' in sys.argv else 10
    motor.instalar_fontes()
    from playwright.sync_api import sync_playwright
    with sync_playwright() as pw:
        nav = pw.chromium.launch()
        while True:
            r = uma_rodada(nav)
            if r: print(json.dumps({'pedido': r[0], 'situacao': r[1]['situacao'], 'emissao': r[1].get('emissao'), 'paginas': r[1].get('paginas'),
                                    'gates': len(r[1].get('gates', [])), 'alertas': len(r[1].get('alertas', []))}, ensure_ascii=False), flush=True)
            elif uma: break
            else: time.sleep(intervalo)
        nav.close()


if __name__ == '__main__': main()
