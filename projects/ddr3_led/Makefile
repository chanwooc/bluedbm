CONNECTALDIR?=../../tools/connectal/
S2H_INTERFACES = EchoRequest:Echo.request
H2S_INTERFACES = Echo:EchoIndication:host

BSVFILES = Echo.bsv \
		   ../../xilinx/ddr3_zynq/DDR3Controller.bsv ../../src/lib/AuroraCommon.bsv
CPPFILES= main.cpp

ifeq ($(BOARD),zc706)
CONNECTALFLAGS += -D DataBusWidth=64
CONNECTALFLAGS += --mainclockperiod=5 --derivedclockperiod=5
endif

CONNECTALFLAGS += -D IMPORT_HOSTIF -D XILINX_SYS_CLK

PIN_TYPE = EchoPins
PIN_TYPE_INCLUDE = Echo
PINOUT_FILE = pinout.sw.json
AUTOTOP = --interface pins:Echo.pins

NOHOST_XDC = ../../misc/nohost.xdc
CONNECTALFLAGS += --bsvpath=../../xilinx/ddr3_zynq
CONNECTALFLAGS += \
	--verilog ../../xilinx/ddr3_zynq/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/ddr3_zynq/ddr3_zynq.xci \
	--constraint ../../xilinx/ddr3_zynq/ddr3_zynq.xdc \
	--implconstraint ../../xilinx/ddr3_zynq/ddr3_zynq.xdc \

$(IPDIR)/$(BOARD)/ddr3_zynq/ddr3_zynq.xci: ../../core-scripts/synth-ddr3-zynq.tcl ../../core-scripts/ddr3-zynq.prj
	cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-ddr3-zynq.tcl

ip.%:
	make gen.$(*)
	BOARD=$(*) make IPDIR=$(IPDIR) $(IPDIR)/$(*)/ddr3_zynq/ddr3_zynq.xci

include $(CONNECTALDIR)/Makefile.connectal

