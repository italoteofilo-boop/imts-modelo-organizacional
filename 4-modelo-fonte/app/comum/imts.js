// IMTS.OS · núcleo do aplicativo de produção (www.imts.global)
// Login (Google do Workspace para quem é de dentro; link por e-mail para clientes e parceiros), sessão, menu por papel
// e a porta única: toda leitura e ação passa por public.imts(p_fn, p_args), com o login de quem usa.
// Nenhuma tela monta SQL. Nenhuma tela guarda segredo. A permissão é sempre do banco.
(function () {
  'use strict';
  const C = window.IMTS_CONFIG || {};
  const ENSAIO = C.ensaio === true;                       // só no ensaio local (Playwright); a configuração de produção não tem este campo
  const REST = (C.rest || (C.supabaseUrl || '') + '/rest/v1').replace(/\/$/, '');
  const FUNCOES = (C.funcoes || (C.supabaseUrl || '') + '/functions/v1').replace(/\/$/, '');
  const guardar = {
    ler(k) { try { return localStorage.getItem('imts.' + k); } catch (e) { return null; } },
    gravar(k, v) { try { if (v == null) localStorage.removeItem('imts.' + k); else localStorage.setItem('imts.' + k, v); } catch (e) { /* sem armazenamento: segue sem lembrar */ } }
  };
  let cliente = null, quem = null;

  function supa() {
    if (cliente) return cliente;
    if (!window.supabase || !C.supabaseUrl || !C.anonKey) throw new Error('configuração do aplicativo incompleta (config.js)');
    cliente = window.supabase.createClient(C.supabaseUrl, C.anonKey, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce' } });
    return cliente;
  }
  async function token() {
    if (ENSAIO) { try { return sessionStorage.getItem('imts_token_teste'); } catch (e) { return null; } }
    const { data } = await supa().auth.getSession();
    return data?.session?.access_token || null;
  }

  // ---------- porta única ----------
  function erro(msg, codigo) { const e = new Error(msg); e.codigo = codigo; return e; }
  async function chamar(fn, args) {
    const t = await token();
    if (!t) { irParaEntrada(); throw erro('sessão encerrada: entre de novo', 'sessao'); }
    const h = { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + t, 'Accept': 'application/json' };
    if (C.anonKey) h.apikey = C.anonKey;
    const emp = empresa(); if (emp) h['x-empresa'] = emp;
    let r;
    try {
      r = await fetch(REST + '/rpc/imts', { method: 'POST', headers: h, body: JSON.stringify({ p_fn: fn, p_args: args || {} }) });
    } catch (e) { throw erro('sem conexão com o servidor; tente de novo', 'rede'); }
    const texto = await r.text();
    let corpo = null; try { corpo = texto ? JSON.parse(texto) : null; } catch (e) { corpo = texto; }
    if (r.status === 401) { irParaEntrada(); throw erro('sessão encerrada: entre de novo', 'sessao'); }
    if (!r.ok) throw erro(limpar(corpo?.message || corpo?.hint || String(texto || r.statusText)), corpo?.code);
    return corpo;
  }
  function limpar(m) { return String(m || 'erro').replace(/^(ERROR:\s*)?(P0001:\s*)?/, '').trim(); }

  // ---------- funções do servidor (Google, IA): o navegador nunca vê a chave ----------
  async function funcao(nome, acao, dados) {
    const t = await token();
    if (!t) { irParaEntrada(); throw erro('sessão encerrada: entre de novo', 'sessao'); }
    const h = { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + t };
    if (C.anonKey) h.apikey = C.anonKey;
    const emp = empresa(); if (emp) h['x-empresa'] = emp;
    let r;
    try { r = await fetch(FUNCOES + '/' + nome, { method: 'POST', headers: h, body: JSON.stringify({ acao, ...(dados || {}) }) }); }
    catch (e) { throw erro('sem conexão com o servidor; tente de novo', 'rede'); }
    const corpo = await r.json().catch(() => ({}));
    if (!r.ok) throw erro(corpo?.erro || corpo?.message || 'falha na função ' + nome, corpo?.codigo || r.status);
    return corpo;
  }
  const google = (acao, dados) => funcao('google', acao, dados);
  const ia = (acao, dados) => funcao('ia', acao, dados);
  const servidor = (nome, acao, dados) => funcao(nome, acao, dados);   // outras funções do servidor (ex.: conexoes)

  // ---------- empresa em uso (vai no cabeçalho x-empresa; o banco confere a permissão) ----------
  function empresa() { return guardar.ler('empresa'); }
  function escolherEmpresa(id) { guardar.gravar('empresa', id || null); document.dispatchEvent(new CustomEvent('imts:empresa', { detail: id })); }

  // ---------- sessão ----------
  function irParaEntrada() {
    if (/\/(index\.html)?$/.test(location.pathname)) return;
    location.href = 'index.html?volta=' + encodeURIComponent(location.pathname.split('/').pop() + location.search);
  }
  async function entrarGoogle() {
    const volta = new URLSearchParams(location.search).get('volta') || 'index.html';
    const { error } = await supa().auth.signInWithOAuth({ provider: 'google', options: {
      redirectTo: new URL(volta, location.href).href, queryParams: { hd: C.dominio || 'imts.com.br', prompt: 'select_account' } } });
    if (error) throw erro(error.message);
  }
  async function entrarEmail(email) {
    const { error } = await supa().auth.signInWithOtp({ email, options: { emailRedirectTo: new URL('index.html', location.href).href, shouldCreateUser: true } });
    if (error) throw erro(error.message);
  }
  async function sair() {
    guardar.gravar('empresa', null); quem = null;
    if (ENSAIO) { try { sessionStorage.removeItem('imts_token_teste'); } catch (e) { /* nada */ } }
    else { try { await supa().auth.signOut(); } catch (e) { /* segue */ } }
    location.href = 'index.html';
  }
  async function quemSou(forcar) {
    if (quem && !forcar) return quem;
    quem = await chamar('rt.quem_sou', {});
    // empresa em uso: a lembrada, se ainda for permitida; senão a primeira
    if (quem.tipo === 'interno') {
      const ids = (quem.empresas || []).map(e => e.id);
      if (!ids.includes(empresa())) escolherEmpresa(ids[0] || null);
    }
    return quem;
  }

  // ---------- menu por papel ----------
  const MODULOS = [
    { id: 'mesa', nome: 'Mesa', href: 'mesa.html', para: q => q.tipo === 'interno' },
    { id: 'painel', nome: 'Painel', href: 'painel.html', para: q => q.tipo === 'interno' },
    { id: 'central', nome: 'Central', href: 'central.html', para: q => q.tipo === 'interno' },
    { id: 'acervo', nome: 'Acervo', href: 'acervo.html', para: q => q.tipo === 'interno' },
    { id: 'biblioteca', nome: 'Biblioteca', href: 'biblioteca.html', para: q => q.tipo === 'interno' },
    { id: 'admin', nome: 'Administração', href: 'admin.html', para: q => q.tipo === 'interno' && q.administra },
    { id: 'portal', nome: 'Portal', href: 'portal.html', para: q => q.tipo === 'externo' }
  ];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  function barra(modulo) {
    const el = document.getElementById('imts-barra');
    if (!el || !quem) return;
    const mods = MODULOS.filter(m => m.para(quem));
    const emps = quem.tipo === 'interno' ? (quem.empresas || []) : [];
    el.innerHTML = `
      <a class="imts-marca" href="index.html">IMTS.OS</a>
      <nav class="imts-menu" aria-label="Módulos">${mods.map(m => `<a href="${m.href}"${m.id === modulo ? ' aria-current="page"' : ''}>${esc(m.nome)}</a>`).join('')}</nav>
      <div class="imts-quem">
        ${emps.length > 1 ? `<label>Empresa <select id="imts-empresa">${emps.map(e => `<option value="${esc(e.id)}"${e.id === empresa() ? ' selected' : ''}>${esc(e.nome)}</option>`).join('')}</select></label>`
          : emps.length === 1 ? `<span class="imts-emp">${esc(emps[0].nome)}</span>` : ''}
        <span class="imts-nome">${esc(quem.nome || '')}</span>
        <button type="button" id="imts-sair">Sair</button>
      </div>`;
    document.getElementById('imts-sair').onclick = sair;
    const s = document.getElementById('imts-empresa');
    if (s) s.onchange = () => escolherEmpresa(s.value);
  }

  // Abre um módulo: exige sessão e o tipo certo de usuário; desenha a barra; devolve quem usa.
  async function iniciar(opc) {
    const o = opc || {};
    if (!ENSAIO) {
      const { data } = await supa().auth.getSession();
      if (!data?.session) { irParaEntrada(); return new Promise(() => {}); }
    }
    let q;
    try { q = await quemSou(); } catch (e) { if (e.codigo === 'sessao') return new Promise(() => {}); throw e; }
    if (q.tipo === 'sem_cadastro' || (o.exige && o.exige !== 'qualquer' && q.tipo !== o.exige) || (o.admin && !q.administra)) {
      location.href = 'index.html'; return new Promise(() => {});
    }
    barra(o.modulo);
    return q;
  }

  window.IMTS = { chamar, google, ia, servidor, iniciar, quemSou, empresa, escolherEmpresa, sair, entrarGoogle, entrarEmail, modulos: () => MODULOS.filter(m => quem && m.para(quem)),
    supa, esc, ensaio: ENSAIO, guardar };
})();
