import { describe, it, expect, beforeAll } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";

// Import JS glue and WASM exported lookup function from pkg
import init, { lookup_ashtadhyayi_sutra } from "../pkg/maataa_runtime.js";

const WASM_PATH = path.resolve(__dirname, "../pkg/maataa_runtime_bg.wasm");

describe("Ashtadhyayi PHF Static Map WASM Lookups", () => {
  beforeAll(async () => {
    // Load WASM binary directly from output package
    const wasmBytes = fs.readFileSync(WASM_PATH);
    await init({ module_or_path: wasmBytes });
  });

  it("1. Should resolve Sutra 1.1.1 in O(1) time with correct metadata", () => {
    const sutra: any = lookup_ashtadhyayi_sutra("1.1.1");

    expect(sutra).toBeDefined();
    expect(sutra.id).toBe("1.1.1");
    expect(sutra.sutra).toBe("वृद्धिरादैच्");
    expect(sutra.category).toBe("संज्ञा (Saṁjñā)");
    expect(sutra.hardware_gate).toBe("SAMJNA_BINDING_GATE");
  });

  it("2. Should resolve Sutra 1.1.2 (अदेङ् गुणः) correctly", () => {
    const sutra: any = lookup_ashtadhyayi_sutra("1.1.2");

    expect(sutra).toBeDefined();
    expect(sutra.id).toBe("1.1.2");
    expect(sutra.sutra).toBe("अदेङ् गुणः");
    expect(sutra.category).toBe("संज्ञा (Saṁjñā)");
  });

  it("3. Should reject invalid/non-existent Sutra IDs with appropriate error", () => {
    expect(() => lookup_ashtadhyayi_sutra("9.9.999")).toThrow(
      "Sutra ID not found in Ashtadhyayi static hash map"
    );
    // The first pada has 75 sutras; the old placeholder dataset answered this one.
    expect(() => lookup_ashtadhyayi_sutra("1.1.101")).toThrow(
      "Sutra ID not found in Ashtadhyayi static hash map"
    );
  });

  it("4. Should return the last sutra, unclassified sutras as null, and the attribution", () => {
    const sutra: any = lookup_ashtadhyayi_sutra("8.4.68");
    expect(sutra.sutra).toBe("अ अ");
    expect(sutra.category).toBeNull();
    expect(sutra.hardware_gate).toBe("DEFAULT_GATE");
    expect(sutra.source).toContain("MIT");
  });
});
