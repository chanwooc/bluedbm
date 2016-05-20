import FIFO::*;
import Vector::*;
import Leds::*;

// DDR3 support
import DDR3Sim::*;
import DDR3Controller::*;
import DDR3Common::*;
//import DRAMController::*;
import Connectable::*;
import DefaultValue::*;

import ControllerTypes::*;

import HostInterface::*;
import Clocks::*;
import ConnectalClocks::*;


import FTL::*;

interface FTLTestRequest;
	method Action translate(Bit#(32) lpa);
//	method Action loadMap(Bit#(32) sgId);
endinterface

interface FTLTestIndication;
//	method Action loadDone(Bit#(32) dummy);
	method Action translateDone(Bit#(32) valid,Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) cnt);
endinterface

interface FTLTestPins;
	`ifndef BSIM
	interface LEDS leds;
	interface DDR3_Pins_ZC706 pins_ddr3;
	(* prefix="", always_ready, always_enabled *)
	method Action assert_reset((* port="SW" *)Bit#(1) sw);
	`endif
endinterface

interface FTLTest;
   interface FTLTestRequest request;
   interface FTLTestPins pins;
endinterface

`ifndef BSIM
module mkFTLTest#(HostInterface host, FTLTestIndication indication)(FTLTest);
	///////////////////////////
	/// DDR3 instantiation
	///////////////////////////
	Clock clk200 = host.tsys_clk_200mhz_buf;
	MakeResetIfc rst200_gen <- mkReset(100, True, clk200);
	Reset rst200 = rst200_gen.new_rst;

	DRAM_Wrapper dram_ctrl <- mkDRAMWrapper(clk200, rst200);

	/// led
	//	led(0) = reset signal (ddr3rstn)
	//	led(1) = divided down system clock (for blinking)
	//	led(2) = reset signal (rst200)
	//	led(3) = initialization (calibration) done
	Reg#(Bit#(32)) counter <- mkReg(0);
	Reg#(Bit#(1)) init_done <- mkReg(0);

	FIFO#(Bit#(32)) pendingReq <- mkSizedFIFO(20);

	C2B r2b_rst200 <- mkR2B(rst200);
	C2B r2b_ddr3rstn <- mkR2B(dram_ctrl.reset_n);

	rule ledval;
		counter <= counter+1;
		init_done <= pack(dram_ctrl.init_done);
	endrule

	// FTL
	FTLIfc myFTL <- mkFTL(dram_ctrl);

	rule read_indication;
		let d <- myFTL.get;
		let valid = isValid(d);
		let phyAddr = fromMaybe(?, d); 
		$display("[FTLTest.bsv] read_indication: %d %d %d %d", phyAddr.bus, phyAddr.chip, phyAddr.block, phyAddr.page);
		pendingReq.deq;
		indication.translateDone( zeroExtend(pack(isValid(d))),
								zeroExtend(phyAddr.bus),
								zeroExtend(phyAddr.chip),
								zeroExtend(phyAddr.block),
								zeroExtend(phyAddr.page),
								counter - pendingReq.first
		);
	endrule

	interface FTLTestRequest request;
		method Action translate(Bit#(32) lpa);
			myFTL.translate(lpa);
			pendingReq.enq(counter);
		endmethod
	endinterface

	interface FTLTestPins pins;
		interface LEDS leds;
			method Bit#(LedsWidth) leds;
				Bit#(LedsWidth) ret = 0;

				ret[0] = r2b_ddr3rstn.o;
				ret[1] = counter[26];
				ret[2] = r2b_rst200.o;
				ret[3] = (init_done);

				return ret;
			endmethod
		endinterface
		interface pins_ddr3 = dram_ctrl.ddr3;
		method Action assert_reset(Bit#(1) sw);
			if (sw==1) begin
				rst200_gen.assertReset();
			end
		endmethod
   endinterface
endmodule
`else
module mkFTLTest#(HostInterface host, FTLTestIndication indication)(FTLTest);
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

	interface FTLTestRequest request;
		method Action translate(Bit#(32) lpa);
			myFTL.translate(lpa);
			pendingReq.enq(counter);
		endmethod
	endinterface

	interface FTLTestPins pins;
	endinterface
endmodule
`endif
