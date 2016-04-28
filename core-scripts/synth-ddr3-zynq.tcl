source board.tcl
source $connectaldir/scripts/connectal-synth-ip.tcl
set scriptsdir [file dirname [file normalize [info script]] ]

connectal_synth_ip mig_7series 2.* ddr3_zynq [list CONFIG.XML_INPUT_FILE "$scriptsdir/ddr3-zynq.prj" CONFIG.RESET_BOARD_INTERFACE {Custom} CONFIG.MIG_DONT_TOUCH_PARAM {Custom} CONFIG.BOARD_MIG_PARAM {Custom}]
