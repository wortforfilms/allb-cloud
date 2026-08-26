#!/usr/bin/env zsh
set -e

echo "================================================="
echo "  SIDDHAM NPU AXI-STREAM DMA SIMULATION (macOS)  "
echo "================================================="

# Compile RTL & Testbench using SystemVerilog 2012 mode
iverilog -g2012 -o dma_sim.vvp siddham_axis_dma.v tb_siddham_axis_dma.v

# Run Simulation Binary
vvp dma_sim.vvp

echo "================================================="