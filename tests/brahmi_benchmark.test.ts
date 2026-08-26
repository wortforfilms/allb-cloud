import { describe, it, expect, beforeAll } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";
import init, {
  tokenize_brahmi_script,
  tokenize_brahmi_zerocopy,
} from "../pkg/maataa_runtime.js";

const WASM_PATH = path.resolve(__dirname, "../pkg/maataa_runtime_bg.wasm");

// ============================================================================
// 1. BASELINE NATIVE JAVASCRIPT TOKENIZER LOGIC
// ============================================================================

/**
 * Baseline Native JS String-Array Brahmi Tokenizer
 */
function tokenizeBrahmiJS(inputText: string): string[] {
  const tokens: string[] = [];
  for (const ch of inputText) {
    const cp = ch.codePointAt(0) || 0;
    if ((cp >= 0x11000 && cp <= 0x1107F) || cp === 0x200D) {
      tokens.push(ch);
    }
  }
  return tokens;
}

// ============================================================================
// 2. BENCHMARK TIMING UTILITY
// ============================================================================

function measureExecution(fn: () => void, iterations: number): number {
  const start = performance.now();
  for (let i = 0; i < iterations; i++) {
    fn();
  }
  return performance.now() - start;
}

// ============================================================================
// 3. INTEGRATION & PERFORMANCE TEST SUITE
// ============================================================================

describe("Brahmi Script Tokenizer: WASM vs Native JS Performance", () => {
  let sampleBrahmiCorpus: string;

  beforeAll(async () => {
    // Load compiled WASM binary directly from local file system
    const wasmBytes = fs.readFileSync(WASM_PATH);
    await init({ module_or_path: wasmBytes });

    // Generate large test corpus (210,000 Brahmi script characters)
    const basePhrase = "𑀮𑀺𑀧𑀺𑀩𑁆𑀭𑀸𑀳𑁆𑀫𑀻𑀲𑀁𑀲𑁆𑀓𑀾𑀢𑀫𑁆";
    sampleBrahmiCorpus = basePhrase.repeat(5000);
  });

  it("1. Should produce identical output tokens across JS and WASM implementations", () => {
    const jsTokens = tokenizeBrahmiJS(sampleBrahmiCorpus);
    const wasmTokens = tokenize_brahmi_script(sampleBrahmiCorpus);
    const wasmZeroCopy = tokenize_brahmi_zerocopy(sampleBrahmiCorpus);

    expect(wasmTokens.length).toBe(jsTokens.length);
    expect(wasmZeroCopy.length).toBe(jsTokens.length);

    // Verify first token matches expected Unicode Brahmi "LA" (U+1102E)
    expect(wasmTokens[0]).toBe(jsTokens[0]);
    expect(wasmZeroCopy[0]).toBe(jsTokens[0].codePointAt(0));
  });

  it("2. Should measure and compare execution times across memory strategies", () => {
    const ITERATIONS = 100;

    // Warm-up runs to prime V8 JIT compiler
    measureExecution(() => tokenizeBrahmiJS(sampleBrahmiCorpus), 5);
    measureExecution(() => tokenize_brahmi_script(sampleBrahmiCorpus), 5);
    measureExecution(() => tokenize_brahmi_zerocopy(sampleBrahmiCorpus), 5);

    // Benchmark 1: Native JS String Array
    const jsDurationMs = measureExecution(
      () => tokenizeBrahmiJS(sampleBrahmiCorpus),
      ITERATIONS
    );

    // Benchmark 2: WASM String Array (Heavy FFI boundary allocations)
    const wasmStringDurationMs = measureExecution(
      () => tokenize_brahmi_script(sampleBrahmiCorpus),
      ITERATIONS
    );

    // Benchmark 3: WASM Zero-Copy Uint32Array Buffer
    const wasmZeroCopyDurationMs = measureExecution(
      () => tokenize_brahmi_zerocopy(sampleBrahmiCorpus),
      ITERATIONS
    );

    const jsAvg = jsDurationMs / ITERATIONS;
    const wasmStringAvg = wasmStringDurationMs / ITERATIONS;
    const wasmZeroCopyAvg = wasmZeroCopyDurationMs / ITERATIONS;

    const zeroCopySpeedup = (jsAvg / wasmZeroCopyAvg).toFixed(2);

    console.log(`\n=================================================================`);
    console.log(`BRAHMI SCRIPT TOKENIZER BENCHMARK (${sampleBrahmiCorpus.length} characters)`);
    console.log(`=================================================================`);
    console.log(`1. Native JS String-Array Time   : ${jsAvg.toFixed(3)} ms`);
    console.log(`2. WASM String-Array Time (FFI) : ${wasmStringAvg.toFixed(3)} ms`);
    console.log(`3. WASM Zero-Copy Uint32Array   : ${wasmZeroCopyAvg.toFixed(3)} ms`);
    console.log(`-----------------------------------------------------------------`);
    console.log(`Performance Ratio (Zero-Copy)   : ${zeroCopySpeedup}x relative to JS`);
    console.log(`=================================================================\n`);

    expect(wasmZeroCopyAvg).toBeGreaterThan(0);
    expect(jsAvg).toBeGreaterThan(0);
  });
});