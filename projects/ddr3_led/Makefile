CONNECTALDIR?=../../tools/connectal/
S2H_INTERFACES = DDRLedRequest:DDRLed.request
H2S_INTERFACES = DDRLed:DDRLedIndication:host

BSVFILES = DDRLed.bsv
CPPFILES= main.cpp

ifeq ($(BOARD),zc706)
CONNECTALFLAGS += -D DataBusWidth=64
CONNECTALFLAGS += --mainclockperiod=5 --derivedclockperiod=5
endif

CONNECTALFLAGS += -D IMPORT_HOSTIF -D XILINX_SYS_CLK

PIN_TYPE = DDRLedPins
PIN_TYPE_INCLUDE = DDRLed
PINOUT_FILE = pinout.sw.json
AUTOTOP = --interface pins:DDRLed.pins

CONNECTALFLAGS += --bsvpath=../../xilinx/ddr3_zynq --bsvpath=../../src/lib

ifeq ($(BOARD), bluesim)
CONNECTALFLAGS += -D BSIM
else
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
endif

include $(CONNECTALDIR)/Makefile.connectal

