#CDC from auroraIntra clocks to/from ps7_fclk_0_c/O (usually 200MHz Clock)
set_max_delay -from [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -to [get_clocks auroraI_user_clk_i] -datapath_only 5.0
set_max_delay -from [get_clocks auroraI_user_clk_i] -to [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -datapath_only 5.0
set_max_delay -from [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -to [get_clocks auroraI_drp_clk_i] -datapath_only 5.0
set_max_delay -from [get_clocks auroraI_drp_clk_i] -to [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -datapath_only 5.0
set_max_delay -from [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -to [get_clocks auroraI_init_clk_i] -datapath_only 5.0
set_max_delay -from [get_clocks auroraI_init_clk_i] -to [get_clocks -of_objects [get_pins ps7_fclk_0_c/O]] -datapath_only 5.0

set_false_path -from [get_clocks GT_REFCLK1] -to [get_clocks auroraI_drp_clk_i]
set_false_path -from [get_clocks GT_REFCLK1] -to [get_clocks auroraI_init_clk_i]
	
#Vivado 2015.4 only
#set_property CLKFBOUT_PHASE 0.000 [get_cells ts_0_hwmain_flashCtrl_auroraIntra/auroraIntraClockDiv4_clkdiv]
#set_property CLKFBOUT_PHASE 0.000 [get_cells ts_0_hwmain_auroraExtClockDiv4_clkdiv]
