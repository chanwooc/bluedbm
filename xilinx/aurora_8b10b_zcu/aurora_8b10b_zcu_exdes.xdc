 
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
## XDC generated for xczu9eg-ffvb1156-2 device
# 275.0MHz GT Reference clock constraint
create_clock -name GT_REFCLK1 -period 3.636	 [get_ports aurora_clk_fmc1_gtx_clk_p_v]
####################### GT reference clock LOC #######################
set_property LOC L8 [get_ports aurora_clk_fmc1_gtx_clk_p_v]
set_property LOC L7 [get_ports aurora_clk_fmc1_gtx_clk_n_v]

# 20.0 ns period Board Clock Constraint -> changed to 110 MHz Derived Board Clock
#create_clock -name auroraI_init_clk_i -period 20.0 [get_nets -hierarchical -filter { NAME =~ "*auroraIntraClockDiv4_CLK_slowClock" }]

# I guess below should be inferred automatically 
# 110MHz user_clk -> 4.4Gbps*8/10*4 = 14.08Gbps = 128bit * 110M
#create_clock -name auroraI_user_clk_i -period 9.091  [get_pins -hierarchical -regexp {.*/aurora_module_i/clock_module_i/user_clk_buf_i/O}]


###### CDC in RESET_LOGIC from INIT_CLK to USER_CLK ##############
set_false_path -to [get_pins -hier *aurora_8b10b_zcu_cdc_to*/D]
# False path constraints for Ultrascale Clocking Module (BUFG_GT)
# ----------------------------------------------------------------------------------------------------------------------
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *clock_module_i/*PLL_NOT_LOCKED*}]
set_false_path -through [get_pins -hierarchical -filter {NAME =~ *clock_module_i/*user_clk_buf_i/CLR}]

##################### Locatoin constrain #########################
##Note: User should add LOC based upon the board
#       Below LOC's are place holders and need to be changed as per the device and board
#set_property LOC D17 [get_ports INIT_CLK_P]
#set_property LOC D18 [get_ports INIT_CLK_N]
#set_property LOC G19 [get_ports RESET]
#set_property LOC K18 [get_ports GT_RESET_IN]
#set_property LOC A20 [get_ports CHANNEL_UP]
#set_property LOC A17 [get_ports LANE_UP[0]]
#set_property LOC A16 [get_ports LANE_UP[1]]
#set_property LOC B20 [get_ports LANE_UP[2]]
#set_property LOC C20  [get_ports LANE_UP[3]]
#set_property LOC Y15 [get_ports HARD_ERR]   
#set_property LOC AH10 [get_ports SOFT_ERR]   
#set_property LOC AD16 [get_ports ERR_COUNT[0]]   
#set_property LOC Y19 [get_ports ERR_COUNT[1]]   
#set_property LOC Y18 [get_ports ERR_COUNT[2]]   
#set_property LOC AA18 [get_ports ERR_COUNT[3]]   
#set_property LOC AB18 [get_ports ERR_COUNT[4]]   
#set_property LOC AB19 [get_ports ERR_COUNT[5]]   
#set_property LOC AC19 [get_ports ERR_COUNT[6]]   
#set_property LOC AB17 [get_ports ERR_COUNT[7]]   
    
    

##Note: User should add IOSTANDARD based upon the board
#       Below IOSTANDARD's are place holders and need to be changed as per the device and board
#set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports INIT_CLK_P]
#set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports INIT_CLK_N]
#set_property IOSTANDARD LVCMOS18 [get_ports RESET]
#set_property IOSTANDARD LVCMOS18 [get_ports GT_RESET_IN]

#set_property IOSTANDARD LVCMOS18 [get_ports CHANNEL_UP]
#set_property IOSTANDARD LVCMOS18 [get_ports LANE_UP[0]]
#set_property IOSTANDARD LVCMOS18 [get_ports LANE_UP[1]]
#set_property IOSTANDARD LVCMOS18 [get_ports LANE_UP[2]]
#set_property IOSTANDARD LVCMOS18  [get_ports LANE_UP[3]]
#set_property IOSTANDARD LVCMOS18 [get_ports HARD_ERR]   
#set_property IOSTANDARD LVCMOS18 [get_ports SOFT_ERR]   
#set_property IOSTANDARD LVCMOS18 [get_ports ERR_COUNT[0]]   
#set_property IOSTANDARD LVCMOS18 [get_ports ERR_COUNT[1]]   
#set_property IOSTANDARD LVCMOS18 [get_ports ERR_COUNT[2]]   
#set_property IOSTANDARD LVCMOS18 [get_ports ERR_COUNT[3]]   
#set_property IOSTANDARD LVCMOS18 [get_ports ERR_COUNT[4]]   
#set_property IOSTANDARD LVCMOS18 [get_ports ERR_COUNT[5]]   
#set_property IOSTANDARD LVCMOS18 [get_ports ERR_COUNT[6]]   
#set_property IOSTANDARD LVCMOS18 [get_ports ERR_COUNT[7]]   
    
    
    
##################################################################

# GT LOC override
# UltraScale FPGAs Transceivers Wizard IP core-level XDC file
# ----------------------------------------------------------------------------------------------------------------------

# Commands for enabled transceiver GTHE4_CHANNEL_X1Y4
# ----------------------------------------------------------------------------------------------------------------------

# Before replacing, place them to the other positions
set_property LOC GTHE4_CHANNEL_X1Y8 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[25].*gen_gthe4_channel_inst[0].GTHE4_CHANNEL_PRIM_INST}]
set_property LOC GTHE4_CHANNEL_X1Y9 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[25].*gen_gthe4_channel_inst[1].GTHE4_CHANNEL_PRIM_INST}]
set_property LOC GTHE4_CHANNEL_X1Y10 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[25].*gen_gthe4_channel_inst[2].GTHE4_CHANNEL_PRIM_INST}]
set_property LOC GTHE4_CHANNEL_X1Y11 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[25].*gen_gthe4_channel_inst[3].GTHE4_CHANNEL_PRIM_INST}]
#

## Channel primitive location constraint
# Prev   : GT0 = X1Y4 (MGT0, DP6)   (X)
# Correct: GT0 = X1Y7 (MGT3, DP4)
set_property LOC GTHE4_CHANNEL_X1Y7 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[25].*gen_gthe4_channel_inst[0].GTHE4_CHANNEL_PRIM_INST}]
#
## Channel primitive serial data pin location constraints
## (Provided as comments for your reference. The channel primitive location constraint is sufficient.)
##set_property package_pin T1 [get_ports gthrxn_in[0]]
##set_property package_pin T2 [get_ports gthrxp_in[0]]
##set_property package_pin R3 [get_ports gthtxn_out[0]]
##set_property package_pin R4 [get_ports gthtxp_out[0]]
#
## Commands for enabled transceiver GTHE4_CHANNEL_X1Y5
## ----------------------------------------------------------------------------------------------------------------------
#
## Channel primitive location constraint
# Prev   : GT1 = X1Y5 (MGT1, DP5)
set_property LOC GTHE4_CHANNEL_X1Y5 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[25].*gen_gthe4_channel_inst[1].GTHE4_CHANNEL_PRIM_INST}]
#
## Channel primitive serial data pin location constraints
## (Provided as comments for your reference. The channel primitive location constraint is sufficient.)
##set_property package_pin P1 [get_ports gthrxn_in[1]]
##set_property package_pin P2 [get_ports gthrxp_in[1]]
##set_property package_pin P5 [get_ports gthtxn_out[1]]
##set_property package_pin P6 [get_ports gthtxp_out[1]]
#
## Commands for enabled transceiver GTHE4_CHANNEL_X1Y6
## ----------------------------------------------------------------------------------------------------------------------
#
## Channel primitive location constraint
# Prev   : GT2 = X1Y6 (MGT2, DP7)   (X)
# Correct: GT2 = X1Y4 (MGT0, DP6)
set_property LOC GTHE4_CHANNEL_X1Y4 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[25].*gen_gthe4_channel_inst[2].GTHE4_CHANNEL_PRIM_INST}]
#
## Channel primitive serial data pin location constraints
## (Provided as comments for your reference. The channel primitive location constraint is sufficient.)
##set_property package_pin M1 [get_ports gthrxn_in[2]]
##set_property package_pin M2 [get_ports gthrxp_in[2]]
##set_property package_pin N3 [get_ports gthtxn_out[2]]
##set_property package_pin N4 [get_ports gthtxp_out[2]]
#
## Commands for enabled transceiver GTHE4_CHANNEL_X1Y7
## ----------------------------------------------------------------------------------------------------------------------
#
## Channel primitive location constraint
# Prev   : GT3 = X1Y7 (MGT3, DP4)   (X)
# Correct: GT3 = X1Y6 (MGT2, DP7)
set_property LOC GTHE4_CHANNEL_X1Y6 [get_cells -hierarchical -filter {NAME =~ *gen_channel_container[25].*gen_gthe4_channel_inst[3].GTHE4_CHANNEL_PRIM_INST}]
#
## Channel primitive serial data pin location constraints
## (Provided as comments for your reference. The channel primitive location constraint is sufficient.)
##set_property package_pin L3 [get_ports gthrxn_in[3]]
##set_property package_pin L4 [get_ports gthrxp_in[3]]
##set_property package_pin M5 [get_ports gthtxn_out[3]]
##set_property package_pin M6 [get_ports gthtxp_out[3]]
