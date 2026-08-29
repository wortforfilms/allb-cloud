import { rmSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const disposablePaths = [
  "target",
  "pkg",
  "artifacts",
  ".wrangler",
  "coverage",
  ".vitest",
  "node_modules",
  "apps/siddham-authority-desktop/node_modules",
  "apps/siddham-authority-desktop/dist",
  "contracts/__pycache__",
  "generated/python/__pycache__",
  "hardware/top_sim.vvp",
  "hardware/top_waves.vcd",
  "dma_waves.vcd",
  "npu_dma_sim.out",
];

for (const path of disposablePaths) {
  rmSync(resolve(root, path), { recursive: true, force: true });
}
console.log(`Cleaned ${disposablePaths.length} reproducible output paths`);
