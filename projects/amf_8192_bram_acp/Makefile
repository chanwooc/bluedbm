CONNECTALDIR?=../../tools/connectal/
S2H_INTERFACES = FlashRequest:Main.request
H2S_INTERFACES = Main:FlashIndication:host.derivedClock,host.derivedReset
MEM_READ_INTERFACES = lMain.dmaReadClient
MEM_WRITE_INTERFACES = lMain.dmaWriteClient

PIN_TYPE=Top_Pins
PIN_TYPE_INCLUDE=Top_Pins
AUTOTOP = --interface pins:Main.pins

# specific for ZYNQ - Four Masters
#NUMBER_OF_MASTERS=4
#PLATFORM_NUMBER_OF_MASTERS=4
CONNECTALFLAGS += -D USE_ACP
NUMBER_OF_ENGINES=9

BSVFILES = Main.bsv  \
	../aftl_bram/Dummy.bsv \
	../../xilinx/aurora_8b10b_zynq/AuroraImportZynq.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../controller/src/common/FlashBusModel.bsv \
	../../controller/src/model_zynq/FlashCtrlModel.bsv \
	../../controller/src/hw_zynq/FlashCtrlZynq.bsv

CPPFILES=main_example.cpp

CONNECTALFLAGS += -D DataBusWidth=64
CONNECTALFLAGS += -D NumReadClients=$(NUMBER_OF_ENGINES) -D NumWriteClients=$(NUMBER_OF_ENGINES)
CONNECTALFLAGS += -D IMPORT_HOST_CLOCKS
CONNECTALFLAGS += --mainclockperiod=6 --derivedclockperiod=5

ifeq ($(BOARD), bluesim)
CONNECTALFLAGS += -D BSIM
else ifeq ($(BOARD), verilator)
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

$(IPDIR)/$(BOARD)/aurora_8b10b_zynq/aurora_8b10b_zynq.xci: ../../core-scripts/synth-aurora-intra-zynq.tcl
	cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra-zynq.tcl

ip.%:
	make gen.$(*)
	BOARD=$(*) make IPDIR=$(IPDIR) $(IPDIR)/$(*)/aurora_8b10b_zynq/aurora_8b10b_zynq.xci
endif

include $(CONNECTALDIR)/Makefile.connectal
