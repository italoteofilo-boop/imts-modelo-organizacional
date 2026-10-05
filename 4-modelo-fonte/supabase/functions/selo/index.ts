// Edge Function selo do IMTS.OS: ver tratar.ts. Implantar com verify_jwt desligado (quem chama é o banco, com X-IMTS-Chave).
import postgres from "npm:postgres@3.4.4";
import { tratar } from "./tratar.ts";
const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { max: 1, prepare: false });
Deno.serve((req) => tratar(req, { sql, fetch }));
