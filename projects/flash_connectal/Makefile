CONNECTALDIR=../../tools/connectal/

INTERFACES = FlashRequest FlashIndication

PIN_TYPE=Top_Pins
PIN_TYPE_INCLUDE=TopPins
NUMBER_OF_MASTERS=1

BSVFILES = IfcNames.bsv Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_fmc1_new/AuroraImportFmc1.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../controller/src/common/FlashBusModel.bsv \
	../../controller/src/model_virtex/FlashCtrlModel.bsv \
	../../controller/src/hw_virtex/FlashCtrlVirtex.bsv

CPPFILES=main.cpp

CONNECTALFLAGS  = -D IMPORT_HOST_CLOCKS -D DataBusWidth=128 --clib rt
#CONNECTALFLAGS += -P mkPcieEndpointX7 -P mkMemMasterEngine -P mkMemSlaveEngineSynth -P mkPcieTracer
#CONNECTALFLAGS += -P mkConnectalTop
CONNECTALFLAGS += --bsvpath=$(BOARD)/generatedbsv

ifneq ($(BOARD), bluesim)
CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_fmc1_new/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	-C ../../xilinx/aurora_8b10b_fmc1_new/aurora_8b10b_fmc1_exdes.xdc \
	--constraint ../../misc/bluedbm.xdc \
	--implconstraint ../../misc/bluedbm.xdc \

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
prebuild:: $(AURORA_INTRA)

$(AURORA_INTRA):
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra.tcl)
endif

include $(CONNECTALDIR)/Makefile.connectal
