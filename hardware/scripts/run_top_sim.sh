#!/usr/bin/env zsh
set -e

echo "================================================="
echo "  SIDDHAM NPU TOP-LEVEL SYSTEM SIMULATION        "
echo "================================================="

# Compile all Verilog modules using SystemVerilog 2012 mode
repo_root=${0:A:h:h:h}
cd "$repo_root/hardware"
iverilog -g2012 -s tb_siddham_npu_top -o top_sim.vvp \
    rtl/npu_dma_engine.v \
    rtl/npu_compute_core.v \
    tb/tb_siddham_npu_top.v

# Run simulation binary
vvp top_sim.vvp

echo "================================================="
