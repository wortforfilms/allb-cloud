# ==============================================================================
# Script Name: build_siddham_npu_bd.tcl
# Description: Automates Vivado Project creation, Instantiates Zynq UltraScale+ 
#              MPSoC, integrates the RTL module `siddham_npu_mmio.v`, auto-maps
#              the AXI4-Lite SmartConnect bus, and maps MMIO to 0xA0000000.
# Target Part: xck26-sfvc784-2LV-c (Kria KV260 Vision AI Starter Kit)
# ==============================================================================

# 1. Project Configuration & Creation
set proj_name "maataa_siddham_hardware"
set proj_dir  "./vivado_workspace"
set part_num  "xck26-sfvc784-2LV-c"
set board_id  "xilinx.com:kv260_phyt:part0:1.1"

# Create project directory structure
create_project $proj_name $proj_dir -part $part_num -force
if {[catch {set_property board_part $board_id [current_project]} err]} {
    puts "INFO: Board part $board_id not found in local cache. Falling back to raw device part $part_num."
}

# 2. Add Synthesizable Verilog Source
add_files -norecurse "./siddham_npu_mmio.v"
update_compile_order -fileset sources_1

# 3. Create Block Design Canvas
set bd_name "siddham_npu_system"
create_bd_design $bd_name
current_bd_design $bd_name

# 4. Instantiate Zynq UltraScale+ MPSoC IP Core
set zynq_ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ultra_ps_e_0]

# Enable Master AXI HPM0 LPD Interface for PL access
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP2 {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100.000000} \
] $zynq_ps

# Run PS Block Automation
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} $zynq_ps

# 5. Add RTL Module to Block Design Canvas
set mmio_module [create_bd_cell -type module -reference siddham_npu_mmio npu_mmio_0]

# 6. Instantiate AXI SmartConnect Interconnect & Reset Controller
set axi_smc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0]
set proc_rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0]

# Set SmartConnect to single master / single slave configuration
set_property CONFIG.NUM_SI {1} $axi_smc
set_property CONFIG.NUM_MI {1} $axi_smc

# 7. Wire Clock & Reset Nets
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk] \
               [get_bd_pins smartconnect_0/aclk] \
               [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
               [get_bd_pins npu_mmio_0/axi_aclk]

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
               [get_bd_pins proc_sys_reset_0/ext_reset_in]

connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
               [get_bd_pins smartconnect_0/aresetn]

connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins npu_mmio_0/axi_aresetn]

# 8. Wire AXI4-Lite Control Bus
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD] \
                    [get_bd_intf_pins smartconnect_0/S00_AXI]

# Wire SmartConnect Master to custom Verilog ports
connect_bd_net [get_bd_pins smartconnect_0/M00_AXI_awaddr]  [get_bd_pins npu_mmio_0/s_axi_awaddr]
connect_bd_net [get_bd_pins smartconnect_0/M00_AXI_awvalid] [get_bd_pins npu_mmio_0/s_axi_awvalid]
connect_bd_net [get_bd_pins npu_mmio_0/s_axi_awready]        [get_bd_pins smartconnect_0/M00_AXI_awready]
connect_bd_net [get_bd_pins smartconnect_0/M00_AXI_wdata]   [get_bd_pins npu_mmio_0/s_axi_wdata]
connect_bd_net [get_bd_pins smartconnect_0/M00_AXI_wstrb]   [get_bd_pins npu_mmio_0/s_axi_wstrb]
connect_bd_net [get_bd_pins smartconnect_0/M00_AXI_wvalid]  [get_bd_pins npu_mmio_0/s_axi_wvalid]
connect_bd_net [get_bd_pins npu_mmio_0/s_axi_wready]         [get_bd_pins smartconnect_0/M00_AXI_wready]
connect_bd_net [get_bd_pins npu_mmio_0/s_axi_bresp]          [get_bd_pins smartconnect_0/M00_AXI_bresp]
connect_bd_net [get_bd_pins npu_mmio_0/s_axi_bvalid]         [get_bd_pins smartconnect_0/M00_AXI_bvalid]
connect_bd_net [get_bd_pins smartconnect_0/M00_AXI_bready]  [get_bd_pins npu_mmio_0/s_axi_bready]

connect_bd_net [get_bd_pins smartconnect_0/M00_AXI_araddr]  [get_bd_pins npu_mmio_0/s_axi_araddr]
connect_bd_net [get_bd_pins smartconnect_0/M00_AXI_arvalid] [get_bd_pins npu_mmio_0/s_axi_arvalid]
connect_bd_net [get_bd_pins npu_mmio_0/s_axi_arready]        [get_bd_pins smartconnect_0/M00_AXI_arready]
connect_bd_net [get_bd_pins npu_mmio_0/s_axi_rdata]          [get_bd_pins smartconnect_0/M00_AXI_rdata]
connect_bd_net [get_bd_pins npu_mmio_0/s_axi_rresp]          [get_bd_pins smartconnect_0/M00_AXI_rresp]
connect_bd_net [get_bd_pins npu_mmio_0/s_axi_rvalid]         [get_bd_pins smartconnect_0/M00_AXI_rvalid]
connect_bd_net [get_bd_pins smartconnect_0/M00_AXI_rready]  [get_bd_pins npu_mmio_0/s_axi_rready]

# 9. Assign MMIO Base Address (0xA0000000)
assign_bd_address
set_property offset 0xA0000000 [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_npu_mmio_0_Reg}]
set_property range  64K        [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_npu_mmio_0_Reg}]

# 10. Regenerate Layout & Validate Block Design
regenerate_bd_layout
validate_bd_design
save_bd_design

# 11. Create Top-Level HDL Wrapper
make_wrapper -files [get_files ${proj_dir}/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -top
add_files -norecurse ${proj_dir}/${proj_name}.srcs/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v
update_compile_order -fileset sources_1

puts "=========================================================================="
puts " SUCCESS: Siddham NPU Block Design built and mapped to 0xA0000000!"
puts "=========================================================================="