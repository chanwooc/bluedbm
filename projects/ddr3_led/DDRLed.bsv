import FIFO::*;
import Vector::*;
import Leds::*;

// DDR3 support
import DDR3Controller::*;
import DDR3Common::*;
import DDR3Sim::*;
//import DRAMController::*;
import Connectable::*;
import DefaultValue::*;

import HostInterface::*;
import Clocks::*;
import ConnectalClocks::*;

interface DDRLedRequest;
	method Action write(Bit#(32) addr, Bit#(32) data_high, Bit#(32) data_low);
	method Action readReq(Bit#(32) addr);
endinterface

interface DDRLedIndication;
	method Action readDone(Bit#(32) data_high, Bit#(32) data_low, Bit#(32) cnt);
endinterface

interface DDRLedPins;
	`ifndef BSIM
	interface LEDS leds;
	interface DDR3_Pins_ZC706 pins_ddr3;
	(* prefix="", always_ready, always_enabled *)
	method Action assert_reset((* port="SW" *)Bit#(1) sw);
	`endif
endinterface

interface DDRLed;
   interface DDRLedRequest request;
   interface DDRLedPins pins;
endinterface

`ifndef BSIM
module mkDDRLed#(HostInterface host, DDRLedIndication indication)(DDRLed);
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

	FIFO#(Bit#(32)) pendingRead <- mkSizedFIFO(20);

	C2B r2b_rst200 <- mkR2B(rst200);
	C2B r2b_ddr3rstn <- mkR2B(dram_ctrl.reset_n);

	rule ledval;
		counter <= counter+1;
		init_done <= pack(dram_ctrl.init_done);
	endrule

	rule read_indication;
		let d <- dram_ctrl.read;
		pendingRead.deq;
		indication.readDone(d[63:32], d[31:0], counter-pendingRead.first);
	endrule

	interface DDRLedRequest request;
		method Action write(Bit#(32) addr, Bit#(32) data_high, Bit#(32) data_low);
			dram_ctrl.write(truncate((addr)), extend({data_high, data_low}), (1<<64)-1);
		endmethod

		method Action readReq(Bit#(32) addr);
			dram_ctrl.readReq(truncate((addr)));
			pendingRead.enq(counter);
		endmethod
	endinterface

	interface DDRLedPins pins;
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
		`ifndef BSIM
		interface pins_ddr3 = dram_ctrl.ddr3;
		`endif
		method Action assert_reset(Bit#(1) sw);
			if (sw==1) begin
				rst200_gen.assertReset();
			end
		endmethod
   endinterface
endmodule
`else
module mkDDRLed#(HostInterface host, DDRLedIndication indication)(DDRLed);
	///////////////////////////
	/// DDR3 instantiation
	///////////////////////////
	DRAM_Wrapper dram_ctrl <- mkDRAMWrapperSim;

	Reg#(Bit#(32)) counter <- mkReg(0);
	FIFO#(Bit#(32)) pendingRead <- mkSizedFIFO(20);

	rule ledval;
		counter <= counter+1;
	endrule

	rule read_indication;
		let d <- dram_ctrl.read;
		pendingRead.deq;
		indication.readDone(d[63:32], d[31:0], counter-pendingRead.first);
	endrule

	interface DDRLedRequest request;
		method Action write(Bit#(32) addr, Bit#(32) data_high, Bit#(32) data_low);
			dram_ctrl.write(truncate((addr)), extend({data_high, data_low}), (1<<64)-1);
		endmethod

		method Action readReq(Bit#(32) addr);
			dram_ctrl.readReq(truncate((addr)));
			pendingRead.enq(counter);
		endmethod
	endinterface

	interface DDRLedPins pins;
	endinterface
endmodule
`endif
