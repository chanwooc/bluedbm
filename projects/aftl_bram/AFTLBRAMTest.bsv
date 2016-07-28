import FIFO::*;
import FIFOF::*;
import Vector::*;
import Leds::*;

// DDR3 support
//import DDR3Sim::*;
//import DDR3Controller::*;
//import DDR3Common::*;
//import DRAMController::*;
import BRAM::*;
import Connectable::*;
import DefaultValue::*;

// for DMA
import ConnectalMemory::*;
import ConnectalConfig::*;
import MemTypes::*;
import MemReadEngine::*;
import MemWriteEngine::*;
import Pipe::*;

import ControllerTypes::*;

import HostInterface::*;
import Clocks::*;
import ConnectalClocks::*;


import AFTL::*;
import BRAM_Wrapper::*;

interface AFTLBRAMTestRequest;
	method Action translate(Bit#(32) op, Bit#(32) lpa);
	method Action setDmaRef(Bit#(32) map);//, Bit#(32) mgr);
	method Action downloadMap(); // Read Map&Mgr from FPGA to Host (DMA Write)
	method Action uploadMap(); // Upload Map&Mgr from host to FPGA (DMA Read)
//	method Action loadMap(Bit#(32) sgId);
endinterface

interface AFTLBRAMTestIndication;
	method Action uploadDone;    // Host -> FPGA (Map update)
	method Action downloadDone;  // FPGA -> Host (Map download from FPGA)
	method Action translateSuccess(Bit#(32) op, Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) cnt);
	method Action translateFailure(Bit#(32) op, Bit#(32) cnt);
endinterface

interface AFTLBRAMTestPins;
//	`ifndef BSIM
//	interface LEDS leds;
//	interface DDR3_Pins_ZC706 pins_ddr3;
//	(* prefix="", always_ready, always_enabled *)
//	method Action assert_reset((* port="SW" *)Bit#(1) sw);
//	`endif
endinterface

interface AFTLBRAMTest;
	interface AFTLBRAMTestRequest request;
	interface AFTLBRAMTestPins pins;
	interface Vector#(NumWriteClients, MemWriteClient#(DataBusWidth)) dmaWriteClient;
	interface Vector#(NumReadClients, MemReadClient#(DataBusWidth)) dmaReadClient;
endinterface


module mkAFTLBRAMTest#(HostInterface host, AFTLBRAMTestIndication indication)(AFTLBRAMTest);
	///////////////////////////
	/// BRAM instantiation
	///////////////////////////
	BRAM_Wrapper1 bram_ctrl <- mkBRAM_Wrapper1;

	Reg#(Bit#(32)) counter <- mkReg(0);

	FIFO#(Bit#(32)) lastReqCnt <- mkFIFO;
	FIFO#(MapLockMode) mapReq <- mkFIFO;
	FIFO#(Bool) downloadReq <- mkSizedFIFO(4);
	FIFO#(Bool) uploadReq <- mkSizedFIFO(4);


	rule issueMapReq;
		let d = mapReq.first;
		mapReq.deq;
		bram_ctrl.lockPortB(d);

		if (d == UPLOAD) uploadReq.enq(True);
		else downloadReq.enq(True);
	endrule


	//-------------
	// DMA
	//-------------
	Vector#(NumReadClients, MemReadEngine#(DataBusWidth, DataBusWidth, 14, 1)) re <- replicateM(mkMemReadEngine);
	Vector#(NumWriteClients, MemWriteEngine#(DataBusWidth, DataBusWidth,  1, 1)) we <- replicateM(mkMemWriteEngine);

	Reg#(Bit#(32)) dmaMapRef <- mkReg(0);

	function MemReadEngineServer#(DataBusWidth) getREServer( Vector#(NumReadClients, MemReadEngine#(DataBusWidth, DataBusWidth, 14, 1)) rengine, Integer idx ) ;
		return rengine[idx].readServers[0];
	endfunction

	function MemWriteEngineServer#(DataBusWidth) getWEServer( Vector#(NumWriteClients, MemWriteEngine#(DataBusWidth, DataBusWidth, 1, 1)) wengine, Integer idx ) ;
		return wengine[idx].writeServers[0];
	endfunction

	// DMA Read
	FIFOF#(Bool) dmaReadReq2Resp <- mkSizedFIFOF(10);
	FIFO#(Bool)  dmaReadResp <- mkFIFO;

	rule initDmaRead; // from Host to FPGA (Upload)
		let dmaCmd = MemengineCmd {
							sglId: dmaMapRef, 
							base: 0,
							len: 1024*1024, // 1MB 
							burstLen: 128
						};

		let reS = getREServer(re, 0);
		reS.request.put(dmaCmd);

		$display("[AFTLBRAMTest.bsv] init dma read cmd issued");

		uploadReq.deq;
		dmaReadReq2Resp.enq(True);
	endrule

	// Total 1MB
	// Each burst beat 64bit = 8Byte 
	// --> total 128*1024 = 2^17 beats
	Integer dmaMapBeats = 128*1024;
	Reg#(Bit#(20)) dmaReadBeatCnt <- mkReg(0);

	rule pipeDmaRdData if (dmaReadReq2Resp.notEmpty);
		let reS = getREServer(re, 0);
		let d <- toGet(reS.data).get; //Each beat is 64 bit = 8 Byte wide

		// BRAM: 64 Byte-word addressing (14 bit address -> 64 Byte-word)
		// 8 Beats per each address
		// dmaReadBeatCnt >> 3     : 14bit address
		// dmaReadBeatCnt[2:0] << 6: Data-shift unit = 64 bit = 2^6 bit
		// dmaReadBeatCnt[2:0] << 3: Mask-shift unit = 8 Byte = 2^3 Byte

		bram_ctrl.writeB( truncate  ( dmaReadBeatCnt >> 3 ),
						  zeroExtend( d.data ) << {dmaReadBeatCnt[2:0], 6'b0} ,
						  zeroExtend( 64'b11111111 << { dmaReadBeatCnt[2:0], 3'b0}) );

		if (dmaReadBeatCnt == fromInteger(dmaMapBeats - 1)) begin
			dmaReadBeatCnt <= 0;
			dmaReadReq2Resp.deq;
			dmaReadResp.enq(True);
		end else begin
			dmaReadBeatCnt <= dmaReadBeatCnt+1;
		end
	endrule

	rule dmaRdDone; // Upload done
		dmaReadResp.deq;
		indication.uploadDone;
		bram_ctrl.unlockPortB;
	endrule



	// DMA Write
	FIFOF#(Bool) mapBramReq <- mkSizedFIFOF(10);
	FIFOF#(Bool) dmaWriteReq2Resp <- mkSizedFIFOF(10);

	// Total 1MB, each word: 512bit=64Byte -> total 14bit address
	// Total 1MB, Each burst beat 64bit = 8Byte -> total 128*1024 beats
	Integer mapDownloadReqs = 16*1024; // 2^14
	Reg#(Bit#(20)) mapDownloadReqCnt <- mkReg(0);
	Reg#(Bit#(20)) dmaWriteBeatCnt <- mkReg(0);

	rule initUpload;
		downloadReq.deq;
		mapBramReq.enq(True);
		dmaWriteReq2Resp.enq(True);

		let dmaCmd = MemengineCmd {
							sglId: dmaMapRef, 
							base: 0,
							len: 1024*1024, // 1MB 
							burstLen: 128
						};

		let weS = getWEServer(we, 0);
		weS.request.put(dmaCmd);

		$display("[AFTLBRAMTest.bsv] init dma write cmd issued");
	endrule

	rule reqMapData if (mapBramReq.notEmpty);
		//$display("[AFTLBRAMTest.bsv] map read req for download issued: %d", mapDownloadReqCnt);
		bram_ctrl.readReqB( truncate( mapDownloadReqCnt ) );

		if (mapDownloadReqCnt == fromInteger(mapDownloadReqs - 1)) begin
			mapDownloadReqCnt <= 0;
			mapBramReq.deq;
		end else begin
			mapDownloadReqCnt <= mapDownloadReqCnt+1;
		end
	endrule

	FIFO#(Bit#(512)) dmaWrDataBuf <- mkFIFO;

	rule pipeDmaWrData1;
		//$display("[AFTLBRAMTest.bsv] map read data for download");
		let d <- bram_ctrl.readB;
		dmaWrDataBuf.enq(d);
	endrule

	Reg#(Bit#(3)) dmaWrPhase <- mkReg(0);

	rule pipeDmaWrData2;
		let buffered_data = dmaWrDataBuf.first; // 512bit

		Bit#(DataBusWidth) data = truncate( buffered_data >> { dmaWrPhase, 6'b0 } );

		let weS = getWEServer(we, 0);
		weS.data.enq(data);

		if (dmaWrPhase == 7) begin
			dmaWrDataBuf.deq;
		end

		dmaWrPhase <= dmaWrPhase+1;
	endrule


	rule dmaWrDone;
		let weS = getWEServer(we, 0);
		let dummy <- weS.done.get;
		dmaWriteReq2Resp.deq;

		indication.downloadDone;
		bram_ctrl.unlockPortB;
	endrule


	//----------
	// Misc
	//----------

	rule counting;
		counter <= counter+1;
	endrule

	//---------
	// FTL
	//---------
	AFTLIfc myFTL <- mkAFTL(bram_ctrl);

	rule indication_success;
		let d <- myFTL.getSuccess;
		let bus = d.bus;
		let chip = d.chip;
		let block = d.block;
		let page = d.page;

		Bit#(2) op;

		case (d.op)
			READ_PAGE: op=0;
			WRITE_PAGE: op=1;
			ERASE_BLOCK: op=2;
			default: op=3;
		endcase

		$display("[AFTLBRAMTest.bsv] Success: %d %d %d %d", bus, chip, block, page);
		lastReqCnt.deq;
		indication.translateSuccess( zeroExtend(op),
								zeroExtend(bus),
								zeroExtend(chip),
								zeroExtend(block),
								zeroExtend(page),
								counter - lastReqCnt.first
		);
	endrule

	rule indication_fail;
		let d <- myFTL.getFailure;

		Bit#(2) op;

		case (d.op)
			READ_PAGE: op=0;
			WRITE_PAGE: op=1;
			ERASE_BLOCK: op=2;
			default: op=3;
		endcase

		$display("[AFTLBRAMTest.bsv] Failed %u", op );
		lastReqCnt.deq;
		indication.translateFailure( zeroExtend(op),
								counter - lastReqCnt.first
		);
	endrule

	// ----------
	// Interfaces
	// ----------
	//DMA Engines
	Vector#(NumWriteClients, MemWriteClient#(DataBusWidth)) dmaWriteClientVec; 
	Vector#(NumReadClients, MemReadClient#(DataBusWidth)) dmaReadClientVec;

	for (Integer tt = 0; tt < valueOf(NumReadClients); tt=tt+1) begin
		dmaReadClientVec[tt] = re[tt].dmaClient;
	end

	for (Integer tt = 0; tt < valueOf(NumWriteClients); tt=tt+1) begin
		dmaWriteClientVec[tt] = we[tt].dmaClient;
	end

	interface AFTLBRAMTestRequest request;
		method Action translate(Bit#(32) op, Bit#(32) lpa);
			case (op)
				0: // READ
				myFTL.translate( FTLCmd{tag: 0, op: READ_PAGE, lpa: lpa} );
				1: // WRITE
				myFTL.translate( FTLCmd{tag: 0, op: WRITE_PAGE, lpa: lpa} );
				2: // ERASE
				myFTL.translate( FTLCmd{tag: 0, op: ERASE_BLOCK, lpa: lpa} );
			endcase

			lastReqCnt.enq(counter);
		endmethod
		method Action setDmaRef(Bit#(32) map);//, Bit#(32) mgr);
			dmaMapRef <= map;
			//dmaMgrRef <= mgr;
		endmethod
		method Action downloadMap(); // Read Map&Mgr from FPGA to Host (DMA Write)
			mapReq.enq(DOWNLOAD);
		endmethod
		method Action uploadMap(); // Upload Map&Mgr from host to FPGA (DMA Read)
			mapReq.enq(UPLOAD);
		endmethod
	endinterface

	interface AFTLBRAMTestPins pins;
	endinterface

	interface dmaWriteClient = dmaWriteClientVec;
	interface dmaReadClient = dmaReadClientVec;
endmodule
