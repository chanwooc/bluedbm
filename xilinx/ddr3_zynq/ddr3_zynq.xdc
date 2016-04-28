set_clock_groups -asynchronous -group {clk_fpga_0} -group {sys_clk}

set_false_path -from [get_pins -of_objects [get_cells -hier -filter {NAME =~ *ddr3_ctrl_user_reset_n/*}] -filter {NAME=~ *C}]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_pins -hierarchical *clk_ref_mmcm_gen.mmcm_i*CLKIN1] 
set_property slave_banks {34} [get_iobanks 33]
