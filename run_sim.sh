#!/usr/bin/env zsh
set -e

echo "================================================="
echo "  MAATAA HARDWARE RTL SIMULATION (macOS)         "
echo "================================================="

iverilog -g2012 -o npu_mmio_sim.vvp siddham_npu_mmio.v tb_siddham_npu_mmio.v
vvp npu_mmio_sim.vvp

if command -v gtkwave &> /dev/null; then
    echo "[+] Launching GTKWave with pre-configured layout..."
    gtkwave npu_mmio_waves.vcd npu_mmio.gtkw &
else
    echo "[!] GTKWave not found. VCD trace exported."
fi

echo "================================================="