// BRAM for FTL to support ONE flash card (BRAM_Wrapper1)

import FIFO::*;
import FIFOF::*;
import BRAM::*;
import Vector::*;
import Connectable::*;
import DefaultValue::*;

typedef enum { UPLOAD, DOWNLOAD } MapLockMode deriving (Bits, Eq);

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
	method Bool isLocked;
	method MapLockMode lockMode;
endinterface

module mkBRAM_Wrapper1(BRAM_Wrapper1);
	BRAM_Configure cfg = defaultValue;
	BRAM1PortBE#(Bit#(14), Bit#(512), 64) bram <- mkBRAM1ServerBE(cfg);

	FIFO#(Bit#(512)) respA <- mkFIFO; // TODO: mkSizedFIFO(4)
	//FIFO#(Bit#(512)) respB <- mkFIFO;
	mkConnection( bram.portA.response, toPut(respA) );
	//mkConnection( bram.portB.response, toPut(respB) );

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

	method Action readReq(Bit#(14) addr) if (!lockFIFO.notEmpty);
		bram.portA.request.put(makeRequest(0, addr, ?));
	endmethod

	method Action write(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen) if (!lockFIFO.notEmpty);
		bram.portA.request.put(makeRequest(byteen, addr, data));
	endmethod

	method ActionValue#(Bit#(512)) read if (!lockFIFO.notEmpty);
		//let d <- bram.portA.response.get;
		let d <- toGet(respA).get;
		return d;
	endmethod

	method Action lockPortB(MapLockMode a);
		lockFIFO.enq(a);
		bram.portAClear;
		respA.clear;
	endmethod

	method Action unlockPortB = lockFIFO.deq;
	method Bool isLocked = lockFIFO.notEmpty;
	method MapLockMode lockMode = lockFIFO.first;

	method Action readReqB(Bit#(14) addr) if (lockFIFO.first==DOWNLOAD);
		bram.portA.request.put(makeRequest(0, addr, ?));
	endmethod

	method Action writeB(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen) if (lockFIFO.first==UPLOAD);
		bram.portA.request.put(makeRequest(byteen, addr, data));
	endmethod

	method ActionValue#(Bit#(512)) readB if (lockFIFO.first==DOWNLOAD);
		//let d <- bram.portA.response.get;
		let d <- toGet(respA).get;
		return d;
	endmethod
endmodule

module mkBRAM_Wrapper2(BRAM_Wrapper1);
	BRAM_Configure cfg = defaultValue;
	BRAM2PortBE#(Bit#(14), Bit#(512), 64) bram <- mkBRAM2ServerBE(cfg);

	FIFO#(Bit#(512)) respA <- mkFIFO; // TODO: mkSizedFIFO(4)
	FIFO#(Bit#(512)) respB <- mkFIFO;
	mkConnection( bram.portA.response, toPut(respA) );
	mkConnection( bram.portB.response, toPut(respB) );

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

	method Action readReq(Bit#(14) addr) if (!lockFIFO.notEmpty);
		bram.portA.request.put(makeRequest(0, addr, ?));
	endmethod

	method Action write(Bit#(14) addr, Bit#(512) data, Bit#(64) byteen) if (!lockFIFO.notEmpty);
		bram.portA.request.put(makeRequest(byteen, addr, data));
	endmethod

	method ActionValue#(Bit#(512)) read if (!lockFIFO.notEmpty);
		let d <- bram.portA.response.get;
		return d;
	endmethod

	method Action lockPortB(MapLockMode a);
		lockFIFO.enq(a);
		bram.portBClear;
		respB.clear;
	endmethod

	method Action unlockPortB = lockFIFO.deq;
	method Bool isLocked = lockFIFO.notEmpty;
	method MapLockMode lockMode = lockFIFO.first;

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

