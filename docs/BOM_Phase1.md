# Siddham Edge: Phase 1 Dev-Kit BOM & Architecture

## Target Development Hardware
- **FPGA Board:** Xilinx Kria KV260 Vision AI Starter Kit (AMD Zynq UltraScale+ MPSoC)
- **NPU Accelerator IP:** Custom Soft-NPU Core mapped to DPU (Deep Processing Unit) B4096 IP
- **Processor Subsystem:** Quad-core ARM Cortex-A53 @ 1.3GHz
- **System Memory:** 4GB DDR4 (64-bit wide)
- **On-Board Storage:** 16GB eMMC + MicroSD slot
- **Network Interfaces:** 1x GbE RJ45 (for Z0-VESP Local Ingress)
- **Sensor IO:** MIPI-CSI2 camera interface, GPIO, UART, I2C

## Resource Allocation & Utilization Target
- **LUTs (Look-Up Tables):** 117,120 / 256,000 (45.75%)
- **DSP Slices:** 768 / 1,248 (61.54%)
- **BRAM (Block RAM):** 14.4 Mb / 26.6 Mb (54.13%)
- **Target Power Consumption:** <= 12.5 W