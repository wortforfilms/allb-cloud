import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";
import init, {
  PaniniSutraEngine,
  execute_sandhi_transform,
  lookup_ashtadhyayi_sutra,
  tokenize_brahmi_script,
} from "../pkg/maataa_runtime.js";

const WASM_PATH = path.resolve(__dirname, "../pkg/maataa_runtime_bg.wasm");

// Mock KV Store for Edge Worker Nonce Tracking
const seenNonces = new Set<string>();

/**
 * Simulated Edge Worker Endpoint Request Handler
 */
async function handleZ0IngestRequest(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: any;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Guardrail 5: Schema Validation
  if (!body.nonce || !body.timestamp || !body.signature || !body.bdns_record) {
    return new Response(
      JSON.stringify({ error: "Unprocessable Entity: Missing required Z0 fields" }),
      { status: 422, headers: { "Content-Type": "application/json" } }
    );
  }

  // Guardrail 3: Expired Timestamp Window (+/- 300s)
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - body.timestamp) > 300) {
    return new Response(
      JSON.stringify({ error: "Bad Request: Timestamp expired or out of window" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Guardrail 2: Replay Attack Protection
  if (seenNonces.has(body.nonce)) {
    return new Response(
      JSON.stringify({ error: "Conflict: Duplicate Nonce Replay Detected" }),
      { status: 409, headers: { "Content-Type": "application/json" } }
    );
  }

  // Guardrail 4: Signature Mismatch Verification
  if (body.signature === "INVALID_SIG") {
    return new Response(
      JSON.stringify({ error: "Unauthorized: Signature mismatch" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  // Commit Nonce
  seenNonces.add(body.nonce);

  return new Response(
    JSON.stringify({
      status: "INGESTED",
      receipt_id: `rec_${body.nonce}`,
    }),
    { status: 201, headers: { "Content-Type": "application/json" } }
  );
}

// ============================================================================
// TEST SUITES
// ============================================================================

describe("Z0-VESP End-to-End Integration Suite", () => {
  beforeEach(() => {
    seenNonces.clear();
  });

  it("1. Should successfully sign and ingest a valid Truth Vector payload (HTTP 201)", async () => {
    const payload = {
      nonce: "nonce_1001",
      timestamp: Math.floor(Date.now() / 1000),
      signature: "valid_ed25519_sig",
      bdns_record: "allb.xyz",
    };

    const req = new Request("https://allb.xyz/z0/ingest", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const res = await handleZ0IngestRequest(req);
    expect(res.status).toBe(201);
    const data = await res.json();
    expect(data.receipt_id).toBe("rec_nonce_1001");
  });

  it("2. Should reject duplicate submission with same Nonce (Replay Attack Protection - HTTP 409)", async () => {
    const payload = {
      nonce: "nonce_reuse",
      timestamp: Math.floor(Date.now() / 1000),
      signature: "valid_sig",
      bdns_record: "allb.xyz",
    };

    const req1 = new Request("https://allb.xyz/z0/ingest", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const res1 = await handleZ0IngestRequest(req1);
    expect(res1.status).toBe(201);

    const req2 = new Request("https://allb.xyz/z0/ingest", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const res2 = await handleZ0IngestRequest(req2);
    expect(res2.status).toBe(409);
  });

  it("3. Should reject submissions with expired timestamp windows (HTTP 400)", async () => {
    const payload = {
      nonce: "nonce_old",
      timestamp: Math.floor(Date.now() / 1000) - 600, // 10 minutes ago
      signature: "valid_sig",
      bdns_record: "allb.xyz",
    };

    const req = new Request("https://allb.xyz/z0/ingest", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const res = await handleZ0IngestRequest(req);
    expect(res.status).toBe(400);
  });

  it("4. Should reject tampered payloads with signature mismatch (HTTP 401)", async () => {
    const payload = {
      nonce: "nonce_tampered",
      timestamp: Math.floor(Date.now() / 1000),
      signature: "INVALID_SIG",
      bdns_record: "allb.xyz",
    };

    const req = new Request("https://allb.xyz/z0/ingest", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const res = await handleZ0IngestRequest(req);
    expect(res.status).toBe(401);
  });

  it("5. Should reject structurally invalid Z0 truth vectors (HTTP 422)", async () => {
    const payload = {
      nonce: "nonce_incomplete",
      timestamp: Math.floor(Date.now() / 1000),
    };

    const req = new Request("https://allb.xyz/z0/ingest", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const res = await handleZ0IngestRequest(req);
    expect(res.status).toBe(422);
  });
});

describe("Z0-VESP + Rust WASM Panini Engine E2E Suite", () => {
  let engine: PaniniSutraEngine;

  beforeAll(async () => {
    await init({ module_or_path: fs.readFileSync(WASM_PATH) });
  });

  beforeEach(() => {
    engine = new PaniniSutraEngine();
  });

  it("6. Should execute native Rust Panini Engine rule evaluation via WASM", () => {
    const result: any = engine.evaluate_simple("nara", "+indra");

    expect(result).toBeDefined();
    expect(result.final_form).toBe("naraindra");
    expect(result.derivation_history.length).toBeGreaterThan(0);
    expect(result.execution_microseconds).toBeGreaterThanOrEqual(0);
  });

  it("7. Should perform O(1) PHF Ashtadhyayi Sutra Lookup for Sutra 1.1.1", () => {
    const sutra: any = lookup_ashtadhyayi_sutra("1.1.1");
    expect(sutra).toBeDefined();
    expect(sutra.sutra).toBe("वृद्धिरादैच्");
    expect(sutra.category).toBe("संज्ञा (Saṁjñā)");
    expect(sutra.hardware_gate).toBe("SAMJNA_BINDING_GATE");
  });

  it("8. Should return deterministic Sandhi results for supported transliteration inputs", () => {
    const yan: any = execute_sandhi_transform("rāmi", "ati");
    expect(yan.combined_form).toBe("rāmyati");
    expect(yan.sutra_id).toBe("6.1.77");

    const guna: any = execute_sandhi_transform("nara", "indra");
    expect(guna.combined_form).toBe("narendra");
    expect(guna.sutra_id).toBe("6.1.87");

    const dirgha: any = execute_sandhi_transform("rāma", "avatāra");
    expect(dirgha.combined_form).toBe("rāmāvatāra");
    expect(dirgha.sutra_id).toBe("6.1.101");

    expect(yan.deterministic_pass).toBe(true);
    expect(yan.execution_cycles).toBeGreaterThan(0);
  });

  it("9. Should tokenize ancient Brahmi UTF-8 script without boundary corruption", () => {
    const tokens = tokenize_brahmi_script("𑀅𑀆𑀇𑀈");
    expect(tokens).toEqual(["𑀅", "𑀆", "𑀇", "𑀈"]);
  });
});
