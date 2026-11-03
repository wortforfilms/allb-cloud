#!/usr/bin/env bash
# Paninian datapath regression: Shiva Sutra ROM, vowel sandhi engine, two-phase datapath, and the
# consonant/visarga sandhi pipeline, checked against the Python references and Vidyut.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
if command -v python3 >/dev/null 2>&1; then python3 "$script_dir/panini_ref.py"; python3 "$script_dir/hal_ref.py"; python3 "$script_dir/prakriya_ref.py"; fi
cd "$repo_root/hardware/tb"
iverilog -g2012 -Wall -I ../rtl -I . -s tb_panini_datapath -o /tmp/panini_datapath_sim.vvp \
    ../rtl/sivasutra_rom.v ../rtl/sandhi_engine.v ../rtl/panini_datapath.v tb_panini_datapath.v
vvp -n /tmp/panini_datapath_sim.vvp
iverilog -g2012 -Wall -I ../rtl -I . -s tb_hal_sandhi -o /tmp/hal_sandhi_sim.vvp \
    ../rtl/hal_sandhi_stages.v ../rtl/hal_sandhi_pipeline.v tb_hal_sandhi.v
vvp -n /tmp/hal_sandhi_sim.vvp
iverilog -g2012 -Wall -I ../rtl -I . -s tb_prakriya_core -o /tmp/prakriya_core_sim.vvp \
    ../rtl/prakriya_core.v tb_prakriya_core.v
vvp -n /tmp/prakriya_core_sim.vvp
iverilog -g2012 -Wall -I ../rtl -I . -s tb_fpga_top -o /tmp/fpga_top_sim.vvp \
    ../rtl/prakriya_core.v ../rtl/spi_slave.v ../rtl/fpga_top.v tb_fpga_top.v
vvp -n /tmp/fpga_top_sim.vvp
