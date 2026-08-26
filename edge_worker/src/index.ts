export interface Env {
  Z0_NONCE_KV: KVNamespace;
}

export interface VespEnvelope {
  canonical_hash: string;
  nonce: string;
  signature: string;
  payload: {
    script_type: string;
    aksharas: string[];
    vector_dim: number;
    alignment_score: number;
    timestamp: number;
  };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method Not Allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    try {
      const envelope: VespEnvelope = await request.json();
      const { canonical_hash, nonce, signature, payload } = envelope;

      if (!canonical_hash || !nonce || !signature || !payload) {
        return new Response(JSON.stringify({ error: "Invalid VESP Packet Format" }), { status: 400 });
      }

      // Check for replayed nonces in KV store
      const existingNonce = await env.Z0_NONCE_KV.get(nonce);
      if (existingNonce) {
        console.log(`[Z0-VESP EDGE] REPLAY REJECTED: ${nonce}`);
        return new Response(JSON.stringify({ error: "FORBIDDEN: Replay Attack Detected" }), {
          status: 403,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Save nonce with a 300-second TTL
      await env.Z0_NONCE_KV.put(nonce, "1", { expirationTtl: 300 });

      console.log(`[Z0-VESP EDGE] Packet Accepted!`);
      console.log(`               • Script Type : ${payload.script_type}`);
      console.log(`               • Aksharas    : ${JSON.stringify(payload.aksharas)}`);
      console.log(`               • Alignment   : ${payload.alignment_score}`);

      return new Response(
        JSON.stringify({
          status: "ACCEPTED",
          node: "LOCAL_EDGE_01",
          canonical_hash,
          timestamp: Date.now(),
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }
      );
    } catch (err) {
      return new Response(JSON.stringify({ error: "Malformed Payload", details: String(err) }), { status: 400 });
    }
  },
};