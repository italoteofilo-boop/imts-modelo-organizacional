// Selo de assinatura do IMTS.OS: ECDSA P-256 com SHA-256 (WebCrypto), usado pelas funções assinatura e verificar.
// A chave privada vive só no cofre (segredo assinatura_chave_privada, em JWK); a pública fica em doc.assinatura_chave.
import { b64url, b64urlDecode } from "./servidor.ts";

export const ECDSA = { name: "ECDSA", namedCurve: "P-256" } as const;
const ASSINAR = { name: "ECDSA", hash: "SHA-256" } as const;
const bytes = (t: string) => new TextEncoder().encode(t);

export async function sha256Hex(b: Uint8Array | string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", typeof b === "string" ? bytes(b) : b as Uint8Array<ArrayBuffer>));
  return [...d].map((x) => x.toString(16).padStart(2, "0")).join("");
}

// identificador da chave: impressão SHA-256 da chave pública (RFC 7638), em base64url
export async function kidDe(jwk: JsonWebKey): Promise<string> {
  const canon = JSON.stringify({ crv: jwk.crv, kty: jwk.kty, x: jwk.x, y: jwk.y });
  return b64url(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes(canon))));
}

export function soPublica(jwk: JsonWebKey): JsonWebKey {
  return { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y };
}

export async function gerarPar(): Promise<{ privada: JsonWebKey; publica: JsonWebKey; kid: string }> {
  const par = await crypto.subtle.generateKey(ECDSA, true, ["sign", "verify"]) as CryptoKeyPair;
  const privada = await crypto.subtle.exportKey("jwk", par.privateKey) as JsonWebKey;
  const publica = soPublica(await crypto.subtle.exportKey("jwk", par.publicKey) as JsonWebKey);
  return { privada, publica, kid: await kidDe(publica) };
}

export async function chavePrivada(jwk: JsonWebKey): Promise<CryptoKey> {
  return await crypto.subtle.importKey("jwk", { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y, d: jwk.d }, ECDSA, false, ["sign"]);
}

// assinatura em formato bruto (r || s, 64 bytes) e base64url
export async function assinarTexto(privada: CryptoKey, texto: string): Promise<string> {
  return b64url(new Uint8Array(await crypto.subtle.sign(ASSINAR, privada, bytes(texto))));
}

export async function conferirTexto(publica: JsonWebKey, texto: string, assinatura: string): Promise<boolean> {
  try {
    const k = await crypto.subtle.importKey("jwk", soPublica(publica), ECDSA, false, ["verify"]);
    return await crypto.subtle.verify(ASSINAR, k, b64urlDecode(assinatura) as Uint8Array<ArrayBuffer>, bytes(texto));
  } catch {
    return false;
  }
}
