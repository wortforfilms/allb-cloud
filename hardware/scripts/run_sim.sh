#!/usr/bin/env bash
set -e

echo "================================================="
echo "  MAATAA HARDWARE RTL SIMULATION (macOS)         "
echo "================================================="

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
cd "$repo_root/hardware"
iverilog -g2012 -o npu_mmio_sim.vvp rtl/siddham_npu_mmio.v tb/tb_siddham_npu_mmio.v
vvp npu_mmio_sim.vvp

if command -v gtkwave &> /dev/null; then
    echo "[+] Launching GTKWave with pre-configured layout..."
    gtkwave npu_mmio_waves.vcd npu_mmio.gtkw &
else
    echo "[!] GTKWave not found. VCD trace exported."
fi

echo "================================================="
