# Worker do motor documental (B24). Imagem oficial do Playwright para Python (Chromium e dependências já instalados).
# Construir:  docker build -t imts-worker-documentos documentos/
# Rodar:      docker run -d --restart=always --name imts-worker \
#               -e SUPABASE_URL=https://<ref>.supabase.co -e SUPABASE_CHAVE_PUB=<chave publicável> \
#               -e DOC_WORKER_CHAVE=<valor do segredo doc_worker_chave no cofre> -e DOC_WORKER_NOME=worker-1 imts-worker-documentos
# A chave do worker nunca entra na imagem: vai só no ambiente do contêiner.
FROM mcr.microsoft.com/playwright/python:v1.56.0-noble
WORKDIR /app
# o segredo opcional "ca" só existe em rede com proxy próprio (certificado da empresa); em produção não é preciso
RUN --mount=type=secret,id=ca,required=false pip install --no-cache-dir $( [ -f /run/secrets/ca ] && echo --cert /run/secrets/ca ) jinja2==3.1.6 playwright==1.56.0 pypdf==3.17.4 pdfplumber==0.11.9
COPY motor.py worker.py ./
COPY fontes ./fontes
COPY marcas ./marcas
COPY modelos ./modelos
COPY tipos ./tipos
RUN chown -R pwuser:pwuser /app
USER pwuser
ENV PYTHONUNBUFFERED=1
HEALTHCHECK --interval=5m --timeout=10s CMD python3 -c "import os,sys; sys.exit(0 if os.environ.get('SUPABASE_URL') else 1)"
CMD ["python3", "worker.py", "--intervalo", "10"]
