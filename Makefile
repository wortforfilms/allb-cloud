.PHONY: all sim sim-top sim-panini rtl-check test build-wasm verify package deploy-staging clean

# 1. सम्पूर्ण सिस्टम बिल्ड और टेस्ट
all: build-wasm test

# 2. L0: Verilog HDL Simulation (Icarus Verilog + vvp)
sim:
	@echo "==> Compiling and executing the AXI-stream DMA regression..."
	iverilog -g2012 -o npu_dma_sim.out hardware/tb/tb_siddham_axis_dma.v hardware/rtl/siddham_axis_dma.v
	@echo "==> Running VVP Simulation..."
	vvp npu_dma_sim.out

sim-top:
	@echo "==> Executing the integrated DMA + NPU core regression..."
	hardware/scripts/run_top_sim.sh

sim-panini:
	@echo "==> Paninian datapath regression (Shiva Sutra ROM + sandhi engine vs reference and Vidyut)..."
	hardware/scripts/run_panini_sim.sh

rtl-check:
	@echo "==> Compile-checking the integrated NPU top-level..."
	iverilog -g2012 -s siddham_npu_top -o /tmp/siddham-npu-top-check.vvp hardware/rtl/siddham_npu_top.v hardware/rtl/npu_compute_core.v hardware/rtl/npu_dma_engine.v
	iverilog -g2012 -I hardware/rtl -s panini_datapath -o /tmp/panini-datapath-check.vvp hardware/rtl/sivasutra_rom.v hardware/rtl/sandhi_engine.v hardware/rtl/panini_datapath.v

# 3. L1/L2: Native Rust Kernel & Vitest E2E Suite
test: build-wasm
	@echo "==> Executing Rust Native Tests..."
	cargo test --release
	@echo "==> Executing Vitest E2E Integration Suite..."
	npx vitest run tests/z0_vesp_e2e.test.ts

# 4. L2: WASM Production Compilation
build-wasm:
	@echo "==> Compiling WebAssembly Module via build-edge.sh..."
	./scripts/build-edge.sh

# 5. L3: Isolated Cloudflare staging deployment
deploy-staging: build-wasm
	@echo "==> Deploying the isolated staging Worker..."
	npx wrangler deploy --env staging

verify:
	npm run verify

package: verify build-wasm
	npm run desktop:check
	npm run artifacts:package

clean:
	node scripts/clean.mjs
