CONNECTALDIR=../../tools/connectal/
S2H_INTERFACES = FlashRequest:Main.request
H2S_INTERFACES = Main:FlashIndication:host.derivedClock,host.derivedReset
MEM_READ_INTERFACES = lMain.dmaReadClient
MEM_WRITE_INTERFACES = lMain.dmaWriteClient

PIN_TYPE=Top_Pins
PIN_TYPE_INCLUDE=Top_Pins
PINOUT_FILE = pinout.sw.json
AUTOTOP = --interface pins:Main.pins

# specific for ZYNQ - Four Masters
NUMBER_OF_MASTERS=2
PLATFORM_NUMBER_OF_MASTERS=2
NUMBER_OF_RENGINES=2 # Flash Write (DMA Read)
NUMBER_OF_WENGINES=4 # Flash Read  (DMA Write)

BSVFILES = Main.bsv \
	../../xilinx/aurora_8b10b_zcu/AuroraImportZynq.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../controller/src/common/FlashBusModel.bsv \
	../../controller/src/model_zynq/FlashCtrlModel.bsv \
	../../controller/src/hw_zynq/FlashCtrlZynq.bsv

CPPFILES=main.cpp

CONNECTALFLAGS += -D DataBusWidth=128
CONNECTALFLAGS += -D NumReadClients=$(NUMBER_OF_RENGINES) -D NumWriteClients=$(NUMBER_OF_WENGINES)
CONNECTALFLAGS += -D IMPORT_HOST_CLOCKS
CONNECTALFLAGS += --mainclockperiod=5 --derivedclockperiod=9.091

ifeq ($(BOARD), bluesim)
CONNECTALFLAGS += -D BSIM
else ifeq ($(BOARD), verilator)
CONNECTALFLAGS += -D BSIM
else
NOHOST_XDC = ../../misc/nohost_zcu.xdc

CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_zcu/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_zcu/aurora_8b10b_zcu.xci \
	--constraint ../../xilinx/aurora_8b10b_zcu/aurora_8b10b_zcu_exdes.xdc \
	--constraint $(NOHOST_XDC) \
	--implconstraint ../../xilinx/aurora_8b10b_zcu/aurora_8b10b_zcu_exdes.xdc \
	--implconstraint $(NOHOST_XDC) 

$(IPDIR)/$(BOARD)/aurora_8b10b_zcu/aurora_8b10b_zcu.xci: ../../core-scripts/synth-aurora-intra-zcu.tcl
	cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra-zcu.tcl

ip.%:
	make gen.$(*)
	BOARD=$(*) make IPDIR=$(IPDIR) $(IPDIR)/$(*)/aurora_8b10b_zcu/aurora_8b10b_zcu.xci
endif

include $(CONNECTALDIR)/Makefile.connectal
