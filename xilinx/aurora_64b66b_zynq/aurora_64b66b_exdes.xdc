##################################################################################
##
## Project:  Aurora 64B/66B
## Company:  Xilinx
##
##
##
## (c) Copyright 2008 - 2014 Xilinx, Inc. All rights reserved.
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
## applications related to the deployment of airbags, or y
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
###################################################################################################
##
##  aurora_64b66b_exdes
##
##  Description: This is the example design constraints file for a 1 lane Aurora
##               core.
##               This is example design xdc.
##               Note: User need to set proper IO standards for the LOC's mentioned below.
###################################################################################################

################################################################################
# Shared across cores
# Ref Clk: pin connect Quad 109, HPC_GBTCLK0, 625 MHz (T=1.6ns)
set_property LOC AD10 [get_ports aurora_quad109_gtx_clk_p_v]
set_property LOC AD9 [get_ports aurora_quad109_gtx_clk_n_v]
create_clock -name GTXQ0_left_109_i -period 1.600	 [get_pins *auroraExt109/auroraExt_gtx_clk/O]

# Board Init Clk
create_clock -name aurora_init_clk_i -period 20.0 [get_pins *auroraExtClockDiv4_slowbuf/O]

# Aurora clks (user/sync)
create_clock -name TS_user_clk_i_all -period 6.400	 [get_pins -hier -filter {NAME =~ *aurora_64b66b_block_i/clock_module_i/user_clk_net_i/O}]
create_clock -name TS_sync_clk_i_all -period 3.200	 [get_pins -hier -filter {NAME =~ *aurora_64b66b_block_i/clock_module_i/sync_clock_net_i/O}]

# False Paths
set_false_path -from [get_cells -hier -filter {NAME =~ *auroraExt109/rst50/*}]
set_false_path -to [get_pins -hier -filter {NAME =~ *auroraExt109/rst50/*/CLR}]

#CDC from "init clk" to aurora user/sync clk
set_false_path -from [get_clocks aurora_init_clk_i] -to [get_clocks TS_user_clk_i_all]
set_false_path -from [get_clocks TS_user_clk_i_all] -to [get_clocks aurora_init_clk_i]
set_false_path -from [get_clocks aurora_init_clk_i] -to [get_clocks TS_sync_clk_i_all]
set_false_path -from [get_clocks TS_sync_clk_i_all] -to [get_clocks aurora_init_clk_i]

#CDC from ps7 clk_fpga_0 clk to aurora user clk. Should be read after zc706.xdc
set_max_delay -from [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -to [get_clocks TS_user_clk_i_all] -datapath_only [get_property CLKIN1_PERIOD [get_cells ps7_clockGen_pll]]
set_max_delay -from [get_clocks TS_user_clk_i_all] -to [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -datapath_only [get_property CLKIN1_PERIOD [get_cells ps7_clockGen_pll]]


######################################## Quad 109
################ X0Y0
set_false_path -to [get_pins -hier *aurora_64b66b_X0Y0_cdc_to*/D]
set_property LOC GTXE2_CHANNEL_X0Y0 [get_cells -hierarchical -regexp {.*aurora_64b66b_block_i/aurora_64b66b_X0Y0_i/inst/aurora_64b66b_X0Y0_wrapper_i/aurora_64b66b_X0Y0_multi_gt_i/aurora_64b66b_X0Y0_gtx_inst/gtxe2_i}]

set_property LOC AK10 [get_ports { aurora_ext_0_TXP }]
set_property LOC AK9  [get_ports { aurora_ext_0_TXN }]
set_property LOC AH10 [get_ports { aurora_ext_0_rxp_i }]
set_property LOC AH9  [get_ports { aurora_ext_0_rxn_i }]

############### X0Y1
set_false_path -to [get_pins -hier *aurora_64b66b_X0Y1_cdc_to*/D]
set_property LOC GTXE2_CHANNEL_X0Y1 [get_cells -hierarchical -regexp {.*aurora_64b66b_block_i/aurora_64b66b_X0Y1_i/inst/aurora_64b66b_X0Y1_wrapper_i/aurora_64b66b_X0Y1_multi_gt_i/aurora_64b66b_X0Y1_gtx_inst/gtxe2_i}]

set_property LOC AK6  [get_ports { aurora_ext_1_TXP }]
set_property LOC AK5  [get_ports { aurora_ext_1_TXN }]
set_property LOC AJ8  [get_ports { aurora_ext_1_rxp_i }]
set_property LOC AJ7  [get_ports { aurora_ext_1_rxn_i }]

############### X0Y2
set_false_path -to [get_pins -hier *aurora_64b66b_X0Y2_cdc_to*/D]
set_property LOC GTXE2_CHANNEL_X0Y2 [get_cells -hierarchical -regexp {.*aurora_64b66b_block_i/aurora_64b66b_X0Y2_i/inst/aurora_64b66b_X0Y2_wrapper_i/aurora_64b66b_X0Y2_multi_gt_i/aurora_64b66b_X0Y2_gtx_inst/gtxe2_i}]

set_property LOC AJ4  [get_ports { aurora_ext_2_TXP }]
set_property LOC AJ3  [get_ports { aurora_ext_2_TXN }]
set_property LOC AG8  [get_ports { aurora_ext_2_rxp_i }]
set_property LOC AG7  [get_ports { aurora_ext_2_rxn_i }]

############### X0Y3
set_false_path -to [get_pins -hier *aurora_64b66b_X0Y3_cdc_to*/D]
set_property LOC GTXE2_CHANNEL_X0Y3 [get_cells -hierarchical -regexp {.*aurora_64b66b_block_i/aurora_64b66b_X0Y3_i/inst/aurora_64b66b_X0Y3_wrapper_i/aurora_64b66b_X0Y3_multi_gt_i/aurora_64b66b_X0Y3_gtx_inst/gtxe2_i}]

set_property LOC AK2  [get_ports { aurora_ext_3_TXP }]
set_property LOC AK1  [get_ports { aurora_ext_3_TXN }]
set_property LOC AE8  [get_ports { aurora_ext_3_rxp_i }]
set_property LOC AE7  [get_ports { aurora_ext_3_rxn_i }]
