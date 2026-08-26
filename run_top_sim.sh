#!/usr/bin/env zsh
set -e

echo "================================================="
echo "  SIDDHAM NPU TOP-LEVEL SYSTEM SIMULATION        "
echo "================================================="

# Compile all Verilog modules using SystemVerilog 2012 mode
iverilog -g2012 -o top_sim.vvp \
    npu_mmio_regbank.v \
    npu_dma_engine.v \
    npu_compute_core.v \
    siddham_npu_top.v \
    tb_siddham_npu_top.v

# Run simulation binary
vvp top_sim.vvp

echo "================================================="