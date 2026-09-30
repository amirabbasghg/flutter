import type { Env } from "../types";
import { fromBase64Url, timingSafeEqual, toBase64Url } from "./encoding";

const DEFAULT_ITERATIONS = 100_000;
const MIN_LENGTH = 8;
const MAX_LENGTH = 128; // reject huge inputs before spending CPU on hashing

export function validatePassword(password: unknown): string | null {
  if (typeof password !== "string") return "invalid-password";
  if (password.length < MIN_LENGTH) return "password-too-short";
  if (password.length > MAX_LENGTH) return "password-too-long";
  return null;
}

function iterationsFor(env: Pick<Env, "PBKDF2_ITERATIONS">): number {
  const n = Number(env.PBKDF2_ITERATIONS);
  return Number.isInteger(n) && n > 0 ? n : DEFAULT_ITERATIONS;
}

// password -> HMAC(pepper) -> PBKDF2(salt). Pepper lives only in a Worker secret.
async function derive(
  password: string,
  pepper: string,
  salt: Uint8Array,
  iterations: number,
): Promise<Uint8Array> {
  if (!pepper) {
    throw new Error(
      "PASSWORD_PEPPER is not set. Create backend/.dev.vars (local) or run `wrangler secret put PASSWORD_PEPPER`.",
    );
  }
  const enc = new TextEncoder();
  const hmacKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(pepper),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const peppered = await crypto.subtle.sign("HMAC", hmacKey, enc.encode(password));
  const pbkdfKey = await crypto.subtle.importKey("raw", peppered, "PBKDF2", false, [
    "deriveBits",
  ]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations },
    pbkdfKey,
    256,
  );
  return new Uint8Array(bits);
}

// Stored format: pbkdf2$<iterations>$<salt b64url>$<hash b64url>
export async function hashPassword(
  password: string,
  env: Pick<Env, "PASSWORD_PEPPER" | "PBKDF2_ITERATIONS">,
): Promise<string> {
  const iterations = iterationsFor(env);
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await derive(password, env.PASSWORD_PEPPER, salt, iterations);
  return `pbkdf2$${iterations}$${toBase64Url(salt)}$${toBase64Url(hash)}`;
}

export async function verifyPassword(
  password: string,
  stored: string,
  env: Pick<Env, "PASSWORD_PEPPER">,
): Promise<boolean> {
  const [alg, iterStr, saltB64, hashB64] = stored.split("$");
  const iterations = Number(iterStr);
  if (alg !== "pbkdf2" || !Number.isInteger(iterations) || !saltB64 || !hashB64) {
    return false;
  }
  const actual = await derive(password, env.PASSWORD_PEPPER, fromBase64Url(saltB64), iterations);
  return timingSafeEqual(actual, fromBase64Url(hashB64));
}

// True when the stored hash uses fewer iterations than currently configured
// (lets login silently upgrade old hashes).
export function needsRehash(stored: string, env: Pick<Env, "PBKDF2_ITERATIONS">): boolean {
  return Number(stored.split("$")[1]) < iterationsFor(env);
}
