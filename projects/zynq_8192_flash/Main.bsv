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
import ConnectalConfig::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import Pipe::*;
`include "ConnectalProjectConfig.bsv"

import Clocks :: *;
import Xilinx       :: *;
`ifndef BSIM
import XilinxCells ::*;
`endif

import AuroraCommon::*;
import AuroraImportZynq::*;

//import AuroraExtArbiter::*;
//import AuroraExtImport::*;
//import AuroraExtImport117::*;

import ControllerTypes::*;
import FlashCtrlZynq::*;
import FlashCtrlModel::*;

import Top_Pins::*;

//import MainTypes::*;
typedef 8 NUM_ENG_PORTS;

interface FlashRequest;
	method Action readPage(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
	method Action writePage(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
	method Action eraseBlock(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) tag);
	//method Action addDmaReadRefs(Bit#(32) pointer, Bit#(32) offset, Bit#(32) tag);
	//method Action addDmaWriteRefs(Bit#(32) pointer, Bit#(32) offset, Bit#(32) tag);

	method Action setDmaReadRef(Bit#(32) sgId);
	method Action setDmaWriteRef(Bit#(32) sgId);

	method Action start(Bit#(32) dummy);
	method Action debugDumpReq(Bit#(32) dummy);
	method Action debugDumpReq2(Bit#(32) dummy);
	method Action setDebugVals (Bit#(32) flag, Bit#(32) debugDelay); 
endinterface

interface FlashIndication;
	method Action readDone(Bit#(32) tag);
	method Action writeDone(Bit#(32) tag);
	method Action eraseDone(Bit#(32) tag, Bit#(32) status);
	method Action debugDumpResp(Bit#(32) debug0, Bit#(32) debug1, Bit#(32) debug2, Bit#(32) debug3, Bit#(32) debug4, Bit#(32) debug5);
	method Action debugDumpResp2(Bit#(32) debug0, Bit#(32) debug1, Bit#(32) debug2);
endinterface

typedef 128 DmaBurstBytes; 
Integer pageSize8192 = 8192;

Integer dmaBurstBytes = valueOf(DmaBurstBytes);
Integer dmaBurstWords = dmaBurstBytes/wordBytes; //128/16 = 8
Integer dmaBurstsPerPage = (pageSizeUser+dmaBurstBytes-1)/dmaBurstBytes; //ceiling, 65
Integer dmaBurstWordsLast = (pageSizeUser%dmaBurstBytes)/wordBytes; //num bursts in last dma; 2 bursts

// SW uses only 8192 bytes
Integer wordsPerFlashPage = pageSizeUser/wordBytes; // 8224/16 = 514
Integer wordsPer8192Page  = pageSize8192/wordBytes; // 8192/16 = 512
Integer realBurstsPerPage = pageSize8192/dmaBurstBytes; // 64

//Integer dmaAllocPageSizeLog = 14; //typically portal alloc page size is 16KB; MUST MATCH SW
Integer dmaAllocPageSizeLog = 13; //typically portal alloc page size is 8KB; MUST MATCH SW
Integer dmaLength = realBurstsPerPage * dmaBurstBytes; // 64 * 128 = 8192

interface MainIfc;
	interface FlashRequest request;
	interface Vector#(NumWriteClients, MemWriteClient#(DataBusWidth)) dmaWriteClient;
	interface Vector#(NumReadClients, MemReadClient#(DataBusWidth)) dmaReadClient;
	interface Top_Pins pins;
//	interface Aurora_Pins#(4) aurora_fmc1;
//	interface Aurora_Clock_Pins aurora_clk_fmc1;
endinterface

module mkMain#(Clock clk200, Reset rst200, FlashIndication indication)(MainIfc);
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	Reg#(Bool) started <- mkReg(False);
	Reg#(Bit#(64)) cycleCnt <- mkReg(0);

	FIFOF#(FlashCmd) flashCmdQ <- mkSizedFIFOF(valueOf(NumTags));
	Vector#(NumTags, Reg#(BusT)) tag2busTable <- replicateM(mkRegU());
	//Vector#(NumTags, Reg#(Tuple2#(Bit#(32),Bit#(32)))) dmaWriteRefs <- replicateM(mkRegU());
	//Vector#(NumTags, Reg#(Tuple2#(Bit#(32),Bit#(32)))) dmaReadRefs <- replicateM(mkRegU());

	//--------------------------------------------
	// Flash Controller
	//--------------------------------------------
	GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
	`ifdef BSIM
		FlashCtrlZynqIfc flashCtrl <- mkFlashCtrlModel(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk200);
	`else
		FlashCtrlZynqIfc flashCtrl <- mkFlashCtrlZynq(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk200);
	`endif

	//--------------------------------------------
	// DMA Module Instantiation
	//--------------------------------------------
	Vector#(NumReadClients, MemReadEngine#(DataBusWidth, DataBusWidth, 14, TDiv#(NUM_ENG_PORTS,NumReadClients))) re <- replicateM(mkMemReadEngine);
	Vector#(NumWriteClients, MemWriteEngine#(DataBusWidth, DataBusWidth,  1, TDiv#(NUM_ENG_PORTS,NumWriteClients))) we <- replicateM(mkMemWriteEngine);

	function MemReadEngineServer#(DataBusWidth) getREServer( Vector#(NumReadClients, MemReadEngine#(DataBusWidth, DataBusWidth, 14, TDiv#(NUM_ENG_PORTS,NumReadClients))) rengine, Integer idx ) ;
		let numEngine = valueOf(NumReadClients);
		let idxEngine = idx % numEngine;
		let idxServer = idx / numEngine;

		return rengine[idxEngine].readServers[idxServer];
	endfunction
	
	function MemWriteEngineServer#(DataBusWidth) getWEServer( Vector#(NumWriteClients, MemWriteEngine#(DataBusWidth, DataBusWidth,  1, TDiv#(NUM_ENG_PORTS,NumWriteClients))) wengine, Integer idx ) ;
		let numEngine = valueOf(NumWriteClients);
		let idxEngine = idx % numEngine;
		let idxServer = idx / numEngine;

		return wengine[idxEngine].writeServers[idxServer];
	endfunction

	function Bit#(32) calcDmaPageOffset(TagT tag);
		Bit#(32) off = zeroExtend(tag);
		return (off<< dmaAllocPageSizeLog);
	endfunction

	rule incCycle;
		cycleCnt <= cycleCnt + 1;
	endrule

	Reg#(Bit#(32)) debugReadReqCnt <- mkReg(0);
	Reg#(Bit#(32)) debugReadDoneCnt <- mkReg(0);

	rule driveFlashCmd (started);
		let cmd = flashCmdQ.first;
		flashCmdQ.deq;
		tag2busTable[cmd.tag] <= cmd.bus;
		if(cmd.op == READ_PAGE) debugReadReqCnt <= debugReadReqCnt + 1;
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
	Reg#(Bit#(32)) dmaWriteSgid <- mkReg(0);

	FIFO#(Tuple2#(Bit#(WordSz), TagT)) dataFlash2DmaQ <- mkFIFO();
	Vector#(NUM_ENG_PORTS, FIFO#(Tuple2#(Bit#(WordSz), TagT))) dmaWriteBuf <- replicateM(mkSizedFIFO(dmaBurstWords*2)); // mkSizedBRAMFIFO
	Vector#(NUM_ENG_PORTS, FIFO#(Tuple2#(Bit#(WordSz), TagT))) dmaWriteBufOut <- replicateM(mkFIFO());

	//Vector#(NUM_ENG_PORTS, Reg#(Bit#(16))) dmaWBurstCnts <- replicateM(mkReg(0));
	//Vector#(NUM_ENG_PORTS, Reg#(Bit#(16))) dmaWBurstPerPageCnts <- replicateM(mkReg(0));
	Vector#(NUM_ENG_PORTS, Reg#(Bit#(16))) wordPerPageCnts <- replicateM(mkReg(0));

	Vector#(NUM_ENG_PORTS, FIFOF#(TagT)) dmaWrReq2RespQ <- replicateM(mkSizedFIFOF(valueOf(NumTags))); //TODO make bigger?
	Vector#(NUM_ENG_PORTS, FIFO#(TagT)) dmaWriteReqQ <- replicateM(mkSizedFIFO(valueOf(NumTags)));//TODO make bigger?
	Vector#(NUM_ENG_PORTS, FIFO#(TagT)) dmaWriteDoneQs <- replicateM(mkFIFO);

