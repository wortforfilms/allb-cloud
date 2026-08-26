import { PaniniSutraEngine, VespPayload } from './panini_sutras';

async function runPhase1Benchmark() {
  console.log("=================================================");
  console.log("STARTING PHASE 1 BENCHMARK SUITE (Siddham/Z0)");
  console.log("=================================================\n");

  const ITERATIONS = 1000;
  const VECTOR_DIM = 128;
  
  // Generate mock consensus vector
  const consensusVector = Array.from({ length: VECTOR_DIM }, () => Math.random());
  
  // Mock valid payload
  const validPayload: VespPayload = {
    embedding: [...consensusVector], // 1.0 similarity
    confidence: 0.95,
    timestamp: Math.floor(Date.now() / 1000),
    signerPublicKey: "ed25519_pk_8f9a2b1c...",
    nonce: "nonce_abc123"
  };

  let totalDurationMs = 0;
  let passedCount = 0;

  const startTime = performance.now();

  for (let i = 0; i < ITERATIONS; i++) {
    const iterStart = performance.now();
    const result = await PaniniSutraEngine.validatePayload(validPayload, consensusVector, 1.5);
    const iterEnd = performance.now();

    totalDurationMs += (iterEnd - iterStart);
    if (result.overallPassed) passedCount++;
  }

  const totalTimeMs = performance.now() - startTime;
  const avgLatencyMs = totalDurationMs / ITERATIONS;
  const opsPerSec = Math.floor((ITERATIONS / totalTimeMs) * 1000);

  console.log(`Total Iterations:       ${ITERATIONS}`);
  console.log(`Successful Executions:  ${passedCount} / ${ITERATIONS}`);
  console.log(`Average Latency:        ${avgLatencyMs.toFixed(3)} ms per vector`);
  console.log(`Throughput:             ${opsPerSec} ops/sec`);
  console.log(`Target Latency Threshold: <= 45.000 ms`);
  console.log(`Benchmark Status:       ${avgLatencyMs <= 45 ? "PASSED (Within Bounds)" : "FAILED (High Latency)"}`);
  console.log("=================================================\n");
}

runPhase1Benchmark();