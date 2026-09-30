import { SignJWT, jwtVerify } from "jose";
import type { Env } from "../types";
import { toBase64Url } from "./encoding";

const ISSUER = "expense-app";
const AUDIENCE = "expense-app-api";
export const ACCESS_TOKEN_TTL_SECONDS = 60 * 60; // 1 hour
export const REFRESH_TOKEN_TTL_SECONDS = 60 * 60 * 24 * 60; // 60 days
export const RESET_TOKEN_TTL_SECONDS = 60 * 30; // 30 minutes

const secretKey = (env: Pick<Env, "JWT_SECRET">) => {
  if (!env.JWT_SECRET) {
    throw new Error(
      "JWT_SECRET is not set. Create backend/.dev.vars (local) or run `wrangler secret put JWT_SECRET`.",
    );
  }
  return new TextEncoder().encode(env.JWT_SECRET);
};

export async function signAccessToken(
  userId: string,
  env: Pick<Env, "JWT_SECRET">,
): Promise<string> {
  return new SignJWT({})
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuer(ISSUER)
    .setAudience(AUDIENCE)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TOKEN_TTL_SECONDS}s`)
    .sign(secretKey(env));
}

// Returns the user id, or null if the token is invalid/expired.
export async function verifyAccessToken(
  token: string,
  env: Pick<Env, "JWT_SECRET">,
): Promise<string | null> {
  const key = secretKey(env); // throws a clear error if JWT_SECRET is missing
  try {
    const { payload } = await jwtVerify(token, key, {
      algorithms: ["HS256"],
      issuer: ISSUER,
      audience: AUDIENCE,
    });
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Random opaque token (refresh / password reset). Give `token` to the client,
// store only `hash` in D1.
export async function generateOpaqueToken(): Promise<{ token: string; hash: string }> {
  const token = toBase64Url(crypto.getRandomValues(new Uint8Array(32)));
  return { token, hash: await sha256Hex(token) };
}