//	Vector#(NUM_ENG_PORTS, Reg#(Bit#(32))) dmaWrReqCnts <- replicateM(mkReg(0));

	Vector#(NUM_ENG_PORTS, Reg#(TagT)) currTags <- replicateM(mkReg(0));

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
		//$display("@%d Main.bsv: rdata tag=%d, bus=%d, data[%d,%d]=%x", cycleCnt, tag, bus,dmaWBurstPerPageCnts[bus], dmaWBurstCnts[bus], data);
	endrule

	for (Integer b=0; b<valueOf(NUM_ENG_PORTS); b=b+1) begin
		rule doReqDMAStart;
			dmaWriteBuf[b].deq;
			let taggedRdata = dmaWriteBuf[b].first;
			let tag = tpl_2(taggedRdata);

			if(wordPerPageCnts[b]==0) begin
				dmaWriteReqQ[b].enq(tag);
			end

			if(wordPerPageCnts[b] < fromInteger(wordsPer8192Page)) begin // < 512
				dmaWriteBufOut[b].enq(taggedRdata);
			end

			if(wordPerPageCnts[b] == fromInteger(wordsPerFlashPage-1)) begin
				wordPerPageCnts[b] <= 0;
			end
			else begin
				wordPerPageCnts[b] <= wordPerPageCnts[b] + 1;
			end
		endrule

		//initiate dma pipeline
		//FIFO#(Tuple3#(TagT, Bit#(32), Bit#(32))) dmaWriteReqPipe <- mkFIFO;
		FIFO#(TagT) dmaWriteReqPipe <- mkFIFO;
		rule initiateDmaWritePipe;
			dmaWriteReqQ[b].deq;
			let tag = dmaWriteReqQ[b].first;
			//let base = tpl_1(dmaWriteRefs[tag]);
			//let offset = tpl_2(dmaWriteRefs[tag]);
			//dmaWriteReqPipe.enq(tuple3(tag, base, offset));
			dmaWriteReqPipe.enq(tag);
		endrule

		//initiate dma
		rule initiateDmaWrite;
			dmaWriteReqPipe.deq;
			//let tag = tpl_1(dmaWriteReqPipe.first);
			//let base = tpl_2(dmaWriteReqPipe.first);
			//let offset = tpl_3(dmaWriteReqPipe.first);
			//Bit#(32) burstOffset = offset;//(dmaWrReqCnts[b]<<log2(dmaBurstBytes)) + offset;
			let tag = dmaWriteReqPipe.first;
			let pageOffset = calcDmaPageOffset(tag);
			let dmaCmd = MemengineCmd {
								sglId: dmaWriteSgid, 
								base: zeroExtend(pageOffset),
								len:fromInteger(dmaLength), 
								burstLen:fromInteger(dmaBurstBytes)
							};
			let weS = getWEServer(we,b);
			weS.request.put(dmaCmd);
			dmaWrReq2RespQ[b].enq(tag);
			
			$display("@%d Main.bsv: init dma write tag=%d, bus=%d, base=0x%x, offset=%x",
							cycleCnt, tag, b, dmaWriteSgid, pageOffset);
			//if (dmaWrReqCnts[b] == fromInteger(dmaBurstsPerPage-1)) begin
			//	dmaWrReqCnts[b] <= 0;
			//end
			//else begin
			//	dmaWrReqCnts[b] <= dmaWrReqCnts[b] + 1;
			//end
		endrule

		//send data, pad with 0's if necessary
		Reg#(Bit#(1)) phase <- mkReg(0);
		rule sendDmaWriteData;
			let taggedRdata = dmaWriteBufOut[b].first;
			Bit#(DataBusWidth) data = (phase==0) ? truncateLSB(tpl_1(taggedRdata)) : truncate(tpl_1(taggedRdata));
			
			if (phase==1) begin
				dmaWriteBufOut[b].deq;
			end
			phase <= phase + 1;

			let weS = getWEServer(we,b);
			weS.data.enq(data);
		endrule

		//dma response.get done; when enough has accumulated, send ack to sw
		rule dmaWriterGetResponse;
			let weS = getWEServer(we,b);
			let dummy <- weS.done.get;
			let tagCnt = dmaWrReq2RespQ[b].first;
			dmaWrReq2RespQ[b].deq;
			$display("@%d Main.bsv: dma resp tag=%d", cycleCnt, (tagCnt));
			dmaWriteDoneQs[b].enq(tagCnt);
		endrule

		rule collectReadDone;
			dmaWriteDoneQs[b].deq;
			let tag = dmaWriteDoneQs[b].first;
			indication.readDone(zeroExtend(tag));
			debugReadDoneCnt <= debugReadDoneCnt + 1;
		endrule

	end //for each bus



	//--------------------------------------------
	// Writes to Flash (DMA Reads)
	//--------------------------------------------
	Reg#(Bit#(32)) dmaReadSgid <- mkReg(0);

	FIFO#(Tuple2#(TagT, BusT)) wrToDmaReqQ <- mkFIFO();
	Vector#(NUM_ENG_PORTS, FIFO#(TagT)) dmaRdReq2RespQ <- replicateM(mkSizedFIFO(valueOf(NumTags))); //TODO sz
	Vector#(NUM_ENG_PORTS, FIFO#(TagT)) dmaReadReqQ <- replicateM(mkSizedFIFO(valueOf(NumTags)));
	Vector#(NUM_ENG_PORTS, Reg#(Bit#(32))) dmaReadBurstCount <- replicateM(mkReg(0));
	//Vector#(NUM_ENG_PORTS, Reg#(Bit#(32))) dmaRdReqCnts <- replicateM(mkReg(0));

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

	for (Integer b=0; b<valueOf(NUM_ENG_PORTS); b=b+1) begin
		rule initDmaRead;
			//let tag = dmaReadReqQ[b].first;
			//let base = tpl_1(dmaReadRefs[tag]);
			//let offset = tpl_2(dmaReadRefs[tag]);
			//Bit#(32) burstOffset = offset;
			let tag = dmaReadReqQ[b].first;
			let pageOffset = calcDmaPageOffset(tag);
			let dmaCmd = MemengineCmd {
								sglId: dmaReadSgid, 
								base: zeroExtend(pageOffset),
								len:fromInteger(dmaLength), 
								burstLen:fromInteger(dmaBurstBytes)
							};
			//re.readServers[b].request.put(dmaCmd);
			let reS = getREServer(re,b);
			reS.request.put(dmaCmd);

			//$display("Main.bsv: dma read cmd issued: tag=%d, base=0x%x, offset=0x%x", tag, dmaReadSgid, pageOffset);
			dmaReadReqQ[b].deq;
			//if (dmaRdReqCnts[b] == fromInteger(dmaBurstsPerPage-1)) begin
			//	dmaRdReqCnts[b] <= 0;
			//	dmaReadReqQ[b].deq; //done with this req
			//end
			//else begin
			//	dmaRdReqCnts[b] <= dmaRdReqCnts[b] + 1;
			//end
		endrule

		//forward data: 64->128 (Zynq)
		Reg#(Bit#(1)) phaseDmaR <- mkReg(0);
		Reg#(Bit#(WordSz)) dataTmp <- mkReg(0);
		FIFO#(Bit#(WordSz)) rdDataPipe <- mkFIFO;
		rule aggrDmaRdData;
			let reS = getREServer(re,b);
			let d <- toGet(reS.data).get;
			phaseDmaR <= phaseDmaR+1;
			if(phaseDmaR==0) begin
				dataTmp <= zeroExtend(d.data);
			end
			else begin
				Bit#(WordSz) dataAggr = (dataTmp<<valueOf(DataBusWidth)) | zeroExtend(d.data);
				rdDataPipe.enq(dataAggr);
			end
		endrule

		FIFO#(Tuple2#(Bit#(128), TagT)) writeWordPipe <- mkFIFO();
		Reg#(Bit#(16)) padCntR <- mkReg(0);
		Reg#(TagT) padTagR <- mkReg(0);
		rule pipeDmaRdData ( padCntR == 0 );
			let d = rdDataPipe.first;
			rdDataPipe.deq;
			let tag = dmaRdReq2RespQ[b].first;

			writeWordPipe.enq(tuple2(d,tag));

			if (dmaReadBurstCount[b] == fromInteger(wordsPer8192Page-1)) begin
				dmaRdReq2RespQ[b].deq;
				dmaReadBurstCount[b] <= 0;

				padCntR <= fromInteger(wordsPerFlashPage - wordsPer8192Page);
				padTagR <= tag;
			end
			else begin
				dmaReadBurstCount[b] <= dmaReadBurstCount[b] + 1;
			end
		endrule

		rule doPaddingFlash (padCntR > 0);
			writeWordPipe.enq(tuple2(0,padTagR)); // pad 0 to spare
			padCntR <= padCntR-1;
		endrule

		rule forwardDmaRdData;
			writeWordPipe.deq;
			flashCtrl.user.writeWord(writeWordPipe.first);
			debugWriteCnt <= debugWriteCnt + 1;
		endrule
	end //for each eng_port
	


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
	FIFO#(Bit#(1)) debugReqQ2 <- mkFIFO();
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

	rule doDebugDump2;
		$display("Main.bsv: debug dump request received");
		debugReqQ2.deq;
		Bit#(16) value = {
			4'hF,
			3'b0,
			flashCmdQ.notEmpty?1'b1:1'b0,
			dmaWrReq2RespQ[7].notEmpty?1'b1:1'b0,
			dmaWrReq2RespQ[6].notEmpty?1'b1:1'b0,
			dmaWrReq2RespQ[5].notEmpty?1'b1:1'b0,
			dmaWrReq2RespQ[4].notEmpty?1'b1:1'b0,
			dmaWrReq2RespQ[3].notEmpty?1'b1:1'b0,
			dmaWrReq2RespQ[2].notEmpty?1'b1:1'b0,
			dmaWrReq2RespQ[1].notEmpty?1'b1:1'b0,
			dmaWrReq2RespQ[0].notEmpty?1'b1:1'b0
		};

		indication.debugDumpResp2(debugReadReqCnt, debugReadDoneCnt, zeroExtend(value));
	endrule
	
	Vector#(NumWriteClients, MemWriteClient#(DataBusWidth)) dmaWriteClientVec; // = vec(we.dmaClient); 
	Vector#(NumReadClients, MemReadClient#(DataBusWidth)) dmaReadClientVec;

	for (Integer tt = 0; tt < valueOf(NumReadClients); tt=tt+1) begin
		dmaReadClientVec[tt] = re[tt].dmaClient;
	end

	for (Integer tt = 0; tt < valueOf(NumWriteClients); tt=tt+1) begin
		dmaWriteClientVec[tt] = we[tt].dmaClient;
	end

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

