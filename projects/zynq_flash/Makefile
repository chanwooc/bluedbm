CONNECTALDIR=../../tools/connectal/

INTERFACES = FlashRequest FlashIndication

PIN_TYPE=Top_Pins
PIN_TYPE_INCLUDE=TopPins

# specific for ZYNQ
#NUMBER_OF_MASTERS=4
#PLATFORM_NUMBER_OF_MASTERS=4


ifeq ($(BOARD), vc707)
BSVFILES = IfcNames.bsv Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_fmc1_new/AuroraImportFmc1.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../controller/src/common/FlashBusModel.bsv \
	../../controller/src/model_virtex/FlashCtrlModel.bsv \
else
BSVFILES = IfcNames.bsv Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_zynq/AuroraImportZynq.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../controller/src/common/FlashBusModel.bsv \
	../../controller/src/model_zynq/FlashCtrlModel.bsv \
	../../controller/src/hw_zynq/FlashCtrlZynq.bsv
endif


CPPFILES=main.cpp

ifeq ($(BOARD), vc707)
CONNECTALFLAGS  = -D IMPORT_HOST_CLOCKS -D DataBusWidth=64 --clib rt
else
CONNECTALFLAGS  = -D DataBusWidth=64
endif

CONNECTALFLAGS += --bsvpath=$(BOARD)/generatedbsv

ifeq ($(BOARD), bluesim)
CONNECTALFLAGS += -D BSIM
endif

ifeq ($(BOARD), zc706)
BLUEDBM_XDC = ../../misc/nohost.xdc
else ifeq ($(BOARD), vc707)
BLUEDBM_XDC = ../../misc/bludedbm.xdc
endif

ifeq ($(BOARD), zc706)
CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_zynq/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_zynq/aurora_8b10b_zynq.xci \
	-C ../../xilinx/aurora_8b10b_zynq/aurora_8b10b_zynq_exdes.xdc \
	--constraint $(BLUEDBM_XDC) \
	--implconstraint $(BLUEDBM_XDC) 

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_zynq/aurora_8b10b_zynq_stub.v
prebuild:: $(AURORA_INTRA)

$(AURORA_INTRA):
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra-zynq.tcl)
endif

ifeq ($(BOARD), vc707)
CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_fmc1_new/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	-C ../../xilinx/aurora_8b10b_fmc1_new/aurora_8b10b_fmc1_exdes.xdc \
	--constraint $(BLUEDBM_XDC) \
	--implconstraint $(BLUEDBM_XDC) \

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
prebuild:: $(AURORA_INTRA)

$(AURORA_INTRA):
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra.tcl)
endif

include $(CONNECTALDIR)/Makefile.connectal
