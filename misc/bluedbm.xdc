#Bscan ref clk to 125mhz clk
set_false_path -from [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -to [get_clocks bscan_refclk]
set_false_path -from [get_clocks bscan_refclk] -to [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]]

#CDC from auroraIntra clocks to/from clkgen_pll_CLKOUT1 (125mhz system clk)
set_max_delay -from [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -to [get_clocks auroraI_user_clk_i] -datapath_only 8.0
set_max_delay -from [get_clocks auroraI_user_clk_i] -to [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -datapath_only 8.0
set_max_delay -from [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -to [get_clocks auroraI_drp_clk_i] -datapath_only 8.0
set_max_delay -from [get_clocks auroraI_drp_clk_i] -to [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -datapath_only 8.0
set_max_delay -from [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -to [get_clocks auroraI_init_clk_i] -datapath_only 8.0
set_max_delay -from [get_clocks auroraI_init_clk_i] -to [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -datapath_only 8.0


#CDC from aurora clk (TS_user_clk_i_all) to/from clkgen_pll_CLKOUT1(125MHz clk)
set_max_delay -from [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -to [get_clocks TS_user_clk_i_all] -datapath_only 8.0
set_max_delay -from [get_clocks TS_user_clk_i_all] -to [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -datapath_only 8.0
#CDC from aurora sync clk (TS_sync_clk_i_all) to/from clkgen_pll_CLKOUT1(125MHz clk)
#set_max_delay -from [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -to [get_clocks TS_sync_clk_i_all] -datapath_only 8.0
#set_max_delay -from [get_clocks TS_sync_clk_i_all] -to [get_clocks -of_objects [get_pins host_pcieHostTop_ep7/clkgen_pll/CLKOUT1]] -datapath_only 8.0

set_false_path -from [get_cells */*auroraExt119/auroraExtImport/aurora_64b66b_block_i/gen_code_reset_logic[*].support_reset_logic_i/gt_rst_r_reg*] -to [get_cells */*auroraExt119/auroraExtImport/aurora_64b66b_block_i/gen_code_reset_logic[*].support_reset_logic_i/u_rst_sync_gt/stg1_aurora_64b66b_cdc_to_reg]

set_false_path -from [get_clocks userclk2] -to [get_clocks TS_user_clk_i_all]
set_false_path -from [get_clocks TS_user_clk_i_all] -to [get_clocks userclk2]
set_false_path -from [get_clocks userclk2_1] -to [get_clocks TS_user_clk_i_all]
set_false_path -from [get_clocks TS_user_clk_i_all] -to [get_clocks userclk2_1]

set_false_path -from [get_clocks userclk2] -to [get_clocks clkgen_pll_CLKOUT1]
set_false_path -from [get_clocks clkgen_pll_CLKOUT1] -to [get_clocks userclk2]

set_false_path -from [get_clocks TS_user_clk_i_all] -to [get_clocks clkgen_pll_CLKOUT1*]
set_false_path -from [get_clocks clkgen_pll_CLKOUT1*] -to [get_clocks TS_user_clk_i_all]

set_false_path -from [get_clocks clkgen_pll_CLKOUT1*] -to [get_clocks clkgen_pll_CLKOUT1*]
set_false_path -from [get_clocks clkgen_pll_CLKOUT1*] -to [get_clocks clkgen_pll_CLKOUT1*]

## added by cw for v15.07.3
#set_false_path -from [get_clocks GT_REFCLK1] -to [get_clocks auroraI_drp_clk_i]
#set_false_path -from [get_clocks GT_REFCLK1] -to [get_clocks auroraI_init_clk_i]

#set_false_path -from [get_clocks clkgen_pll_CLKOUT0_1] -to [get_clocks auroraI_user_clk_i]
#set_false_path -from [get_clocks auroraI_user_clk_i] -to [get_clocks clkgen_pll_CLKOUT0_1]
#set_false_path -from [get_clocks clkgen_pll_CLKOUT0_1] -to [get_clocks auroraI_drp_clk_i]
#set_false_path -from [get_clocks clkgen_pll_CLKOUT0_1] -to [get_clocks auroraI_init_clk_i]

#set_false_path -from [get_clocks clkgen_pll_CLKOUT0_1] -to [get_clocks GT_REFCLK1]

set_false_path -from [get_clocks clockGen_pll_CLKOUT0*] -to [get_clocks clockGen_pll_CLKOUT1*]
set_false_path -from [get_clocks clockGen_pll_CLKOUT1*] -to [get_clocks clockGen_pll_CLKOUT0*]
set_false_path -from [get_clocks clockGen_pll_CLKOUT2*] -to [get_clocks clkgen_pll_CLKOUT0*]
set_false_path -from [get_clocks clockGen_pll_CLKOUT2*] -to [get_clocks clkgen_pll_CLKOUT1*]

#set_false_path -from [get_clocks auroraI_user_clk_i] -to [get_clocks clkgen_pll_CLKOUT0*]

## added by cw for v15.08.1
#set_false_path -from [get_clocks auroraI_user_clk_i] -to [get_clocks clkgen_pll_CLKOUT1_1]
#set_false_path -from [get_clocks clkgen_pll_CLKOUT1_1] -to [get_clocks GT_REFCLK1]
#set_false_path -from [get_clocks clkgen_pll_CLKOUT1_1] -to [get_clocks auroraI_drp_clk_i]
#set_false_path -from [get_clocks clkgen_pll_CLKOUT1_1] -to [get_clocks auroraI_init_clk_i]
#set_false_path -from [get_clocks clkgen_pll_CLKOUT1_1] -to [get_clocks auroraI_user_clk_i]

# NEW
set_false_path -from [get_clocks GT_REFCLK1] -to [get_clocks auroraI_*_clk_i]
set_false_path -from [get_clocks auroraI_*_clk_i] -to [get_clocks GT_REFCLK1]

set_false_path -from [get_clocks clkgen_pll_CLKOUT*] -to [get_clocks GT_REFCLK1]
set_false_path -from [get_clocks GT_REFCLK1] -to [get_clocks clk_pll_CLKOUT*]

set_false_path -from [get_clocks clkgen_pll_CLKOUT*] -to [get_clocks auroraI_*_clk_i]
set_false_path -from [get_clocks auroraI_*_clk_i] -to [get_clocks clkgen_pll_CLKOUT*]

set_false_path -from [get_clocks clkgen_pll_CLKOUT1_1] -to [get_clocks auroraI_user_clk_i]
set_false_path -from [get_clocks auroraI_user_clk_i] -to [get_clocks clkgen_pll_CLKOUT1_1]

set_false_path -from [get_clocks clockGen_pll_CLKOUT2_1] -to [get_clocks clkgen_pll_CLKOUT1_1]
set_false_path -from [get_clocks clkgen pll_CLKOUT1_1] -to [clockGen_pll_CLKOUT2_1]

set_false_path -from [get_clocks clkgen_pll_CLKOUT1_1] -to [get_clocks GT_REFCLK1]
set_false_path -from [get_clocks clkgen_pll_CLKOUT1_1] -to [get_clocks auroraI_user_clk_i]
set_false_path -from [get_clocks clkgen_pll_CLKOUT1_1] -to [get_clocks auroraI_drp_clk_i]
set_false_path -from [get_clocks clkgen_pll_CLKOUT1_1] -to [get_clocks auroraI_init_clk_i]

