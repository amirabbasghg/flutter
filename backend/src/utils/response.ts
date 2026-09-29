import { UserRow } from "../types";

export function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}

export function response(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(),
    },
  });
}

export function getUserResponse(user: UserRow, friendIds: string[]) {
  return {
    id: user.id,
    name: user.name,
    email: user.email ?? "",
    photoURL: user.photo_url,
    accountNumber: user.account_number,
    friendIds,
  };
}