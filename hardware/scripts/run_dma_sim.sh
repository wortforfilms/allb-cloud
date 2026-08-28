#!/usr/bin/env zsh
set -e

echo "================================================="
echo "  SIDDHAM NPU AXI-STREAM DMA SIMULATION (macOS)  "
echo "================================================="

# Compile RTL & Testbench using SystemVerilog 2012 mode
repo_root=${0:A:h:h:h}
cd "$repo_root/hardware"
iverilog -g2012 -o dma_sim.vvp rtl/siddham_axis_dma.v tb/tb_siddham_axis_dma.v

# Run Simulation Binary
vvp dma_sim.vvp

echo "================================================="
