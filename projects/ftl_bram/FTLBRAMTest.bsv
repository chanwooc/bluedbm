import FIFO::*;
import Vector::*;
import Leds::*;

// DDR3 support
//import DDR3Sim::*;
//import DDR3Controller::*;
//import DDR3Common::*;
//import DRAMController::*;
import BRAM::*;
import Connectable::*;
import DefaultValue::*;

import ControllerTypes::*;

import HostInterface::*;
import Clocks::*;
import ConnectalClocks::*;


import FTL::*;

interface FTLBRAMTestRequest;
	method Action translate(Bit#(32) lpa);
//	method Action loadMap(Bit#(32) sgId);
endinterface

interface FTLBRAMTestIndication;
//	method Action loadDone(Bit#(32) dummy);
	method Action translateDone(Bit#(32) valid,Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) cnt);
endinterface

interface FTLBRAMTestPins;
//	`ifndef BSIM
//	interface LEDS leds;
//	interface DDR3_Pins_ZC706 pins_ddr3;
//	(* prefix="", always_ready, always_enabled *)
//	method Action assert_reset((* port="SW" *)Bit#(1) sw);
//	`endif
endinterface

interface FTLBRAMTest;
   interface FTLBRAMTestRequest request;
   interface FTLBRAMTestPins pins;
endinterface


`ifndef BSIM
module mkFTLBRAMTest#(HostInterface host, FTLBRAMTestIndication indication)(FTLBRAMTest);
	///////////////////////////
	/// BRAM instantiation
	///////////////////////////
	BRAM_Wrapper bram_ctrl <- mkBRAMWrapper;

	Reg#(Bit#(32)) counter <- mkReg(0);
	Reg#(Bit#(1)) init_done <- mkReg(0);

	FIFO#(Bit#(32)) pendingReq <- mkSizedFIFO(20);

	rule ledval;
		counter <= counter+1;
		init_done <= pack(bram_ctrl.init_done);
	endrule

	// FTL
	FTLIfc myFTL <- mkFTL(bram_ctrl);

	rule read_indication;
		let d <- myFTL.get;
		let valid = isValid(d);
		let phyAddr = fromMaybe(?, d); 
		$display("[FTLBRAMTest.bsv] read_indication: %d %d %d %d", phyAddr.bus, phyAddr.chip, phyAddr.block, phyAddr.page);
		pendingReq.deq;
		indication.translateDone( zeroExtend(pack(isValid(d))),
								zeroExtend(phyAddr.bus),
								zeroExtend(phyAddr.chip),
								zeroExtend(phyAddr.block),
								zeroExtend(phyAddr.page),
								counter - pendingReq.first
		);
	endrule

	interface FTLBRAMTestRequest request;
		method Action translate(Bit#(32) lpa);
			myFTL.translate(lpa);
			pendingReq.enq(counter);
		endmethod
	endinterface

	interface FTLBRAMTestPins pins;
	endinterface
endmodule
`else
module mkFTLBRAMTest#(HostInterface host, FTLBRAMTestIndication indication)(FTLBRAMTest);
	///////////////////////////
	/// DDR3 instantiation
	///////////////////////////
	let dram_ctrl <- mkDRAMWrapperSim;

	Reg#(Bit#(32)) counter <- mkReg(0);
	FIFO#(Bit#(32)) pendingReq <- mkSizedFIFO(20);

	rule ledval;
		counter <= counter+1;
	endrule

	// FTL
	FTLIfc myFTL <- mkFTL(dram_ctrl);

	rule read_indication;
		let d <- myFTL.get;
		let valid = isValid(d);
		let phyAddr = fromMaybe(?, d); 
		pendingReq.deq;
		indication.translateDone( zeroExtend(pack(isValid(d))),
								zeroExtend(phyAddr.bus),
								zeroExtend(phyAddr.chip),
								zeroExtend(phyAddr.block),
								zeroExtend(phyAddr.page),
								counter - pendingReq.first
		);
	endrule

	interface FTLBRAMTestRequest request;
		method Action translate(Bit#(32) lpa);
			myFTL.translate(lpa);
			pendingReq.enq(counter);
		endmethod
	endinterface

	interface FTLBRAMTestPins pins;
	endinterface
endmodule
`endif
