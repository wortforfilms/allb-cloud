import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

export default defineConfig({
  resolve: {
    alias: {
      "../../../pkg/maataa_runtime_bg.wasm": fileURLToPath(
        new URL("./tests/fixtures/wasm-module-stub.ts", import.meta.url),
      ),
    },
  },
  test: {
    environment: "node",
    globals: true,
  },
});
