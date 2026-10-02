#!/usr/bin/env bash
# Paninian datapath regression: Shiva Sutra ROM, sandhi engine, two-phase datapath,
# checked against the Python reference and Vidyut's golden vowel-sandhi results.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
if command -v python3 >/dev/null 2>&1; then python3 "$script_dir/panini_ref.py"; fi
cd "$repo_root/hardware/tb"
iverilog -g2012 -Wall -I ../rtl -I . -s tb_panini_datapath -o /tmp/panini_datapath_sim.vvp \
    ../rtl/sivasutra_rom.v ../rtl/sandhi_engine.v ../rtl/panini_datapath.v tb_panini_datapath.v
vvp -n /tmp/panini_datapath_sim.vvp
