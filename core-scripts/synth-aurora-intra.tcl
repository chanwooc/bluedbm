source board.tcl
source $connectaldir/scripts/connectal-synth-ip.tcl


set core_version "10.2"
if {[version -short] >= "2014.4"} {
    set core_version "10.3"
}
if {[version -short] >= "2015.1"} {
    set core_version "11.0"
}

connectal_synth_ip aurora_8b10b $core_version aurora_8b10b_fmc1 [list CONFIG.C_AURORA_LANES {4} CONFIG.C_LANE_WIDTH {4} CONFIG.C_LINE_RATE {4.4} CONFIG.C_REFCLK_FREQUENCY {275.000} CONFIG.Interface_Mode {Streaming} CONFIG.C_GT_LOC_24 {4} CONFIG.C_GT_LOC_23 {3} CONFIG.C_GT_LOC_22 {2} CONFIG.C_GT_LOC_21 {1} CONFIG.C_GT_LOC_1 {X}]
