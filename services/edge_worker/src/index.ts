import { initSync, execute_sandhi_transform, lookup_ashtadhyayi_sutra, tokenize_brahmi_script } from "../../../pkg/maataa_runtime.js";
import wasmModule from "../../../pkg/maataa_runtime_bg.wasm";

function ensureWasmLoaded() {
  initSync({ module: wasmModule });
}

function json(data: unknown, status = 200): Response {
  return Response.json(data, {
    status,
    headers: { "cache-control": "no-store" },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handleRequest(request, env);
    } catch (error) {
      const malformedJson = error instanceof SyntaxError;
      console.error(JSON.stringify({
        message: "request failed",
        path: new URL(request.url).pathname,
        error: error instanceof Error ? error.message : String(error),
      }));
      return json(
        { error: malformedJson ? "Malformed JSON request" : "Internal server error" },
        malformedJson ? 400 : 500,
      );
    }
  },
} satisfies ExportedHandler<Env>;

async function handleRequest(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({ status: "OK", service: "maataa-sovereign-worker", environment: env.ENVIRONMENT });
    }

    if (request.method === "POST") {
      const contentLength = Number(request.headers.get("content-length") ?? "0");
      if (contentLength > 65_536) {
        return json({ error: "Request body exceeds 64 KiB" }, 413);
      }
    }

    if (url.pathname === "/api/z0/sandhi" && request.method === "POST") {
      const body: unknown = await request.json();

      if (!isSandhiRequest(body)) {
        return json({ error: "Expected non-empty string fields: left, right" }, 400);
      }

      ensureWasmLoaded();
      const result = execute_sandhi_transform(body.left, body.right);
      return json(result);
    }

    if (url.pathname.startsWith("/api/z0/sutra/") && request.method === "GET") {
      const sutraId = decodeURIComponent(url.pathname.slice("/api/z0/sutra/".length));
      if (!/^\d+\.\d+\.\d+$/.test(sutraId)) {
        return json({ error: "Invalid Sutra ID" }, 400);
      }

      ensureWasmLoaded();
      try {
        return json(lookup_ashtadhyayi_sutra(sutraId));
      } catch {
        return json({ error: `Sutra ${sutraId} not found` }, 404);
      }
    }

    if (url.pathname === "/api/z0/tokenize-brahmi" && request.method === "POST") {
      const body: unknown = await request.json();
      if (!isTokenizeRequest(body)) {
        return json({ error: "Expected string field: text" }, 400);
      }

      ensureWasmLoaded();
      return json({ tokens: tokenize_brahmi_script(body.text) });
    }

    return new Response("Not Found", { status: 404 });
}

function isSandhiRequest(value: unknown): value is { left: string; right: string } {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return typeof candidate.left === "string" && candidate.left.length > 0
    && typeof candidate.right === "string" && candidate.right.length > 0;
}

function isTokenizeRequest(value: unknown): value is { text: string } {
  if (typeof value !== "object" || value === null) return false;
  return typeof (value as Record<string, unknown>).text === "string";
}
