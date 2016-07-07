CONNECTALDIR?=../../tools/connectal/
S2H_INTERFACES = FTLBRAMTestRequest:FTLBRAMTest.request
H2S_INTERFACES = FTLBRAMTest:FTLBRAMTestIndication:host

BSVFILES = FTLBRAMTest.bsv ../../controller/src/common/FlashBusModel.bsv
CPPFILES = main.cpp

ifneq ($(BOARD), bluesim)
CONNECTALFLAGS += -D DataBusWidth=64
CONNECTALFLAGS += --mainclockperiod=5 --derivedclockperiod=5
endif

CONNECTALFLAGS += -D IMPORT_HOSTIF -D XILINX_SYS_CLK

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

