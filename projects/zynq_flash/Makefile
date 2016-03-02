CONNECTALDIR=../../tools/connectal/

INTERFACES = FlashRequest FlashIndication

PIN_TYPE=Top_Pins
PIN_TYPE_INCLUDE=TopPins

# specific for ZYNQ - Four Masters
NUMBER_OF_MASTERS=4
PLATFORM_NUMBER_OF_MASTERS=4

BSVFILES = IfcNames.bsv Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_zynq/AuroraImportZynq.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../controller/src/common/FlashBusModel.bsv \
	../../controller/src/model_zynq/FlashCtrlModel.bsv \
	../../controller/src/hw_zynq/FlashCtrlZynq.bsv

CPPFILES=main.cpp

CONNECTALFLAGS += -D DataBusWidth=64
CONNECTALFLAGS += -D NumReadClients=8 -D NumWriteClients=8
CONNECTALFLAGS += -D IMPORT_HOST_CLOCKS
CONNECTALFLAGS += --mainclockperiod=8 --derivedclockperiod=5
CONNECTALFLAGS += --bsvpath=$(BOARD)/generatedbsv

ifeq ($(BOARD), bluesim)
CONNECTALFLAGS += -D BSIM
else
NOHOST_XDC = ../../misc/nohost.xdc

CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_zynq/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_zynq/aurora_8b10b_zynq.xci \
	--constraint ../../xilinx/aurora_8b10b_zynq/aurora_8b10b_zynq_exdes.xdc \
	--constraint $(NOHOST_XDC) \
	--implconstraint ../../xilinx/aurora_8b10b_zynq/aurora_8b10b_zynq_exdes.xdc \
	--implconstraint $(NOHOST_XDC) 

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_zynq/aurora_8b10b_zynq_stub.v
prebuild:: $(AURORA_INTRA)

$(AURORA_INTRA): ../../core-scripts/synth-aurora-intra-zynq.tcl
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra-zynq.tcl)
endif

include $(CONNECTALDIR)/Makefile.connectal
