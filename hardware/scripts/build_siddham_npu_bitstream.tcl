# ==============================================================================
# Script Name: build_siddham_npu_bitstream.tcl
# Description: Automates Vivado IP creation, Block Design Integration, Synthesis,
#              Implementation, Timing Closure, and Bitstream/XSA Export.
# Target Part: xck26-sfvc784-2LV-c (AMD-Xilinx Kria KV260 Starter Kit)
# ==============================================================================

# 1. Setup Parameters & Output Directories
set proj_name  "maataa_siddham_bitstream"
set proj_dir   "./vivado_bitstream_build"
set part_num   "xck26-sfvc784-2LV-c"
set board_id   "xilinx.com:kv260_phyt:part0:1.1"
set output_dir "./build_output"

file mkdir $output_dir

# 2. Create Vivado Project
create_project $proj_name $proj_dir -part $part_num -force
if {[catch {set_property board_part $board_id [current_project]} err]} {
    puts "INFO: Board part $board_id not found in cache. Falling back to device part $part_num."
}

# 3. Add Synthesizable Verilog Source Files
add_files -norecurse [glob ./npu_mmio_regbank.v]
add_files -norecurse [glob ./npu_dma_engine.v]
add_files -norecurse [glob ./npu_compute_core.v]
add_files -norecurse [glob ./siddham_npu_top.v]
update_compile_order -fileset sources_1

# Set Top Level Module
set_property top siddham_npu_top [current_fileset]

# 4. Create Block Design Canvas
set bd_name "siddham_npu_bd"
create_bd_design $bd_name
current_bd_design $bd_name

# 5. Instantiate Zynq UltraScale+ MPSoC IP Core
set zynq_ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ultra_ps_e_0]

# Configure PS Interfaces (AXI HPM0 LPD for MMIO, HP0 for Stream DMA)
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP2 {1} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100.000000} \
] $zynq_ps

apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} $zynq_ps

# 6. Instantiate Top-Level Module into Block Design
set npu_core [create_bd_cell -type module -reference siddham_npu_top npu_top_0]

# 7. Add SmartConnect Interconnect & Reset Controller
set smc_mmio [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_mmio]
set proc_rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0]

# 8. Connect Clocks, Resets, and Interfaces
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk] \
               [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk] \
               [get_bd_pins smartconnect_mmio/aclk] \
               [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
               [get_bd_pins npu_top_0/clk]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
               [get_bd_pins proc_sys_reset_0/ext_reset_in]

connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins smartconnect_mmio/aresetn] \
               [get_bd_pins npu_top_0/rst_n]

# Wire AXI-Lite Interface to Top Level MMIO
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD] [get_bd_intf_pins smartconnect_mmio/S00_AXI]

connect_bd_net [get_bd_pins smartconnect_mmio/M00_AXI_awaddr]  [get_bd_pins npu_top_0/s_axi_awaddr]
connect_bd_net [get_bd_pins smartconnect_mmio/M00_AXI_awvalid] [get_bd_pins npu_top_0/s_axi_awvalid]
connect_bd_net [get_bd_pins npu_top_0/s_axi_awready]            [get_bd_pins smartconnect_mmio/M00_AXI_awready]
connect_bd_net [get_bd_pins smartconnect_mmio/M00_AXI_wdata]   [get_bd_pins npu_top_0/s_axi_wdata]
connect_bd_net [get_bd_pins smartconnect_mmio/M00_AXI_wstrb]   [get_bd_pins npu_top_0/s_axi_wstrb]
connect_bd_net [get_bd_pins smartconnect_mmio/M00_AXI_wvalid]  [get_bd_pins npu_top_0/s_axi_wvalid]
connect_bd_net [get_bd_pins npu_top_0/s_axi_wready]             [get_bd_pins smartconnect_mmio/M00_AXI_wready]
connect_bd_net [get_bd_pins npu_top_0/s_axi_bresp]              [get_bd_pins smartconnect_mmio/M00_AXI_bresp]
connect_bd_net [get_bd_pins npu_top_0/s_axi_bvalid]             [get_bd_pins smartconnect_mmio/M00_AXI_bvalid]
connect_bd_net [get_bd_pins smartconnect_mmio/M00_AXI_bready]  [get_bd_pins npu_top_0/s_axi_bready]

connect_bd_net [get_bd_pins smartconnect_mmio/M00_AXI_araddr]  [get_bd_pins npu_top_0/s_axi_araddr]
connect_bd_net [get_bd_pins smartconnect_mmio/M00_AXI_arvalid] [get_bd_pins npu_top_0/s_axi_arvalid]
connect_bd_net [get_bd_pins npu_top_0/s_axi_arready]            [get_bd_pins smartconnect_mmio/M00_AXI_arready]
connect_bd_net [get_bd_pins npu_top_0/s_axi_rdata]              [get_bd_pins smartconnect_mmio/M00_AXI_rdata]
connect_bd_net [get_bd_pins npu_top_0/s_axi_rresp]              [get_bd_pins smartconnect_mmio/M00_AXI_rresp]
connect_bd_net [get_bd_pins npu_top_0/s_axi_rvalid]             [get_bd_pins smartconnect_mmio/M00_AXI_rvalid]
connect_bd_net [get_bd_pins smartconnect_mmio/M00_AXI_rready]  [get_bd_pins smartconnect_mmio/M00_AXI_rready]

# Connect Interrupt Line to PS GIC
connect_bd_net [get_bd_pins npu_top_0/interrupt] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

# 9. Map Memory Addresses (Base MMIO = 0xA0000000)
assign_bd_address
set_property offset 0xA0000000 [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_npu_top_0_Reg}]
set_property range  64K        [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_npu_top_0_Reg}]

regenerate_bd_layout
validate_bd_design
save_bd_design

# 10. Generate Wrapper & BD Output Products
make_wrapper -files [get_files ${proj_dir}/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -top
add_files -norecurse ${proj_dir}/${proj_name}.srcs/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v
update_compile_order -fileset sources_1

generate_target all [get_files ${proj_dir}/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd]

# 11. Run RTL Synthesis
puts "=========================================================================="
puts " [1/4] STARTING RTL SYNTHESIS..."
puts "=========================================================================="
launch_runs synth_1 -jobs 8
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed! Check synth_1 log."
    exit 1
}

# 12. Run Implementation (Place & Route)
puts "=========================================================================="
puts " [2/4] STARTING IMPLEMENTATION (PLACE & ROUTE)..."
puts "=========================================================================="
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed! Check impl_1 log."
    exit 1
}

# 13. Export Artifacts (.bit, .bin, and .xsa for HAL Driver)
puts "=========================================================================="
puts " [3/4] EXPORTING BITSTREAM AND XSA HARDWARE HANDOFF..."
puts "=========================================================================="
file copy -force ${proj_dir}/${proj_name}.runs/impl_1/${bd_name}_wrapper.bit ${output_dir}/siddham_npu.bit

write_hw_platform -fixed -include_bit -force -file ${output_dir}/siddham_npu.xsa

# 14. Report Timing Summary
open_run impl_1
report_timing_summary -file ${output_dir}/timing_summary.rpt

puts "=========================================================================="
puts " [4/4] SUCCESS: FPGA Bitstream Generated!"
puts "       • Bitstream: ${output_dir}/siddham_npu.bit"
puts "       • Hardware Export: ${output_dir}/siddham_npu.xsa"
puts "       • Timing Report: ${output_dir}/timing_summary.rpt"
puts "=========================================================================="