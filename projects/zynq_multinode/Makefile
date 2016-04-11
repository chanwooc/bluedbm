CONNECTALDIR=../../tools/connectal/

INTERFACES = FlashRequest FlashIndication

PIN_TYPE=Top_Pins
PIN_TYPE_INCLUDE=TopPins

# specific for ZYNQ - Four Masters
NUMBER_OF_MASTERS=4
PLATFORM_NUMBER_OF_MASTERS=4
NUMBER_OF_ENGINES=8

BSVFILES = IfcNames.bsv Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_zynq/AuroraImportZynq.bsv \
	../../xilinx/aurora_64b66b_zynq/AuroraExtDummy.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../src/lib/AuroraExtEndpoint.bsv \
	../../controller/src/common/FlashBusModel.bsv \
	../../controller/src/model_zynq/FlashCtrlModel.bsv \
	../../controller/src/hw_zynq/FlashCtrlZynq.bsv

CPPFILES=main.cpp flash.cpp #flash.h

CONNECTALFLAGS += -D NodeCountLog=1 #currently two nodes (2->1?)
CONNECTALFLAGS += -D DataBusWidth=64
CONNECTALFLAGS += -D NumReadClients=$(NUMBER_OF_ENGINES) -D NumWriteClients=$(NUMBER_OF_ENGINES)
CONNECTALFLAGS += -D IMPORT_HOST_CLOCKS
CONNECTALFLAGS += --mainclockperiod=5 --derivedclockperiod=5
CONNECTALFLAGS += --bsvpath=$(BOARD)/generatedbsv
CONNECTALFLAGS += --cflags="-Wno-error=unused-variable"

ifeq ($(BOARD), bluesim)
CONNECTALFLAGS += -D BSIM
CONNECTALFLAGS += --bsimsource ../../xilinx/aurora_64b66b_zynq/bdpi.cpp 
else
NOHOST_XDC = ../../misc/nohost.xdc

CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_zynq/ \
	--verilog ../../xilinx/aurora_64b66b_zynq/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X0Y0/aurora_64b66b_X0Y0.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X0Y1/aurora_64b66b_X0Y1.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X0Y2/aurora_64b66b_X0Y2.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X0Y3/aurora_64b66b_X0Y3.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_zynq/aurora_8b10b_zynq.xci \
	--constraint ../../xilinx/aurora_64b66b_zynq/aurora_64b66b_exdes.xdc \
	--constraint ../../xilinx/aurora_8b10b_zynq/aurora_8b10b_zynq_exdes.xdc \
	--constraint $(NOHOST_XDC) \
	--implconstraint ../../xilinx/aurora_64b66b_zynq/aurora_64b66b_exdes.xdc \
	--implconstraint ../../xilinx/aurora_8b10b_zynq/aurora_8b10b_zynq_exdes.xdc \
	--implconstraint $(NOHOST_XDC) 

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_zynq/aurora_8b10b_zynq_stub.v
AURORA_EXT   = $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X0Y3/aurora_64b66b_X0Y3_stub.v
prebuild:: $(AURORA_INTRA) $(AURORA_EXT)

$(AURORA_INTRA): ../../core-scripts/synth-aurora-intra-zynq.tcl
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra-zynq.tcl)

$(AURORA_EXT): ../../core-scripts/synth-aurora-ext-zynq.tcl
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-ext-zynq.tcl)
	find $(CONNECTALDIR)/out/$(BOARD)/ -name "aurora_64b66b_X0Y?_wrapper.v" -exec sed -i "s/GT0_txdiffctrl_in[ \t]\+([4'b10]\+),/GT0_txdiffctrl_in (4'b1100),/g" '{}' \;
endif

include $(CONNECTALDIR)/Makefile.connectal
