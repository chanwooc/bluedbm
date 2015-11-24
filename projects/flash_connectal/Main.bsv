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

import FIFOF::*;
import FIFO::*;
import FIFOLevel::*;
import BRAMFIFO::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;

import Vector::*;
import List::*;

import ConnectalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;

import Clocks :: *;
import Xilinx       :: *;
`ifndef BSIM
import XilinxCells ::*;
`endif

import AuroraImportFmc1::*;

import ControllerTypes::*;
//import AuroraExtArbiter::*;
//import AuroraExtImport::*;
//import AuroraExtImport117::*;
import AuroraCommon::*;

import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;

interface FlashRequest;
	method Action readPage(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
	method Action writePage(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
	method Action eraseBlock(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) tag);
	method Action addDmaReadRefs(Bit#(32) pointer, Bit#(32) offset, Bit#(32) tag);
	method Action addDmaWriteRefs(Bit#(32) pointer, Bit#(32) offset, Bit#(32) tag);
	method Action start(Bit#(32) dummy);
	method Action debugDumpReq(Bit#(32) dummy);
	method Action setDebugVals (Bit#(32) flag, Bit#(32) debugDelay); 
endinterface

interface FlashIndication;
	method Action readDone(Bit#(32) tag);
	method Action writeDone(Bit#(32) tag);
	method Action eraseDone(Bit#(32) tag, Bit#(32) status);
	method Action debugDumpResp(Bit#(32) debug0, Bit#(32) debug1, Bit#(32) debug2, Bit#(32) debug3, Bit#(32) debug4, Bit#(32) debug5);
endinterface

// NumDmaChannels each for flash i/o and emualted i/o
//typedef TAdd#(NumDmaChannels, NumDmaChannels) NumObjectClients;
//typedef NumDmaChannels NumObjectClients;
typedef 128 DmaBurstBytes; 
Integer dmaBurstBytes = valueOf(DmaBurstBytes);
Integer dmaBurstWords = dmaBurstBytes/wordBytes; //128/16 = 8
Integer dmaBurstsPerPage = 65;//(pageSizeUser+dmaBurstBytes-1)/dmaBurstBytes; //ceiling, 65
Integer dmaBurstWordsLast = 2;//(pageSizeUser%dmaBurstBytes)/wordBytes; //num bursts in last dma; 2 bursts

interface MainIfc;
	interface FlashRequest request;
	interface Vector#(1, MemWriteClient#(WordSz)) dmaWriteClient;
	interface Vector#(1, MemReadClient#(WordSz)) dmaReadClient;
	interface Aurora_Pins#(4) aurora_fmc1;
	interface Aurora_Clock_Pins aurora_clk_fmc1;
endinterface

module mkMain#(FlashIndication indication, Clock clk250, Reset rst250)(MainIfc);

	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;


	Reg#(Bool) started <- mkReg(False);
	Reg#(Bit#(64)) cycleCnt <- mkReg(0);

	FIFO#(FlashCmd) flashCmdQ <- mkSizedFIFO(valueOf(NumTags));
	Vector#(NumTags, Reg#(BusT)) tag2busTable <- replicateM(mkRegU());
	Vector#(NumTags, Reg#(Tuple2#(Bit#(32),Bit#(32)))) dmaWriteRefs <- replicateM(mkRegU());
	Vector#(NumTags, Reg#(Tuple2#(Bit#(32),Bit#(32)))) dmaReadRefs <- replicateM(mkRegU());
	Vector#(NUM_BUSES, FIFO#(Tuple2#(Bit#(WordSz), TagT))) dmaWriteBuf <- replicateM(mkSizedBRAMFIFO(dmaBurstWords*2));
	Vector#(NUM_BUSES, FIFO#(Tuple2#(Bit#(WordSz), TagT))) dmaWriteBufOut <- replicateM(mkFIFO());

	GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
	`ifdef BSIM
		FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlModel(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`else
		FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlVirtex(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`endif

	//Create read/write engines with NUM_BUSES memservers
	MemreadEngine#(WordSz, 4, NUM_BUSES) re <- mkMemreadEngine;
	MemwriteEngine#(WordSz, 1, NUM_BUSES) we <- mkMemwriteEngine;
	//MemwriteEngineV#(WordSz, 2, NUM_BUSES) we <- mkMemwriteEngineBuff(1024);

	Vector#(NUM_BUSES, Reg#(Bit#(16))) dmaWBurstCnts <- replicateM(mkReg(0));
	Vector#(NUM_BUSES, Reg#(Bit#(16))) dmaWBurstPerPageCnts <- replicateM(mkReg(0));
	Vector#(NUM_BUSES, FIFO#(TagT)) dmaReqQs <- replicateM(mkSizedFIFO(valueOf(NumTags)));//TODO make bigger?
	Vector#(NUM_BUSES, FIFO#(Tuple2#(TagT, Bit#(32)))) dmaReq2RespQ <- replicateM(mkSizedFIFO(valueOf(NumTags))); //TODO make bigger?
	Vector#(NUM_BUSES, Reg#(Bit#(32))) dmaWrReqCnts <- replicateM(mkReg(0));
	Vector#(NUM_BUSES, Reg#(TagT)) currTags <- replicateM(mkReg(0));
	FIFO#(Tuple2#(Bit#(WordSz), TagT)) dataFlash2DmaQ <- mkFIFO();
	Vector#(NUM_BUSES, FIFO#(TagT)) dmaReadDoneQs <- replicateM(mkFIFO);

	rule incCycle;
		cycleCnt <= cycleCnt + 1;
	endrule

	rule driveFlashCmd (started);
		let cmd = flashCmdQ.first;
		flashCmdQ.deq;
		tag2busTable[cmd.tag] <= cmd.bus;
		flashCtrl.user.sendCmd(cmd); //forward cmd to flash ctrl
		$display("@%d: Main.bsv: received cmd tag=%d @%x %x %x %x", 
						cycleCnt, cmd.tag, cmd.bus, cmd.chip, cmd.block, cmd.page);
	endrule

	Reg#(Bit#(32)) delayRegSet <- mkReg(0);
	Reg#(Bit#(32)) delayReg <- mkReg(0);
	Reg#(Bit#(32)) debugFlag <- mkReg(0);
	Reg#(Bit#(32)) debugReadCnt <- mkReg(0);
	Reg#(Bit#(32)) debugWriteCnt <- mkReg(0);


	//--------------------------------------------
	// Reads from Flash (DMA Write)
	//--------------------------------------------

	rule doEnqReadFromFlash;
		if (delayReg==0) begin
			let taggedRdata <- flashCtrl.user.readWord();
			debugReadCnt <= debugReadCnt + 1;
			if (debugFlag==0) begin
				dataFlash2DmaQ.enq(taggedRdata);
			end
			delayReg <= delayRegSet;
		end
		else begin
			delayReg <= delayReg - 1;
		end
	endrule


	rule doDistributeReadFromFlash;
		let taggedRdata = dataFlash2DmaQ.first;
		dataFlash2DmaQ.deq;
		let tag = tpl_2(taggedRdata);
		let data = tpl_1(taggedRdata);
		BusT bus = tag2busTable[tag];
		dmaWriteBuf[bus].enq(taggedRdata);
		$display("@%d Main.bsv: rdata tag=%d, bus=%d, data[%d]=%x", cycleCnt, tag, bus, dmaWBurstCnts[bus], data);
	endrule

	for (Integer b=0; b<valueOf(NUM_BUSES); b=b+1) begin
		Reg#(Bit#(16)) padCnt <- mkReg(0);
		rule doReqDMAStart if (padCnt==0);
			dmaWriteBuf[b].deq;
			let taggedRdata = dmaWriteBuf[b].first;
			dmaWriteBufOut[b].enq(taggedRdata);
			let tag = tpl_2(taggedRdata);
			//for each bus, every dmaBurstWords bursts, request for init DMA
			if (dmaWBurstCnts[b]==0) begin
				dmaReqQs[b].enq(tag);
				currTags[b] <= tag;
				dmaWBurstCnts[b] <= dmaWBurstCnts[b] + 1;
				dmaWBurstPerPageCnts[b] <= dmaWBurstPerPageCnts[b] + 1;
			end
			else if (dmaWBurstPerPageCnts[b]==fromInteger(dmaBurstsPerPage) && 
							dmaWBurstCnts[b]==fromInteger(dmaBurstWordsLast-1)) begin
				//last burst
				dmaWBurstCnts[b] <= 0;
				dmaWBurstPerPageCnts[b] <= 0;
				padCnt <= fromInteger(dmaBurstWords - dmaBurstWordsLast);
			end
			else if (dmaWBurstCnts[b]==fromInteger(dmaBurstWords-1)) begin
				if (tag != currTags[b]) begin
					$display("main.bsv: **ERROR: tag bursts do not match!");
				end
				dmaWBurstCnts[b] <= 0;
			end
			else begin
				if (tag != currTags[b]) begin
					$display("main.bsv: **ERROR: tag bursts do not match!");
				end
				dmaWBurstCnts[b] <= dmaWBurstCnts[b] + 1;
			end
		endrule

		rule doDmaPad if (padCnt>0);
			dmaWriteBufOut[b].enq(tuple2(-1,?));
			$display("main.bsv: pad -1 for bus=%d", b);
			padCnt <= padCnt - 1;
		endrule
			
			

		//initiate dma pipeline
		FIFO#(Tuple3#(TagT, Bit#(32), Bit#(32))) dmaWriteReqPipe <- mkFIFO;
		rule initiateDmaWritePipe;
			dmaReqQs[b].deq;
			let tag = dmaReqQs[b].first;
			let base = tpl_1(dmaWriteRefs[tag]);
			let offset = tpl_2(dmaWriteRefs[tag]);
			dmaWriteReqPipe.enq(tuple3(tag, base, offset));
		endrule

		//initiate dma
		rule initiateDmaWrite;
			dmaWriteReqPipe.deq;
			let tag = tpl_1(dmaWriteReqPipe.first);
			let base = tpl_2(dmaWriteReqPipe.first);
			let offset = tpl_3(dmaWriteReqPipe.first);
			Bit#(32) burstOffset = (dmaWrReqCnts[b]<<log2(dmaBurstBytes)) + offset;
			let dmaCmd = MemengineCmd {
								sglId: base, 
								base: zeroExtend(burstOffset),
								len:fromInteger(dmaBurstBytes), 
								burstLen:fromInteger(dmaBurstBytes)
							};
			we.writeServers[b].request.put(dmaCmd);
			dmaReq2RespQ[b].enq(tuple2(tag, dmaWrReqCnts[b]));
			
			$display("@%d Main.bsv: init dma write tag=%d, bus=%d, addr=0x%x 0x%x", 
							cycleCnt, tag, b, base, burstOffset);
			if (dmaWrReqCnts[b] == fromInteger(dmaBurstsPerPage-1)) begin
				dmaWrReqCnts[b] <= 0;
			end
			else begin
				dmaWrReqCnts[b] <= dmaWrReqCnts[b] + 1;
			end
		endrule

		//send data, pad with 0's if necessary

		rule sendDmaWriteData;
			let taggedRdata = dmaWriteBufOut[b].first;
			let data = tpl_1(taggedRdata);
			dmaWriteBufOut[b].deq;
			we.dataPipes[b].enq(data);
		endrule

		//dma response.get done; when enough has accumulated, send ack to sw
		rule dmaWriterGetResponse;
			let dummy <- we.writeServers[b].response.get;
			let tagCnt = dmaReq2RespQ[b].first;
			dmaReq2RespQ[b].deq;
			$display("@%d Main.bsv: dma resp [%d] tag=%d", cycleCnt, tpl_2(tagCnt), tpl_1(tagCnt));
			if (tpl_2(tagCnt)==fromInteger(dmaBurstsPerPage-1)) begin
				//indication.readDone(zeroExtend(tpl_1(tagCnt)));
				dmaReadDoneQs[b].enq(tpl_1(tagCnt));
			end
		endrule

		rule collectReadDone;
			dmaReadDoneQs[b].deq;
			let tag = dmaReadDoneQs[b].first;
			indication.readDone(zeroExtend(tag));
		endrule

	end //for each bus





	//--------------------------------------------
	// Writes to Flash (DMA Reads)
	//--------------------------------------------

	/*
	//Instantiate dma readers (in DMABurstHelper)
	Vector#(NUM_BUSES, DMAReadEngineIfc#(WordSz)) dmaReaders;
	for (Integer b=0; b<valueOf(NUM_BUSES); b=b+1) begin
		DMAReadEngineIfc#(WordSz) reader <- mkDmaReadEngine(re.readServers[b], re.dataPipes[b]);
		dmaReaders[b] = reader; 
	end //For NUM_BUSES
	*/

	FIFO#(Tuple2#(TagT, BusT)) wrToDmaReqQ <- mkFIFO();
	Vector#(NUM_BUSES, FIFO#(TagT)) dmaRdReq2RespQ <- replicateM(mkSizedFIFO(valueOf(NumTags))); //TODO sz
	Vector#(NUM_BUSES, Reg#(Bit#(32))) dmaReadBurstCount <- replicateM(mkReg(0));
	Vector#(NUM_BUSES, FIFO#(TagT)) dmaReadReqQ <- replicateM(mkSizedFIFO(valueOf(NumTags)));
	Vector#(NUM_BUSES, Reg#(Bit#(32))) dmaRdReqCnts <- replicateM(mkReg(0));

	//Handle write data requests from controller
	rule handleWriteDataRequestFromFlash;
		TagT tag <- flashCtrl.user.writeDataReq();
		//check which bus it's from
		let bus = tag2busTable[tag];
		wrToDmaReqQ.enq(tuple2(tag, bus));
	endrule

	rule distrDmaReadReq;
		wrToDmaReqQ.deq;
		let r = wrToDmaReqQ.first;
		let tag = tpl_1(r);
		let bus = tpl_2(r);
		dmaReadReqQ[bus].enq(tag);
		dmaRdReq2RespQ[bus].enq(tag);
		//dmaReaders[bus].startRead(tag, fromInteger(pageWords));
	endrule

	for (Integer b=0; b<valueOf(NUM_BUSES); b=b+1) begin
		rule initDmaRead;
			let tag = dmaReadReqQ[b].first;
			let base = tpl_1(dmaReadRefs[tag]);
			let offset = tpl_2(dmaReadRefs[tag]);
			Bit#(32) burstOffset = (dmaRdReqCnts[b]<<log2(dmaBurstBytes)) + offset;
			let dmaCmd = MemengineCmd {
								sglId: base, 
								base: zeroExtend(burstOffset),
								len:fromInteger(dmaBurstBytes), 
								burstLen:fromInteger(dmaBurstBytes)
							};
			re.readServers[b].request.put(dmaCmd);
			$display("Main.bsv: dma read cmd issued: base=%x, burstOffset=%d", base, burstOffset);

			if (dmaRdReqCnts[b] == fromInteger(dmaBurstsPerPage-1)) begin
				dmaRdReqCnts[b] <= 0;
				dmaReadReqQ[b].deq; //done with this req
			end
			else begin
				dmaRdReqCnts[b] <= dmaRdReqCnts[b] + 1;
			end
		endrule

		rule dmaReaderGetResponse;
			let dummy <- re.readServers[b].response.get;
		endrule

		//forward data
		FIFO#(Tuple2#(Bit#(128), TagT)) writeWordPipe <- mkFIFO();
		rule pipeDmaRdData;
			let d <- toGet(re.dataPipes[b]).get;
			let tag = dmaRdReq2RespQ[b].first;
			if (dmaReadBurstCount[b] < fromInteger(pageWords)) begin
				writeWordPipe.enq(tuple2(d, tag));
				$display("Main.bsv: forwarded dma read data [%d]: tag=%d, data=%x", dmaReadBurstCount[b],
								tag, d);
			end
			else begin 
				//drop the data because it's just 0 padded
				$display("Main.bsv: dropped dma read data[%d]", dmaReadBurstCount[b]);
			end

			if (dmaReadBurstCount[b] == fromInteger(dmaBurstsPerPage*dmaBurstWords-1)) begin
				dmaRdReq2RespQ[b].deq;
				dmaReadBurstCount[b] <= 0;
			end
			else begin
				dmaReadBurstCount[b] <= dmaReadBurstCount[b] + 1;
			end
		endrule

		rule forwardDmaRdData;
			writeWordPipe.deq;
			flashCtrl.user.writeWord(writeWordPipe.first);
			debugWriteCnt <= debugWriteCnt + 1;
		endrule
			
	end //for each bus
	
	//Handle read data/done from each DMA reader port
	/*
	for (Integer b=0; b<valueOf(NUM_BUSES); b=b+1) begin
		rule dmaReadDone;
			let trashTag <- dmaReaders[b].done; //ignore this return tag
		endrule

		rule dmaReadData;
			let r <- dmaReaders[b].read;
			let data = tpl_1(r);
			let tag = tpl_2(r);
			flashCtrl.user.writeWord(tuple2(data, tag));
		endrule
	end
	*/


	//--------------------------------------------
	// Writes/Erase Acks
	//--------------------------------------------

	//Handle acks from controller
	FIFO#(Tuple2#(TagT, StatusT)) ackQ <- mkFIFO;
	rule handleControllerAck;
		let ackStatus <- flashCtrl.user.ackStatus();
		ackQ.enq(ackStatus);
	endrule

	rule indicateControllerAck;
		ackQ.deq;
		TagT tag = tpl_1(ackQ.first);
		StatusT st = tpl_2(ackQ.first);
		case (st)
			WRITE_DONE: indication.writeDone(zeroExtend(tag));
			ERASE_DONE: indication.eraseDone(zeroExtend(tag), 0);
			ERASE_ERROR: indication.eraseDone(zeroExtend(tag), 1);
		endcase
	endrule




	//--------------------------------------------
	// Debug
	//--------------------------------------------

	FIFO#(Bit#(1)) debugReqQ <- mkFIFO();
	rule doDebugDump;
		$display("Main.bsv: debug dump request received");
		debugReqQ.deq;
		let debugCnts = flashCtrl.debug.getDebugCnts(); 
		let gearboxSendCnt = tpl_1(debugCnts);         
		let gearboxRecCnt = tpl_2(debugCnts);   
		let auroraSendCntCC = tpl_3(debugCnts);     
		let auroraRecCntCC = tpl_4(debugCnts);  
		indication.debugDumpResp(gearboxSendCnt, gearboxRecCnt, auroraSendCntCC, auroraRecCntCC, debugReadCnt, debugWriteCnt);
	endrule



	Vector#(1, MemWriteClient#(WordSz)) dmaWriteClientVec;
	Vector#(1, MemReadClient#(WordSz)) dmaReadClientVec;
	dmaWriteClientVec[0] = we.dmaClient;
	dmaReadClientVec[0] = re.dmaClient;
		

   interface FlashRequest request;
		method Action readPage(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
			FlashCmd fcmd = FlashCmd{
				tag: truncate(tag),
				op: READ_PAGE,
				bus: truncate(bus),
				chip: truncate(chip),
				block: truncate(block),
				page: truncate(page)
				};

			flashCmdQ.enq(fcmd);
		endmethod
		
		method Action writePage(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
			FlashCmd fcmd = FlashCmd{
				tag: truncate(tag),
				op: WRITE_PAGE,
				bus: truncate(bus),
				chip: truncate(chip),
				block: truncate(block),
				page: truncate(page)
				};

			flashCmdQ.enq(fcmd);
		endmethod

		method Action eraseBlock(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) tag);
			FlashCmd fcmd = FlashCmd{
				tag: truncate(tag),
				op: ERASE_BLOCK,
				bus: truncate(bus),
				chip: truncate(chip),
				block: truncate(block),
				page: 0
				};
			flashCmdQ.enq(fcmd);
		endmethod

		method Action addDmaReadRefs(Bit#(32) pointer, Bit#(32) offset, Bit#(32) tag);
			//for (Integer b=0; b<valueOf(NUM_BUSES); b=b+1) begin
			//	dmaReaders[b].addBuffer(truncate(tag), offset, pointer);
			//end
			dmaReadRefs[tag] <= tuple2(pointer, offset);
		endmethod

		method Action addDmaWriteRefs(Bit#(32) pointer, Bit#(32) offset, Bit#(32) tag);
			dmaWriteRefs[tag] <= tuple2(pointer, offset);
		endmethod

		method Action start(Bit#(32) dummy);
			started <= True;
		endmethod

		method Action debugDumpReq(Bit#(32) dummy);
			debugReqQ.enq(1);
		endmethod

		method Action setDebugVals (Bit#(32) flag, Bit#(32) debugDelay); 
			delayRegSet <= debugDelay;
			debugFlag <= flag;
		endmethod

	endinterface //FlashRequest

   interface MemWriteClient dmaWriteClient = dmaWriteClientVec;
   interface MemReadClient dmaReadClient = dmaReadClientVec;

   interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;

endmodule