//		method Action addDmaReadRefs(Bit#(32) pointer, Bit#(32) offset, Bit#(32) tag);
//			dmaReadRefs[tag] <= tuple2(pointer, offset);
//		endmethod
//
//		method Action addDmaWriteRefs(Bit#(32) pointer, Bit#(32) offset, Bit#(32) tag);
//			dmaWriteRefs[tag] <= tuple2(pointer, offset);
//		endmethod

		method Action setDmaReadRef(Bit#(32) sgId);
			dmaReadSgid <= sgId;
		endmethod

		method Action setDmaWriteRef(Bit#(32) sgId);
			dmaWriteSgid <= sgId;
		endmethod

		method Action start(Bit#(32) dummy);
			started <= True;
		endmethod

		method Action debugDumpReq(Bit#(32) dummy);
			debugReqQ.enq(1);
		endmethod

		method Action debugDumpReq2(Bit#(32) dummy);
			debugReqQ2.enq(1);
		endmethod


		method Action setDebugVals (Bit#(32) flag, Bit#(32) debugDelay); 
			delayRegSet <= debugDelay;
			debugFlag <= flag;
		endmethod

	endinterface //FlashRequest

	interface dmaWriteClient = dmaWriteClientVec;
	interface dmaReadClient = dmaReadClientVec;

	interface Top_Pins pins;
		interface aurora_fmc1 = flashCtrl.aurora;
		interface aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;
	endinterface
endmodule
