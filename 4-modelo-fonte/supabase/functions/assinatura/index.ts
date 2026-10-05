// Edge Function assinatura do IMTS.OS: ver tratar.ts. Implantar com verify_jwt LIGADO (só quem tem login chama;
// a plataforma confere a assinatura do token e o banco decide a permissão). O selo automático fica na função selo.
import postgres from "npm:postgres@3.4.4";
import { tratar } from "./tratar.ts";
const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { max: 1, prepare: false });
Deno.serve((req) => tratar(req, { sql, fetch }));
