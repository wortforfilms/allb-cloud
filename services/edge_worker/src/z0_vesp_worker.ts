// import init, { PaniniEngineWasm } from '../pkg/panini_engine.js';
// import paniniWasmModule from '../pkg/panini_engine_bg.wasm';


export interface Env {
  Z0_NONCE_KV: KVNamespace;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const nonce = request.headers.get("X-Z0-Nonce");
    const signature = request.headers.get("X-Z0-Signature");

    if (!nonce || !signature) {
      return new Response(JSON.stringify({ error: "Missing protocol headers" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Replay attack prevention check
    const existingNonce = await env.Z0_NONCE_KV.get(nonce);
    if (existingNonce) {
      return new Response(JSON.stringify({ error: "Nonce replayed" }), { status: 403 });
    }

    await env.Z0_NONCE_KV.put(nonce, "1", { expirationTtl: 300 }); // 5 min TTL

    const payload = await request.json();
    return new Response(JSON.stringify({ status: "VESP_ACCEPTED", payload }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  },
};