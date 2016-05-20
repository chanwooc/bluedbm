////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2014  Bluespec, Inc.  ALL RIGHTS RESERVED.
////////////////////////////////////////////////////////////////////////////////
//  Filename      : XilinxZC706DDR3.bsv
//  Description   : 
////////////////////////////////////////////////////////////////////////////////
package DDR3Controller;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Connectable       ::*;
import Clocks            ::*;
import FIFO              ::*;
import FIFOF             ::*;
import SpecialFIFOs      ::*;
import TriState          ::*;
import Vector            ::*;
import DefaultValue      ::*;
import Counter           ::*;
import CommitIfc         ::*;
import Memory            ::*;
import ClientServer      ::*;
import GetPut            ::*;
import BUtils            ::*;
import I2C               ::*;
import StmtFSM           ::*;
import DDR3Common        ::*;

import XilinxCells       ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////
//`define DDR3_VC707 29, 256, 32, 2, 64, 8, 15, 10, 3, 1, 1, 1, 1, 1
`define DDR3_UserAddrSz 28    // 1+3+14+10 (rank/bank/row/col)
`define DDR3_UserDataSz 512
`define DDR3_ZC706 `DDR3_UserAddrSz, `DDR3_UserDataSz, 64, 1, 64, 8, 14, 10, 3, 1, 1, 1, 1, 1

typedef DDR3_Pins#(`DDR3_ZC706) DDR3_Pins_ZC706;
typedef DDR3_User#(`DDR3_ZC706) DDR3_User_ZC706;
typedef DDR3_Controller#(`DDR3_ZC706) DDR3_Controller_ZC706;
typedef VDDR3_User_Xilinx#(`DDR3_ZC706) VDDR3_User_Xilinx_ZC706;
typedef VDDR3_Controller_Xilinx#(`DDR3_ZC706) VDDR3_Controller_Xilinx_ZC706;

// User types (added by Chanwoo)
// Xilinx MIG core related types start with DDR3
// Others start with DRAM
typedef `DDR3_UserAddrSz DRAM_AddrSz;
typedef `DDR3_UserDataSz DRAM_DataSz;
typedef Bit#(DRAM_AddrSz) DRAM_AddrT;
typedef Bit#(DRAM_DataSz) DRAM_DataT;
typedef MemoryRequest#(DRAM_AddrSz, DRAM_DataSz) DRAM_Request;
typedef MemoryResponse#(DRAM_DataSz) DRAM_Response;
typedef MemoryClient#(DRAM_AddrSz, DRAM_DataSz) DRAM_Client;
typedef MemoryServer#(DRAM_AddrSz, DRAM_DataSz) DRAM_Server;
typedef 32 MAX_OUTSTANDING_READS;

