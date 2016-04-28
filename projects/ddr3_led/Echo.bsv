// Copyright (c) 2013 Nokia, Inc.
// Copyright (c) 2013 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
import FIFO::*;
import Vector::*;
import Leds::*;

// DDR3 support
import DDR3Sim::*;
import DDR3Controller::*;
import DDR3Common::*;
import DRAMController::*;
import Connectable::*;
import DefaultValue::*;

import HostInterface::*;
import Clocks::*;
import ConnectalClocks::*;

interface EchoRequest;
	method Action write(Bit#(32) addr_hi, Bit#(32) addr_low, Bit#(32) data_high, Bit#(32) data_low);
	method Action readReq(Bit#(32) addr_hi, Bit#(32) addr_low);
endinterface

interface EchoIndication;
	method Action readDone(Bit#(32) data_high, Bit#(32) data_low);
endinterface

interface EchoPins;
    interface LEDS leds;
	interface DDR3_Pins_VC707_1GB pins_ddr3;
	(* prefix="", always_ready, always_enabled *)
    method Action assert_reset((* port="SW" *)Bit#(1) sw);
endinterface

interface Echo;
   interface EchoRequest request;
   interface EchoPins pins;
endinterface

typedef struct {
	Bit#(16) a;
	Bit#(16) b;
} EchoPair deriving (Bits);

module mkEcho#(HostInterface host, EchoIndication indication)(Echo);
    FIFO#(Bit#(32)) delay <- mkSizedFIFO(8);
    FIFO#(EchoPair) delay2 <- mkSizedFIFO(8);

	///////////////////////////
	/// DDR3 instantiation
	///////////////////////////
`ifndef BSIM
	Clock clk200 = host.tsys_clk_200mhz_buf;
	//Reset rst200 <- mkAsyncResetFromCR(4, clk200);
	MakeResetIfc rst200_gen <- mkReset(100, True, clk200);
	Reset rst200 = rst200_gen.new_rst;

	DRAMControllerIfc dramController <- mkDRAMController;
	
	DDR3_Configure_1G ddr3_cfg = defaultValue;
	//ddr3_cfg.reads_in_flight = 32; // adjust as needed
	DDR3_Controller_VC707_1GB ddr3_ctrl <- mkDDR3Controller_VC707_2_1(ddr3_cfg, clk200, clocked_by clk200, reset_by rst200);

	Clock ddr3clk = ddr3_ctrl.user.clock;
	Reset ddr3rstn = ddr3_ctrl.user.reset_n;

	// default clk (200MHz) to ddr3 user clk (200MHz) crossing
	let ddr_cli_200Mhz <- mkDDR3ClientSync(dramController.ddr3_cli, clockOf(dramController), resetOf(dramController), ddr3clk, ddr3rstn);
	mkConnection(ddr_cli_200Mhz, ddr3_ctrl.user);
`else
	DRAMControllerIfc dramController <- mkDRAMController;
	let ddr3_ctrl_user <- mkDDR3Simulator;
	mkConnection(dramController.ddr3_cli, ddr3_ctrl_user);
`endif

	/// led
	//  led(0) = reset signal (ddr3rstn)
	//  led(1) = divided down system clock (for blinking)
	//  led(2) = reset signal (rst200)
	//  led(3) = initialization (calibration) done
	Reg#(Bit#(27)) counter <- mkReg(0);
	Reg#(Bit#(1)) init_done <- mkReg(0);

	C2B r2b_rst200 <- mkR2B(rst200);
	C2B r2b_ddr3rstn <- mkR2B(ddr3rstn);

	rule ledval;
		counter <= counter+1;
		init_done <= pack(ddr3_ctrl.user.init_done);
	endrule

	let dram = dramController.user;

	rule read_indication;
		let d <- dram.read;
		indication.readDone(d[63:32], d[31:0]);
	endrule

	interface EchoRequest request;
		method Action write(Bit#(32) addr_hi, Bit#(32) addr_low, Bit#(32) data_high, Bit#(32) data_low);
			dram.write({addr_hi, addr_low}, zeroExtend({data_high, data_low}), 64);
		endmethod

		method Action readReq(Bit#(32) addr_hi, Bit#(32) addr_low);
			dram.readReq({addr_hi, addr_low}, 64);
		endmethod
	endinterface

	interface EchoPins pins;
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
		interface pins_ddr3 = ddr3_ctrl.ddr3;
	    method Action assert_reset(Bit#(1) sw);
			if (sw==1) begin
				rst200_gen.assertReset();
			end
		endmethod
   endinterface
endmodule
