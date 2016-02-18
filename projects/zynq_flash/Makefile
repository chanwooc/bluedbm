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

CONNECTALFLAGS  = -D DataBusWidth=64
CONNECTALFLAGS += -D NumReadClients=8 -D NumWriteClients=8
CONNECTALFLAGS += --bsvpath=$(BOARD)/generatedbsv

ifeq ($(BOARD), bluesim)
CONNECTALFLAGS += -D BSIM
endif

BLUEDBM_XDC = ../../misc/nohost.xdc

CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_zynq/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_zynq/aurora_8b10b_zynq.xci \
	--constraint ../../xilinx/aurora_8b10b_zynq/aurora_8b10b_zynq_exdes.xdc \
	--constraint $(BLUEDBM_XDC) \
	--implconstraint ../../xilinx/aurora_8b10b_zynq/aurora_8b10b_zynq_exdes.xdc \
	--implconstraint $(BLUEDBM_XDC) 

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_zynq/aurora_8b10b_zynq_stub.v
prebuild:: $(AURORA_INTRA)

$(AURORA_INTRA):
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra-zynq.tcl)

include $(CONNECTALDIR)/Makefile.connectal
