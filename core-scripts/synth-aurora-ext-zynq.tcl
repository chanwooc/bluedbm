source board.tcl
source $connectaldir/scripts/connectal-synth-ip.tcl

set locs {0 1 2 3}
if [info exists env(AURORA_LOCS)] {
    set locs $env(AURORA_LOCS)
}

set core_version 9.2

if {[version -short] >= "2014.4"} {
    set core_version {9.3}
}
if {[version -short] >= "2015.2"} {
    ## this version changed pinout
    set core_version {10.0}
}
if {[version -short] >= "2015.4"} {
    set core_version {11.0}
}

foreach loc $locs {
    set loc_plus_1 [expr $loc + 1]
    connectal_synth_ip aurora_64b66b $core_version aurora_64b66b_X0Y$loc [list CONFIG.C_LINE_RATE {10.0} CONFIG.C_REFCLK_FREQUENCY {625.000} CONFIG.interface_mode {Streaming} CONFIG.C_GT_LOC_1 {X} CONFIG.C_GT_LOC_$loc_plus_1 {1}]
}
