// BRAM for FTL to support ONE flash card (BRAM_Wrapper1)

import FIFO::*;
import FIFOF::*;
import BRAM::*;
import Vector::*;
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

	FIFO#(Bit#(512)) respA <- mkFIFO; // TODO: mkSizedFIFO(4)
	FIFO#(Bit#(512)) respB <- mkFIFO;

	// for map upload/download
	FIFOF#(MapLockMode) lockFIFO <- mkFIFOF;

	function BRAMRequestBE#(Bit#(14), Bit#(512), 64) makeRequest(Bit#(64) write, Bit#(14) addr, Bit#(512) data);
		return BRAMRequestBE{
			writeen: write,
			responseOnWrite: False,
			address: addr,
			datain: data
		};
	endfunction

	mkConnection( bram.portA.response, toPut(respA) );
	mkConnection( bram.portB.response, toPut(respB) );

	method Action readReq(Bit#(14) addr);// if (!lockFIFO.notEmpty);
		bram.portA.request.put(makeRequest(0, addr, ?));
	endmethod

	method Action write(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen);// if (!lockFIFO.notEmpty);
		bram.portA.request.put(makeRequest(byteen, addr, data));
	endmethod

	method ActionValue#(Bit#(512)) read;// if (!lockFIFO.notEmpty);
		let d <- toGet(respA).get;
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
		let d <- toGet(respB).get;
		return d;
	endmethod
endmodule

module mkBRAM_Wrapper_4Banks(BRAM_Wrapper1);
	BRAM_Configure cfg = defaultValue;
	Vector#(4, BRAM2PortBE#(Bit#(12), Bit#(512), 64)) bram <- replicateM(mkBRAM2ServerBE(cfg));

	FIFO#(Bit#(512)) respA   <- mkFIFO;//<- mkSizedFIFO(4); // TODO: mkSizedFIFO(16)
	FIFO#(Bit#(512)) respB  <- mkFIFO;//<- mkSizedFIFO(4);

	FIFO#(Bit#(2)) respMuxA <- mkFIFO;
	FIFO#(Bit#(2)) respMuxB <- mkFIFO;

	function BRAMRequestBE#(Bit#(12), Bit#(512), 64) makeRequest(Bit#(64) write, Bit#(12) addr, Bit#(512) data);
		return BRAMRequestBE{
			writeen: write,
			responseOnWrite: False,
			address: addr,
			datain: data
		};
	endfunction

	// mkConnection( bram.portA.response, toPut(respA) );
	// mkConnection( bram.portB.response, toPut(respB) );

	rule forward_resp1;
		let d <- bram[respMuxA.first].portA.response.get;
		respA.enq(d);
		respMuxA.deq;
	endrule

	rule forward_resp2;
		let d <- bram[respMuxB.first].portB.response.get;
		respB.enq(d);
		respMuxB.deq;
	endrule

	// for map upload/download
	FIFO#(MapLockMode) lockFIFO <- mkFIFO;

	method Action readReq(Bit#(14) addr);
		bram[addr[1:0]].portA.request.put(makeRequest(0, addr[13:2], ?));
		respMuxA.enq(addr[1:0]);
	endmethod

	method Action write(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen);
		bram[addr[1:0]].portA.request.put(makeRequest(byteen, addr[13:2], data));
	endmethod

	method ActionValue#(Bit#(512)) read;
		let d <- toGet(respA).get;
		return d;
	endmethod


	method Action lockPortB(MapLockMode a);
		lockFIFO.enq(a);
	endmethod

	method Action unlockPortB;
		lockFIFO.clear;
	endmethod

	method Action readReqB(Bit#(14) addr) if (lockFIFO.first==DOWNLOAD);
		bram[addr[1:0]].portB.request.put(makeRequest(0, addr[13:2], ?));
		respMuxB.enq(addr[1:0]);
	endmethod

	method Action writeB(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen) if (lockFIFO.first==UPLOAD);
		bram[addr[1:0]].portB.request.put(makeRequest(byteen, addr[13:2], data));
	endmethod

	method ActionValue#(Bit#(512)) readB if (lockFIFO.first==DOWNLOAD);
		let d <- toGet(respB).get;
		return d;
	endmethod
endmodule
