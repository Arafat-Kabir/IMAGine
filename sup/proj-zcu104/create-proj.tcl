# Create a ZCU-104 project and add the IMAGine IP
create_project proj-zcu104 . -part xczu7ev-ffvc1156-2-e
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]
set_property ip_repo_paths ../imagine-ip [current_project]
update_ip_catalog

# Create the block design
create_bd_design "imagine_dsn01"
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]
create_bd_cell -type ip -vlnv user.org:user:imagine_gemv:1.0 imagine_gemv_0
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/zynq_ultra_ps_e_0/pl_clk0 (100 MHz)} Freq {100} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}}  [get_bd_pins imagine_gemv_0/imagine_clk]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} Slave {/imagine_gemv_0/S00_AXI} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins imagine_gemv_0/S00_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {/zynq_ultra_ps_e_0/pl_clk0 (100 MHz)} Clk_xbar {/zynq_ultra_ps_e_0/pl_clk0 (100 MHz)} Master {/zynq_ultra_ps_e_0/M_AXI_HPM1_FPD} Slave {/imagine_gemv_0/S00_AXI} ddr_seg {Auto} intc_ip {/ps8_0_axi_periph} master_apm {0}}  [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM1_FPD]
make_wrapper -files [get_files ./proj-zcu104.srcs/sources_1/bd/imagine_dsn01/imagine_dsn01.bd] -top
add_files -norecurse ./proj-zcu104.gen/sources_1/bd/imagine_dsn01/hdl/imagine_dsn01_wrapper.v
update_compile_order -fileset sources_1

# Configure the Block Design for 64x64 PE array
set_property CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {300} [get_bd_cells zynq_ultra_ps_e_0]
set_property CONFIG.GEMVARR_BLK_ROW_CNT {64} [get_bd_cells imagine_gemv_0]
regenerate_bd_layout
validate_bd_design
save_bd_design
