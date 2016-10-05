 
################################################################################
##
## (c) Copyright 2010-2014 Xilinx, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of Xilinx, Inc. and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## Xilinx, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) Xilinx shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or Xilinx had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## Xilinx products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of Xilinx products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##
##
################################################################################
## XDC generated for xc7z045-ffg900-2 device
# 275.0MHz GT Reference clock constraint
create_clock -name GT_REFCLK1 -period 3.636	 [get_pins -hierarchical -filter { NAME =~ "*/fmc1_gtx_clk_i/O" }]
####################### GT reference clock LOC #######################
set_property LOC AA7 [get_ports aurora_clk_fmc1_gtx_clk_n_v]
set_property LOC AA8 [get_ports aurora_clk_fmc1_gtx_clk_p_v]

# 110MHz user_clk -> 4.4Gbps*8/10*4 = 14.08Gbps = 128bit * 110M
create_clock -name auroraI_user_clk_i -period 9.091	 [get_pins -hierarchical -regexp {.*/aurora_module_i/clock_module_i/user_clk_buf_i/O}]

# 20.0 ns period Board Clock Constraint (drp,init)
# create_clock -name auroraI_init_clk_i -period 20.0 [get_pins -hierarchical -regexp {.*/auroraIntraClockDiv4_slowbuf/O}]
# create_clock -name auroraI_drp_clk_i -period 20.0 [get_pins -hierarchical -regexp {.*/auroraIntraClockDiv4_slowbuf/O}] -add
create_clock -name auroraI_init_clk_i -period 20.0 [get_pins -hierarchical -filter { NAME =~ "*auroraIntraClockDiv4/Q*"}]

###### CDC in RESET_LOGIC from INIT_CLK to USER_CLK ##############
set_max_delay -from [get_clocks auroraI_init_clk_i] -to [get_clocks auroraI_user_clk_i] -datapath_only 9.091	 

#CDC from auroraI_user_clk_i to/from  (200mhz system clk)
#Warning: The following constraints must be sourced AFTER zc707.xdc!
set_max_delay -from [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -to [get_clocks auroraI_user_clk_i] -datapath_only [get_property CLKIN1_PERIOD [get_cells ps7_clockGen_pll]]
set_max_delay -from [get_clocks auroraI_user_clk_i] -to [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -datapath_only [get_property CLKIN1_PERIOD [get_cells ps7_clockGen_pll]]


############################### GT LOC ###################################
set_property LOC GTXE2_CHANNEL_X0Y4 [get_cells -hierarchical -regexp {.*/aurora_8b10b_zynq_i/inst/gt_wrapper_i/aurora_8b10b_zynq_multi_gt_i/gt0_aurora_8b10b_zynq_i/gtxe2_i}]
set_property LOC GTXE2_CHANNEL_X0Y5 [get_cells -hierarchical -regexp {.*/aurora_8b10b_zynq_i/inst/gt_wrapper_i/aurora_8b10b_zynq_multi_gt_i/gt1_aurora_8b10b_zynq_i/gtxe2_i}]
set_property LOC GTXE2_CHANNEL_X0Y6 [get_cells -hierarchical -regexp {.*/aurora_8b10b_zynq_i/inst/gt_wrapper_i/aurora_8b10b_zynq_multi_gt_i/gt2_aurora_8b10b_zynq_i/gtxe2_i}]
set_property LOC GTXE2_CHANNEL_X0Y7 [get_cells -hierarchical -regexp {.*/aurora_8b10b_zynq_i/inst/gt_wrapper_i/aurora_8b10b_zynq_multi_gt_i/gt3_aurora_8b10b_zynq_i/gtxe2_i}]
  
  # X0Y4
 set_property LOC AH2 [get_ports { aurora_fmc1_TXP[3] }]
 set_property LOC AH1 [get_ports { aurora_fmc1_TXN[3] }]
 set_property LOC AH6 [get_ports { aurora_fmc1_rxp_i[3] }]
 set_property LOC AH5 [get_ports { aurora_fmc1_rxn_i[3] }]
  # X0Y5
 set_property LOC AF2 [get_ports { aurora_fmc1_TXP[2] }]
 set_property LOC AF1 [get_ports { aurora_fmc1_TXN[2] }]
 set_property LOC AG4 [get_ports { aurora_fmc1_rxp_i[2] }]
 set_property LOC AG3 [get_ports { aurora_fmc1_rxn_i[2] }]
  # X0Y6
 set_property LOC AE4 [get_ports { aurora_fmc1_TXP[1] }]
 set_property LOC AE3 [get_ports { aurora_fmc1_TXN[1] }]
 set_property LOC AF6 [get_ports { aurora_fmc1_rxp_i[1] }]
 set_property LOC AF5 [get_ports { aurora_fmc1_rxn_i[1] }]
  # X0Y7
 set_property LOC AD2 [get_ports { aurora_fmc1_TXP[0] }]
 set_property LOC AD1 [get_ports { aurora_fmc1_TXN[0] }]
 set_property LOC AD6 [get_ports { aurora_fmc1_rxp_i[0] }]
 set_property LOC AD5 [get_ports { aurora_fmc1_rxn_i[0] }]