interface DRAM_Wrapper;
//	interface Put#(DRAM_Request) request;
//	interface Get#(DRAM_Response) response;

	method Action readReq(DRAM_AddrT addr);
	method Action write(DRAM_AddrT addr, DRAM_DataT data, Bit#(TDiv#(DRAM_DataSz,8)) byteen);
	method ActionValue#(DRAM_DataT) read();
	method Bool init_done;
	
	interface DDR3_Pins_ZC706 ddr3;
	interface Clock clock;
	interface Reset reset_n;
endinterface


////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
import "BVI" ddr3_wrapper =
module vMkZC706DDR3Controller#(DDR3_Configure cfg, Clock refclk)(VDDR3_Controller_Xilinx_ZC706);
   default_clock clk(sys_clk_i);
   default_reset rst(sys_rst);
   
   input_clock refclk(clk_ref_i) = refclk;
   
   parameter SIM_BYPASS_INIT_CAL = (cfg.simulation) ? "FAST" : "OFF";
   parameter SIMULATION          = (cfg.simulation) ? "TRUE" : "FALSE";
   
   interface DDR3_Pins ddr3;
      ifc_inout   dq(ddr3_dq)          clocked_by(no_clock)  reset_by(no_reset);
      ifc_inout   dqs_p(ddr3_dqs_p)    clocked_by(no_clock)  reset_by(no_reset);
      ifc_inout   dqs_n(ddr3_dqs_n)    clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_ck_p    clk_p   clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_ck_n    clk_n   clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_cke     cke     clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_cs_n    cs_n    clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_ras_n   ras_n   clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_cas_n   cas_n   clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_we_n    we_n    clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_reset_n reset_n clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_dm      dm      clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_ba      ba      clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_addr    a       clocked_by(no_clock)  reset_by(no_reset);
      method      ddr3_odt     odt     clocked_by(no_clock)  reset_by(no_reset);
   endinterface
   
   interface VDDR3_User_Xilinx user;
      output_clock    clock(ui_clk);
      output_reset    reset(ui_clk_sync_rst);
      method init_calib_complete      init_done    clocked_by(no_clock) reset_by(no_reset);
      method          		      app_addr(app_addr) enable((*inhigh*)en0) clocked_by(user_clock) reset_by(no_reset);
      method                          app_cmd(app_cmd)   enable((*inhigh*)en00) clocked_by(user_clock) reset_by(no_reset);
      method          		      app_en(app_en)     enable((*inhigh*)en1) clocked_by(user_clock) reset_by(no_reset);
      method          		      app_wdf_data(app_wdf_data) enable((*inhigh*)en2) clocked_by(user_clock) reset_by(no_reset);
      method          		      app_wdf_end(app_wdf_end)   enable((*inhigh*)en3) clocked_by(user_clock) reset_by(no_reset);
      method          		      app_wdf_mask(app_wdf_mask) enable((*inhigh*)en4) clocked_by(user_clock) reset_by(no_reset);
      method          		      app_wdf_wren(app_wdf_wren) enable((*inhigh*)en5) clocked_by(user_clock) reset_by(no_reset);
      method app_rd_data              app_rd_data clocked_by(user_clock) reset_by(no_reset);
      method app_rd_data_end          app_rd_data_end clocked_by(user_clock) reset_by(no_reset);
      method app_rd_data_valid        app_rd_data_valid clocked_by(user_clock) reset_by(no_reset);
      method app_rdy                  app_rdy clocked_by(user_clock) reset_by(no_reset);
      method app_wdf_rdy              app_wdf_rdy clocked_by(user_clock) reset_by(no_reset);
   endinterface
   
   schedule
   (
    ddr3_clk_p, ddr3_clk_n, ddr3_cke, ddr3_cs_n, ddr3_ras_n, ddr3_cas_n, ddr3_we_n, 
    ddr3_reset_n, ddr3_dm, ddr3_ba, ddr3_a, ddr3_odt, user_init_done
    )
   CF
   (
    ddr3_clk_p, ddr3_clk_n, ddr3_cke, ddr3_cs_n, ddr3_ras_n, ddr3_cas_n, ddr3_we_n, 
    ddr3_reset_n, ddr3_dm, ddr3_ba, ddr3_a, ddr3_odt, user_init_done
    );
   
   schedule 
   (
    user_app_addr, user_app_en, user_app_wdf_data, user_app_wdf_end, user_app_wdf_mask, user_app_wdf_wren, user_app_rd_data, 
    user_app_rd_data_end, user_app_rd_data_valid, user_app_rdy, user_app_wdf_rdy, user_app_cmd
    )
   CF
   (
    user_app_addr, user_app_en, user_app_wdf_data, user_app_wdf_end, user_app_wdf_mask, user_app_wdf_wren, user_app_rd_data, 
    user_app_rd_data_end, user_app_rd_data_valid, user_app_rdy, user_app_wdf_rdy, user_app_cmd
    );

endmodule

module mkDDR3Controller_ZC706#(DDR3_Configure cfg, Clock refclk)(DDR3_Controller_ZC706);
   (* hide_all *)
   let _v <- vMkZC706DDR3Controller(cfg, refclk);
   let _m <- mkXilinxDDR3Controller_1beat(_v, cfg);
   return _m;
endmodule


//defined above
//interface DDR3_Wrapper;
//	interface Put#(DDR3_UserRequest) request;
//	interface Get#(DDR3_UserResponse) response;
//	
//	interface DDR3_Pins_ZC706 ddr3;
// endinterface


// refclk: 200MHz FPGA clock, refrst: reset associated with refclk
module mkDRAMWrapper#(Clock refclk, Reset refrst)(DRAM_Wrapper);
	FIFO#(DRAM_Request)  reqs <- mkFIFO;
	FIFO#(DRAM_Response) resp <- mkFIFO;

	// a wrapper module for a Xilinx MIG IP core
	DDR3_Configure cfg = defaultValue;
	cfg.reads_in_flight = 32;
	DDR3_Controller_ZC706 ddr3_ctrl <- mkDDR3Controller_ZC706(defaultValue, refclk, clocked_by refclk, reset_by refrst);

	Clock uClock <- exposeCurrentClock;
	Reset uReset <- exposeCurrentReset;
	Clock dClock = ddr3_ctrl.user.clock;
	Reset dReset = ddr3_ctrl.user.reset_n;

	// Connectal clock domain <-> DRAM user clock domain
	SyncFIFOIfc#(DRAM_Request)  reqs_sync <- mkSyncFIFO(8, uClock, uReset, dClock);
	SyncFIFOIfc#(DRAM_Response) resp_sync <- mkSyncFIFO(8, dClock, dReset, uClock);

	mkConnection(toGet(reqs), toPut(reqs_sync));
	mkConnection(toPut(resp), toGet(resp_sync));

	let dram_client = (
		interface DRAM_Client;
			interface request = toGet(reqs_sync);
			interface response = toPut(resp_sync);
		endinterface);
	
	mkConnection(dram_client, ddr3_ctrl.user, clocked_by dClock, reset_by dReset);

	method Action readReq(DRAM_AddrT addr);
		let req = DRAM_Request{write: False, byteen: ?, address:addr, data: ?};
		toPut(reqs).put(req);
	endmethod

	method Action write(DRAM_AddrT addr, DRAM_DataT data, Bit#(TDiv#(DRAM_DataSz,8)) byteen);
		let req = DRAM_Request{write: True, byteen: byteen, address:addr, data: data};
		toPut(reqs).put(req);
	endmethod

	method ActionValue#(DRAM_DataT) read();
		let d <- toGet(resp).get;
		return d.data;
	endmethod

	method init_done = ddr3_ctrl.user.init_done;
	interface ddr3 = ddr3_ctrl.ddr3;
	interface clock = ddr3_ctrl.user.clock;
	interface reset_n = ddr3_ctrl.user.reset_n;
endmodule

instance Connectable#(DRAM_Client, DDR3_User_ZC706);
	module mkConnection#(DRAM_Client cli, DDR3_User_ZC706 usr)(Empty);
		// Make sure we have enough buffer space to not drop responses!
		Counter#(TLog#(MAX_OUTSTANDING_READS)) reads <- mkCounter(0, clocked_by(usr.clock), reset_by(usr.reset_n));
		FIFO#(DRAM_Response) respbuf <- mkSizedFIFO(valueof(MAX_OUTSTANDING_READS), clocked_by(usr.clock), reset_by(usr.reset_n));
   
		rule request (reads.value() != fromInteger(valueof(MAX_OUTSTANDING_READS)-1));
			let req <- cli.request.get();
			usr.request(req.address, (req.write) ? req.byteen : 0, req.data);

			if (req.write == False) begin
				reads.up();
			end
		endrule
   
		rule response (True);
			let x <- usr.read_data;
			respbuf.enq(unpack(x));
		endrule
   
		rule forward (True);
			let x <- toGet(respbuf).get();
			cli.response.put(x);
			reads.down();
		endrule
	endmodule
endinstance

endpackage: DDR3Controller

