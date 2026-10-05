// Copie para config.js na implantação e preencha com os dados do projeto Supabase de PRODUÇÃO.
// A chave publicável (anon) é pública por desenho: a segurança está no login e nas permissões do banco.
// Nunca ponha aqui a chave de serviço (service_role) nem segredo algum.
window.IMTS_CONFIG = {
  supabaseUrl: 'https://<ref-do-projeto>.supabase.co',
  anonKey: '<chave publicável do projeto>',
  dominio: 'imts.email'          // domínio do Google Workspace aceito no login de quem é de dentro
};
