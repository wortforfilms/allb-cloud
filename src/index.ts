import init, {
  PaniniSutraEngine,
  tokenize_brahmi_zerocopy,
  lookup_ashtadhyayi_sutra,
} from "../pkg/maataa_runtime.js";
import wasmModule from "../pkg/maataa_runtime_bg.wasm";

export interface Env {
  RATE_LIMITER: {
    limit: (options: { key: string }) => Promise<{ success: boolean }>;
  };
}

// Global engine singleton across warm worker isolates
let engineInstance: PaniniSutraEngine | null = null;
let isWasmInitialized = false;

/**
 * Ensures WASM module memory is loaded once per isolate lifetime
 */
async function ensureWasmInitialized(): Promise<PaniniSutraEngine> {
  if (!isWasmInitialized) {
    await init({ module_or_path: wasmModule });
    engineInstance = new PaniniSutraEngine();
    isWasmInitialized = true;
  }
  return engineInstance!;
}

// Whitelisted origins for domain locking
const ALLOWED_ORIGINS = [
  "https://allb.xyz",
  "https://brahmi.allb.xyz",
  "http://localhost:5173", // Local dev server
];

/**
 * Generates CORS response headers dynamically based on request Origin
 */
function getCorsHeaders(request: Request): HeadersInit {
  const origin = request.headers.get("Origin");
  const isAllowed = origin && ALLOWED_ORIGINS.includes(origin);
  const allowOrigin = isAllowed ? origin : "https://allb.xyz";

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

/**
 * JSON Response Helper with embedded CORS headers
 */
function jsonResponse(request: Request, data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...getCorsHeaders(request),
    },
  });
}

// ============================================================================
// WORKER ENTRYPOINT HANDLER
// ============================================================================

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const corsHeaders = getCorsHeaders(request);

    // 1. Handle CORS Preflight OPTIONS Request
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders,
      });
    }

    if (request.method !== "POST") {
      return jsonResponse(request, { error: "Method Not Allowed" }, 405);
    }

    // 2. Rate Limiting Check
    const clientIp = request.headers.get("cf-connecting-ip") || "anonymous";
    if (env.RATE_LIMITER) {
      const { success } = await env.RATE_LIMITER.limit({ key: clientIp });
      if (!success) {
        return jsonResponse(
          request,
          { error: "Too Many Requests: Rate limit exceeded" },
          429
        );
      }
    }

    // 3. Dispatch WASM Engine Execution
    try {
      const engine = await ensureWasmInitialized();
      const body = (await request.json()) as {
        action: "evaluate" | "tokenize" | "lookup";
        base_term?: string;
        pratyaya?: string;
        text?: string;
        sutra_id?: string;
      };

      switch (body.action) {
        case "evaluate": {
          const derivation = engine.evaluate_simple(
            body.base_term || "",
            body.pratyaya || ""
          );
          return jsonResponse(request, { success: true, derivation });
        }

        case "tokenize": {
          const tokens = tokenize_brahmi_zerocopy(body.text || "");
          return jsonResponse(request, { success: true, tokens: Array.from(tokens) });
        }

        case "lookup": {
          const sutra = lookup_ashtadhyayi_sutra(body.sutra_id || "1.1.1");
          return jsonResponse(request, { success: true, sutra });
        }

        default:
          return jsonResponse(request, { error: "Invalid action type" }, 400);
      }
    } catch (err: any) {
      return jsonResponse(
        request,
        { error: err.message || "WASM Evaluation Failure" },
        500
      );
    }
  },
};