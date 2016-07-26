// BRAM for FTL to support ONE flash card (BRAM_Wrapper1)

import FIFO::*;
import BRAM::*;
import Connectable::*;
import DefaultValue::*;

interface BRAM_Wrapper1;
	// followings are for FTL
	method Action readReq(Bit#(14) addr);
	method Action write(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen);
	method ActionValue#(Bit#(512)) read();

	//method Bool init_done;

	// followings are for MAP/MGR management
	method Action readReqB(Bit#(14) addr);
	method Action writeB(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen);
	method ActionValue#(Bit#(512)) readB();

	// followings are for scheduling of map upload/download
	method Action lockPortB(MapLockMode a);
	method Action unlockPortB;
endinterface

typedef enum { UPLOAD, DOWNLOAD } MapLockMode deriving (Bits, Eq);

module mkBRAM_Wrapper1(BRAM_Wrapper1);
	BRAM_Configure cfg = defaultValue;
	BRAM2PortBE#(Bit#(14), Bit#(512), 64) bram <- mkBRAM2ServerBE(cfg);

	FIFO#(Bit#(512)) resp  <- mkSizedFIFO(4); // TODO: mkSizedFIFO(?)
	FIFO#(Bit#(512)) resp2 <- mkSizedFIFO(4);

	function BRAMRequestBE#(Bit#(14), Bit#(512), 64) makeRequest(Bit#(64) write, Bit#(14) addr, Bit#(512) data);
		return BRAMRequestBE{
			writeen: write,
			responseOnWrite: False,
			address: addr,
			datain: data
		};
	endfunction

	mkConnection( bram.portA.response, toPut(resp) );
	mkConnection( bram.portB.response, toPut(resp2) );

	// for map upload/download
	FIFO#(MapLockMode) lockFIFO <- mkFIFO;

	method Action readReq(Bit#(14) addr);
		bram.portA.request.put(makeRequest(0, addr, ?));
	endmethod

	method Action write(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen);
		bram.portA.request.put(makeRequest(byteen, addr, data));
	endmethod

	method ActionValue#(Bit#(512)) read;
		let d <- toGet(resp).get;
		return d;
	endmethod


	method Action lockPortB(MapLockMode a);
		lockFIFO.enq(a);
	endmethod

	method Action unlockPortB;
		lockFIFO.clear;
	endmethod

	method Action readReqB(Bit#(14) addr) if (lockFIFO.first==DOWNLOAD);
		bram.portB.request.put(makeRequest(0, addr, ?));
	endmethod

	method Action writeB(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen) if (lockFIFO.first==UPLOAD);
		bram.portB.request.put(makeRequest(byteen, addr, data));
	endmethod

	method ActionValue#(Bit#(512)) readB if (lockFIFO.first==DOWNLOAD);
		let d <- toGet(resp2).get;
		return d;
	endmethod
endmodule
