.PHONY: all sim sim-top rtl-check test build-wasm deploy-staging clean

# 1. सम्पूर्ण सिस्टम बिल्ड और टेस्ट
all: sim sim-top rtl-check test build-wasm

# 2. L0: Verilog HDL Simulation (Icarus Verilog + vvp)
sim:
	@echo "==> Compiling and executing the AXI-stream DMA regression..."
	iverilog -g2012 -o npu_dma_sim.out hardware/tb/tb_siddham_axis_dma.v hardware/rtl/siddham_axis_dma.v
	@echo "==> Running VVP Simulation..."
	vvp npu_dma_sim.out

sim-top:
	@echo "==> Executing the integrated DMA + NPU core regression..."
	hardware/scripts/run_top_sim.sh

rtl-check:
	@echo "==> Compile-checking the integrated NPU top-level..."
	iverilog -g2012 -s siddham_npu_top -o /tmp/siddham-npu-top-check.vvp hardware/rtl/siddham_npu_top.v hardware/rtl/npu_compute_core.v hardware/rtl/npu_dma_engine.v

# 3. L1/L2: Native Rust Kernel & Vitest E2E Suite
test:
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

clean:
	rm -f npu_top_sim.out npu_dma_sim.out *.vcd
	rm -rf pkg target
