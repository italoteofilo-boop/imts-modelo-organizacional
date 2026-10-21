// Edge Function telegram_app do IMTS.OS (Mini App do Telegram): ver tratar.ts. Implantar com verify_jwt DESLIGADO
// (a identidade vem da assinatura do initData do Telegram, conferida com o token do bot que está no cofre).
import postgres from "npm:postgres@3.4.4";
import { tratar } from "./tratar.ts";
const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { max: 2, prepare: false });
Deno.serve((req) => tratar(req, { sql, fetch }));
