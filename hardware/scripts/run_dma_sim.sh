#!/usr/bin/env bash
set -e

echo "================================================="
echo "  SIDDHAM NPU AXI-STREAM DMA SIMULATION (macOS)  "
echo "================================================="

# Compile RTL & Testbench using SystemVerilog 2012 mode
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
cd "$repo_root/hardware"
iverilog -g2012 -o dma_sim.vvp rtl/siddham_axis_dma.v tb/tb_siddham_axis_dma.v

# Run Simulation Binary
vvp dma_sim.vvp

echo "================================================="
