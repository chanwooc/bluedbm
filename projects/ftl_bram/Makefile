CONNECTALDIR?=../../tools/connectal/
S2H_INTERFACES = FTLBRAMTestRequest:FTLBRAMTest.request
H2S_INTERFACES = FTLBRAMTest:FTLBRAMTestIndication:host
MEM_READ_INTERFACES = lFTLBRAMTest.dmaReadClient
MEM_WRITE_INTERFACES = lFTLBRAMTest.dmaWriteClient

BSVFILES = FTLBRAMTest.bsv ../../controller/src/common/FlashBusModel.bsv
CPPFILES = main_loadsave.cpp

# specific for ZYNQ - Four Masters
NUMBER_OF_MASTERS=4
PLATFORM_NUMBER_OF_MASTERS=4
NUMBER_OF_ENGINES=8

CONNECTALFLAGS += -D DataBusWidth=64
CONNECTALFLAGS += -D NumReadClients=$(NUMBER_OF_ENGINES) -D NumWriteClients=$(NUMBER_OF_ENGINES)
CONNECTALFLAGS += --mainclockperiod=5 --derivedclockperiod=5

#CONNECTALFLAGS += -D IMPORT_HOSTIF -D XILINX_SYS_CLK
CONNECTALFLAGS += -D IMPORT_HOSTIF 

PIN_TYPE = FTLBRAMTestPins
PIN_TYPE_INCLUDE = FTLBRAMTest
#PINOUT_FILE = pinout.sw.json
AUTOTOP = --interface pins:FTLBRAMTest.pins

CONNECTALFLAGS += --bsvpath=../../src/lib

ifeq ($(BOARD), bluesim)
CONNECTALFLAGS += -D BSIM
else ifeq ($(BOARD), verilator)
CONNECTALFLAGS += -D BSIM
endif

include $(CONNECTALDIR)/Makefile.connectal

