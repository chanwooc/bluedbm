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

import AFTL::*;
import BRAM_Wrapper::*;
import Top_Pins::*;

//import MainTypes::*;
typedef 8 NUM_FLASH_DMA_PORTS;
typedef 9 NUM_ENG_PORTS;

interface FlashRequest;
	// memory offset
	method Action readPage(Bit#(32) tag, Bit#(32) lpa, Bit#(32) offset);
	method Action writePage(Bit#(32) tag, Bit#(32) lpa, Bit#(32) offset);
	method Action eraseBlock(Bit#(32) tag, Bit#(32) lpa);

	method Action setDmaReadRef(Bit#(32) sgId);
	method Action setDmaWriteRef(Bit#(32) sgId);
	method Action setDmaMapRef(Bit#(32) sgId);
	
	method Action downloadMap(); // FPGA to Host (DMA W)
	method Action uploadMap();   // Host to FPGA (DMA R)

	method Action start(Bit#(32) dummy);
	method Action debugDumpReq(Bit#(32) dummy);
	method Action setDebugVals (Bit#(32) flag, Bit#(32) debugDelay); 
endinterface

interface FlashIndication;
	method Action readDone(Bit#(32) tag, Bit#(32) status);
	method Action writeDone(Bit#(32) tag, Bit#(32) status);
	method Action eraseDone(Bit#(32) tag, Bit#(32) status);

	method Action uploadDone;
	method Action downloadDone;

	method Action debugDumpResp(Bit#(32) debug0, Bit#(32) debug1, Bit#(32) debug2, Bit#(32) debug3, Bit#(32) debug4, Bit#(32) debug5);
endinterface

typedef 128 DmaBurstBytes; 
Integer dmaBurstBytes = valueOf(DmaBurstBytes);
Integer dmaBurstWords = dmaBurstBytes/wordBytes; //128/16 = 8
Integer dmaBurstsPerPage = (pageSizeUser+dmaBurstBytes-1)/dmaBurstBytes; //ceiling, 65
Integer dmaBurstWordsLast = (pageSizeUser%dmaBurstBytes)/wordBytes; //num bursts in last dma; 2 bursts

Integer dmaAllocPageSizeLog = 14; //typically portal alloc page size is 16KB; MUST MATCH SW
Integer dmaLength = dmaBurstsPerPage * dmaBurstBytes; // 65 * 128 = 8320

interface MainIfc;
	interface FlashRequest request;
	interface Vector#(NumWriteClients, MemWriteClient#(DataBusWidth)) dmaWriteClient;
	interface Vector#(NumReadClients, MemReadClient#(DataBusWidth)) dmaReadClient;
	interface Top_Pins pins;
endinterface

module mkMain#(Clock derivedClock, Reset derivedReset, FlashIndication indication)(MainIfc);
	Clock clk200 = derivedClock;
	Reset rst200 = derivedReset;

	Reg#(Bool) started <- mkReg(False);
	Reg#(Bit#(64)) cycleCnt <- mkReg(0);

	FIFO#(FlashCmd) flashCmdQ <- mkSizedFIFO(valueOf(NumTags));
	FIFO#(FTLCmd) ftlCmdQ <- mkSizedFIFO(valueOf(NumTags));

	Vector#(NumTags, Reg#(BusT)) tag2busTable <- replicateM(mkRegU());

	// Offset - pointer
	Vector#(NumTags, Reg#(Bit#(32))) dmaWriteOffset <- replicateM(mkRegU());
	Vector#(NumTags, Reg#(Bit#(32))) dmaReadOffset <- replicateM(mkRegU());

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
	// AFTL & BRAM
	//--------------------------------------------
	BRAM_Wrapper1 bram_ctrl <- mkBRAM_Wrapper1;
	AFTLIfc aFTL <- mkAFTL(bram_ctrl);

	rule driveFTLCmd (started);
		let cmd = ftlCmdQ.first;
		ftlCmdQ.deq;

		aFTL.translate(cmd);
	endrule

	rule driveFTLSuccessResp;
		let cmd <- aFTL.getSuccess; //FlashCmd
		flashCmdQ.enq(cmd);
	endrule

	rule driveFTLFailureResp;
		let cmd <- aFTL.getFailure; //FTLCmd

		case (cmd.op)
			READ_PAGE:  indication.readDone(zeroExtend(cmd.tag), 1);
			WRITE_PAGE: indication.writeDone(zeroExtend(cmd.tag), 1);
			ERASE_BLOCK:indication.eraseDone(zeroExtend(cmd.tag), 1);
		endcase
	endrule


	//--------------------------------------------
	// DMA Module Instantiation
	//--------------------------------------------
	Vector#(NumReadClients, MemReadEngine#(DataBusWidth, DataBusWidth, 14, TDiv#(NUM_ENG_PORTS,NumReadClients))) re <- replicateM(mkMemReadEngine);
	Vector#(NumWriteClients, MemWriteEngine#(DataBusWidth, DataBusWidth,  1, TDiv#(NUM_ENG_PORTS,NumWriteClients))) we <- replicateM(mkMemWriteEngine);

	function MemReadEngineServer#(DataBusWidth) getREServer( Vector#(NumReadClients, MemReadEngine#(DataBusWidth, DataBusWidth, 14, TDiv#(NUM_ENG_PORTS,NumReadClients))) rengine, Integer idx ) ;
		let numEngineServer = valueOf(NumReadClients);
		let idxEngine = idx % numEngineServer;
		let idxServer = idx / numEngineServer;

		return rengine[idxEngine].readServers[idxServer];
		//return rengine[idx].readServers[0];
	endfunction
	
	function MemWriteEngineServer#(DataBusWidth) getWEServer( Vector#(NumWriteClients, MemWriteEngine#(DataBusWidth, DataBusWidth,  1, TDiv#(NUM_ENG_PORTS,NumWriteClients))) wengine, Integer idx ) ;
		let numEngineServer = valueOf(NumWriteClients);
		let idxEngine = idx % numEngineServer;
		let idxServer = idx / numEngineServer;

		return wengine[idxEngine].writeServers[idxServer];
		//return wengine[idx].writeServers[0];
	endfunction

	function Bit#(32) calcDmaPageOffset(TagT tag);
		Bit#(32) off = zeroExtend(tag);
		return (off<< dmaAllocPageSizeLog);
	endfunction


	rule driveFlashCmd; // (started);
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
	Reg#(Bit#(32)) dmaWriteSgid <- mkReg(0);

	FIFO#(Tuple2#(Bit#(WordSz), TagT)) dataFlash2DmaQ <- mkFIFO();
	Vector#(NUM_FLASH_DMA_PORTS, FIFO#(Tuple2#(Bit#(WordSz), TagT))) dmaWriteBuf <- replicateM(mkSizedBRAMFIFO(dmaBurstWords*2));
	Vector#(NUM_FLASH_DMA_PORTS, FIFO#(Tuple2#(Bit#(WordSz), TagT))) dmaWriteBufOut <- replicateM(mkFIFO());

	Vector#(NUM_FLASH_DMA_PORTS, Reg#(Bit#(16))) dmaWBurstCnts <- replicateM(mkReg(0));
	Vector#(NUM_FLASH_DMA_PORTS, Reg#(Bit#(16))) dmaWBurstPerPageCnts <- replicateM(mkReg(0));

	Vector#(NUM_FLASH_DMA_PORTS, FIFO#(TagT)) dmaWrReq2RespQ <- replicateM(mkSizedFIFO(valueOf(NumTags))); //TODO make bigger?
	Vector#(NUM_FLASH_DMA_PORTS, FIFO#(TagT)) dmaWriteReqQ <- replicateM(mkSizedFIFO(valueOf(NumTags)));//TODO make bigger?
	Vector#(NUM_FLASH_DMA_PORTS, FIFO#(TagT)) dmaWriteDoneQs <- replicateM(mkFIFO);

	Vector#(NUM_FLASH_DMA_PORTS, Reg#(TagT)) currTags <- replicateM(mkReg(0));

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
		$display("@%d Main.bsv: rdata tag=%d, bus=%d, data[%d,%d]=%x", cycleCnt, tag, bus,dmaWBurstPerPageCnts[bus], dmaWBurstCnts[bus], data);
	endrule

	for (Integer b=0; b<valueOf(NUM_FLASH_DMA_PORTS); b=b+1) begin
		Reg#(Bit#(16)) padCnt <- mkReg(0);
		rule doReqDMAStart if (padCnt==0);
			dmaWriteBuf[b].deq;
			let taggedRdata = dmaWriteBuf[b].first;
			dmaWriteBufOut[b].enq(taggedRdata);
			let tag = tpl_2(taggedRdata);
			//for each bus, every dmaBurstWords bursts, request for init DMA
			if (dmaWBurstCnts[b]==0) begin
				if(dmaWBurstPerPageCnts[b]==0) dmaWriteReqQ[b].enq(tag);
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
		$display("@%d Main.bs2: rdata tag=%d, bus=%d, data[%d,%d]", cycleCnt, tag, b,dmaWBurstPerPageCnts[b], dmaWBurstCnts[b]);
		endrule

		rule doDmaPad if (padCnt>0);
			dmaWriteBufOut[b].enq(tuple2(-1,?));
			$display("main.bsv: pad -1 for bus=%d", b);
			padCnt <= padCnt - 1;
		endrule
			
			

		//initiate dma pipeline
		FIFO#(Tuple2#(TagT, Bit#(32))) dmaWriteReqPipe <- mkFIFO;
		//FIFO#(TagT) dmaWriteReqPipe <- mkFIFO;
		rule initiateDmaWritePipe;
			dmaWriteReqQ[b].deq;
			let tag = dmaWriteReqQ[b].first;
			let offset = dmaWriteOffset[tag];
			dmaWriteReqPipe.enq(tuple2(tag,offset));
		endrule

		//initiate dma
		rule initiateDmaWrite;
			dmaWriteReqPipe.deq;
			let tag = tpl_1(dmaWriteReqPipe.first);
			let offset = tpl_2(dmaWriteReqPipe.first);

			let dmaCmd = MemengineCmd {
								sglId: dmaWriteSgid, 
								base: zeroExtend(offset),
								len:fromInteger(dmaLength), 
								burstLen:fromInteger(dmaBurstBytes)
							};

			let weS = getWEServer(we,b);
			weS.request.put(dmaCmd);
			dmaWrReq2RespQ[b].enq(tag);
			
			$display("@%d Main.bsv: init dma write tag=%d, bus=%d, base=0x%x, offset=%x",
							cycleCnt, tag, b, dmaWriteSgid, offset);
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
			indication.readDone(zeroExtend(tag), 0);
		endrule
	end //for each bus


	//--------------------------------------------
	// Writes to Flash (DMA Reads)
	//--------------------------------------------
	Reg#(Bit#(32)) dmaReadSgid <- mkReg(0);

	FIFO#(Tuple2#(TagT, BusT)) wrToDmaReqQ <- mkFIFO();
	Vector#(NUM_FLASH_DMA_PORTS, FIFO#(TagT)) dmaRdReq2RespQ <- replicateM(mkSizedFIFO(valueOf(NumTags))); //TODO sz
	Vector#(NUM_FLASH_DMA_PORTS, FIFO#(TagT)) dmaReadReqQ <- replicateM(mkSizedFIFO(valueOf(NumTags)));
	Vector#(NUM_FLASH_DMA_PORTS, Reg#(Bit#(32))) dmaReadBurstCount <- replicateM(mkReg(0));
	//Vector#(NUM_FLASH_DMA_PORTS, Reg#(Bit#(32))) dmaRdReqCnts <- replicateM(mkReg(0));

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

	for (Integer b=0; b<valueOf(NUM_FLASH_DMA_PORTS); b=b+1) begin
		rule initDmaRead;
			let tag = dmaReadReqQ[b].first;
			let offset = dmaReadOffset[tag];
			let dmaCmd = MemengineCmd {
								sglId: dmaReadSgid, 
								base: zeroExtend(offset),
								len:fromInteger(dmaLength), 
								burstLen:fromInteger(dmaBurstBytes)
							};
			//re.readServers[b].request.put(dmaCmd);
			let reS = getREServer(re,b);
			reS.request.put(dmaCmd);

			$display("Main.bsv: dma read cmd issued: tag=%d, base=0x%x, offset=0x%x", tag, dmaReadSgid, offset);
			dmaReadReqQ[b].deq;
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
		rule pipeDmaRdData;
			let d = rdDataPipe.first;
			rdDataPipe.deq;
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
			WRITE_DONE: indication.writeDone(zeroExtend(tag), 0);
			ERASE_DONE: indication.eraseDone(zeroExtend(tag), 0);
			ERASE_ERROR: indication.eraseDone(zeroExtend(tag), 1);
		endcase
	endrule

	//--------------------------------------------
	// AFTL Map & Block Mgr Table Up/Download
	//--------------------------------------------

	Reg#(Bit#(32)) dmaMapSgid <- mkReg(0);
	FIFO#(MapLockMode) mapReq <- mkFIFO;
//	FIFO#(Bool) downloadReq <- mkSizedFIFO(4);
//	FIFO#(Bool) uploadReq <- mkSizedFIFO(4);

	rule issueMapReq (!bram_ctrl.isLocked);
		let d = mapReq.first;
		mapReq.deq;
		bram_ctrl.lockPortB(d);

//		if (d == UPLOAD) uploadReq.enq(True);
//		else downloadReq.enq(True);
	endrule

	// DMA Read (Host->FPGA, Upload)
	FIFOF#(Bool) ftlReadReq2Resp <- mkFIFOF;
	FIFOF#(Bool) ftlReadResp <- mkFIFOF;

	rule initFTLRead (bram_ctrl.lockMode == UPLOAD && !ftlReadReq2Resp.notEmpty && !ftlReadResp.notEmpty);
	// from Host to FPGA (Upload)
		let dmaCmd = MemengineCmd {
							sglId: dmaMapSgid, 
							base: 0,
							len: 1024*1024, // 1MB 
							burstLen: 128
						};

		let reS = getREServer(re, 8);
		reS.request.put(dmaCmd);

		$display("[AFTLBRAMTest.bsv] init dma read cmd issued");

//		uploadReq.deq;
		ftlReadReq2Resp.enq(True);
	endrule

	// Total 1MB
	// Each burst beat 64bit = 8Byte 
	// --> total 128*1024 = 2^17 beats
	Integer dmaMapBeats = 128*1024;
	Reg#(Bit#(20)) ftlReadBeatCnt <- mkReg(0);

	rule incCycle;
		cycleCnt <= cycleCnt + 1;
	endrule

	rule pipeFTLRdData (bram_ctrl.lockMode == UPLOAD && ftlReadReq2Resp.notEmpty && !ftlReadResp.notEmpty );
		let reS = getREServer(re, 8);
		let d <- toGet(reS.data).get; //Each beat is 64 bit = 8 Byte wide
		$display("[tick%d] dmaGet %d", cycleCnt, ftlReadBeatCnt);

		// BRAM: 64 Byte-word addressing (14 bit address -> 64 Byte-word)
		// 8 Beats per each address
		// ftlReadBeatCnt >> 3     : 14bit address
		// ftlReadBeatCnt[2:0] << 6: Data-shift unit = 64 bit = 2^6 bit
		// ftlReadBeatCnt[2:0] << 3: Mask-shift unit = 8 Byte = 2^3 Byte
		bram_ctrl.writeB( truncate  ( ftlReadBeatCnt >> 3 ),
						  zeroExtend( d.data ) << {ftlReadBeatCnt[2:0], 6'b0} ,
						  zeroExtend( 64'b11111111 << { ftlReadBeatCnt[2:0], 3'b0}) );

		if (ftlReadBeatCnt == fromInteger(dmaMapBeats - 1)) begin
			ftlReadBeatCnt <= 0;
			ftlReadReq2Resp.deq;
			ftlReadResp.enq(True);
		end else begin
			ftlReadBeatCnt <= ftlReadBeatCnt+1;
		end
	endrule

	rule ftlRdDone (bram_ctrl.lockMode == UPLOAD && !ftlReadReq2Resp.notEmpty && ftlReadResp.notEmpty); // Upload done
		ftlReadResp.deq;
		indication.uploadDone;
		bram_ctrl.unlockPortB;
	endrule

	// DMA Write
	FIFOF#(Bool) mapBramReq <- mkFIFOF;//mkSizedFIFOF(10);
	FIFOF#(Bool) ftlWriteReq2Resp <- mkFIFOF;//mkSizedFIFOF(10);

	// Total 1MB, each word: 512bit=64Byte -> total 14bit address
	// Total 1MB, Each burst beat 64bit = 8Byte -> total 128*1024 beats
	Integer mapDownloadReqs = 16*1024; // 2^14
	Reg#(Bit#(20)) mapDownloadReqCnt <- mkReg(0);
	Reg#(Bit#(20)) dmaWriteBeatCnt <- mkReg(0);

	rule initDownload (bram_ctrl.lockMode == DOWNLOAD && !mapBramReq.notEmpty && !ftlWriteReq2Resp.notEmpty);
//		downloadReq.deq;
		mapBramReq.enq(True);
		ftlWriteReq2Resp.enq(True);

		let dmaCmd = MemengineCmd {
							sglId: dmaMapSgid, 
							base: 0,
							len: 1024*1024, // 1MB 
							burstLen: 128
						};

		let weS = getWEServer(we, 8);
		weS.request.put(dmaCmd);

		$display("[AFTLBRAMTest.bsv] init dma write cmd issued");
	endrule

	rule reqMapData (bram_ctrl.lockMode == DOWNLOAD && mapBramReq.notEmpty);
		$display("[AFTLBRAMTest.bsv] %dth req", mapDownloadReqCnt);
		bram_ctrl.readReqB( truncate( mapDownloadReqCnt ) );

		if (mapDownloadReqCnt == fromInteger(mapDownloadReqs - 1)) begin
			mapDownloadReqCnt <= 0;
			mapBramReq.deq;
		end else begin
			mapDownloadReqCnt <= mapDownloadReqCnt+1;
		end
	endrule

	FIFO#(Bit#(512)) dmaWrDataBuf <- mkFIFO;

	rule pipeFTLWrData1 (bram_ctrl.lockMode == DOWNLOAD && ftlWriteReq2Resp.notEmpty);
		let d <- bram_ctrl.readB;
		dmaWrDataBuf.enq(d);
	endrule

	Reg#(Bit#(3)) ftlWrPhase <- mkReg(0);

	rule pipeFTLWrData2 (bram_ctrl.lockMode == DOWNLOAD && ftlWriteReq2Resp.notEmpty);
		let buffered_data = dmaWrDataBuf.first; // 512bit

		Bit#(DataBusWidth) data = truncate( buffered_data >> { ftlWrPhase, 6'b0 } );

		let weS = getWEServer(we, 8);
		weS.data.enq(data);

		if (ftlWrPhase == 7) begin
			dmaWrDataBuf.deq;
		end

		ftlWrPhase <= ftlWrPhase+1;
	endrule


	rule ftlWrDone (bram_ctrl.lockMode == DOWNLOAD && ftlWriteReq2Resp.notEmpty);
		let weS = getWEServer(we, 8);
		let dummy <- weS.done.get;
		ftlWriteReq2Resp.deq;

		indication.downloadDone;
		bram_ctrl.unlockPortB;
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
	
	Vector#(NumWriteClients, MemWriteClient#(DataBusWidth)) dmaWriteClientVec; // = vec(we.dmaClient); 
	Vector#(NumReadClients, MemReadClient#(DataBusWidth)) dmaReadClientVec;

	for (Integer tt = 0; tt < valueOf(NumReadClients); tt=tt+1) begin
		dmaReadClientVec[tt] = re[tt].dmaClient;
	end

	for (Integer tt = 0; tt < valueOf(NumWriteClients); tt=tt+1) begin
		dmaWriteClientVec[tt] = we[tt].dmaClient;
	end

	interface FlashRequest request;
		method Action readPage(Bit#(32) tag, Bit#(32) lpa, Bit#(32) offset);
			FTLCmd fcmd = FTLCmd {
				tag: truncate(tag),
				op:  READ_PAGE,
				lpa: lpa
			};

			ftlCmdQ.enq(fcmd);
			dmaWriteOffset[tag] <= offset;
		endmethod

		method Action writePage(Bit#(32) tag, Bit#(32) lpa, Bit#(32) offset);
			FTLCmd fcmd = FTLCmd {
				tag: truncate(tag),
				op:  WRITE_PAGE,
				lpa: lpa
			};

			ftlCmdQ.enq(fcmd);
			dmaReadOffset[tag] <= offset;
		endmethod

		method Action eraseBlock(Bit#(32) tag, Bit#(32) lpa);
			FTLCmd fcmd = FTLCmd {
				tag: truncate(tag),
				op:  ERASE_BLOCK,
				lpa: lpa
			};

			ftlCmdQ.enq(fcmd);
		endmethod

		method Action setDmaReadRef(Bit#(32) sgId);
			dmaReadSgid <= sgId;
		endmethod

		method Action setDmaWriteRef(Bit#(32) sgId);
			dmaWriteSgid <= sgId;
		endmethod

		method Action setDmaMapRef(Bit#(32) sgId);
			dmaMapSgid <= sgId;
		endmethod

		method Action downloadMap(); // Read Map&Mgr from FPGA to Host (DMA Write)
			mapReq.enq(DOWNLOAD);
		endmethod

		method Action uploadMap(); // Upload Map&Mgr from host to FPGA (DMA Read)
			mapReq.enq(UPLOAD);
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

	interface dmaWriteClient = dmaWriteClientVec;
	interface dmaReadClient = dmaReadClientVec;

	interface Top_Pins pins;
		interface aurora_fmc1 = flashCtrl.aurora;
		interface aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;
	endinterface
endmodule
