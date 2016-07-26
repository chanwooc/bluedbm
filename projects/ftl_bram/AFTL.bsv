package AFTL;

import FIFO::*;
import Vector::*;
import Leds::*;

import GetPut::*;

// DDR3 support
//import DDR3Sim::*;
//import DDR3Controller::*;
//import DDR3Common::*;
//import DRAMController::*;

import BRAM::*;
import BRAM_Wrapper::*;
import Connectable::*;
import DefaultValue::*;

import ControllerTypes::*;

import HostInterface::*;
import Clocks::*;
import ConnectalClocks::*;

//typedef NUM_TOTAL_CHIPS BlocksPerSegment;                        // 8*8=64=2^6
//typedef TMul#(PagesPerBlock, BlocksPerSegment) PagesPerSegment;  // 64*256=16384=2^14
//typedef BlocksPerCE NumSegment;                                  // 4096
typedef 64 BlocksPerSegment;
typedef 16384 PagesPerSegment;
typedef 4096 NumSegment;

typedef TLog#(BlocksPerSegment) LogicalBlockSz; // 6-bit
//typedef TLog#(PagesPerBlock) PageOffsetSz;      // 8-bit
typedef TLog#(256) PageOffsetSz;      // 8-bit
typedef TLog#(NumSegment) SegmentSz;            // 12-bit

typedef Bit#(32) LPA;

typedef struct {
	Bit#(SegmentSz)       segment;
	Bit#(PageOffsetSz)    page;
	Bit#(LogicalBlockSz)  block;
} LogAddr deriving (Bits, Eq);

/*
typedef struct {
	Bit#(8) page;
	Bit#(16) block;
	ChipT chip;
	BusT bus;
} FlashAddr deriving (Bits, Eq);
*/
typedef FlashAddr PhyAddr;

`ifndef BSIM
//in real hardware, RAM is initialized to FFFFFF
//typedef enum { TRIM, DEAD, ALLOCATED, NOT_ALLOCATED } MapStatus deriving (Bits, Eq);
//BRAM 0000
typedef enum { NOT_ALLOCATED, ALLOCATED, DEAD } MapStatus deriving (Bits, Eq);
`else
//For testing. At BSIM, RAM is initialized to AAAAAAA
typedef enum { DEAD, ALLOCATED, NOT_ALLOCATED } MapStatus deriving (Bits, Eq);
`endif

typedef struct {
	MapStatus status;
	Bit#(TSub#(16, SizeOf#(MapStatus))) block; // physical block#
} MapEntry deriving (Bits, Eq); // 16-bit (2-bytes) mapping entry

`ifndef BSIM
//in real hardware, DRAM is initialized to FFFFFF
//typedef enum { BAD_BLK, DIRTY_BLK, CLEAN_BLK, FREE_BLK } BlkStatus deriving (Bits, Eq);
//BRAM 0000
typedef enum { FREE_BLK, DIRTY_BLK, CLEAN_BLK, BAD_BLK } BlkStatus deriving (Bits, Eq);
`else
//For testing. At BSIM, RAM is initialized to AAAAAAA
typedef enum { BAD_BLK, DIRTY_BLK, FREE_BLK, CLEAN_BLK } BlkStatus deriving (Bits, Eq);
`endif


typedef struct {
	BlkStatus status; //2
	Bit#(TSub#(16, SizeOf#(BlkStatus))) erase; //14
} BlkEntry deriving (Bits, Eq); // 16-bit (2-bytes) block info entry

function Bit#(PageOffsetSz) getPageOffset(LPA lpa);
	return truncate(lpa>>valueOf(LogicalBlockSz));
endfunction

function Bit#(LogicalBlockSz) getLogicalBlock(LPA lpa);
	return truncate(lpa);
endfunction

function Bit#(SegmentSz) getSegment(LPA lpa);
	return truncate(lpa>>valueOf(TAdd#(LogicalBlockSz,PageOffsetSz)));
endfunction

function LogAddr getLogAddr(LPA lpa);
	return LogAddr {
		segment: getSegment(lpa),
		page   : getPageOffset(lpa),
		block  : getLogicalBlock(lpa)
	};
endfunction

interface AFTLIfc;
	method Action translate(LPA lpa);
	method ActionValue#(Maybe#(PhyAddr)) get;
endinterface

typedef enum { P0, P1, P2, P3, P4, P5, P6, P7 } AFTLPhase deriving (Bits, Eq);


module mkAFTL#(BRAM_Wrapper1 bram_ctrl)(AFTLIfc);
	FIFO#(LPA) reqs <- mkSizedFIFO(16); // TODO: size?
	FIFO#(Maybe#(PhyAddr)) resps <- mkSizedFIFO(16);

	FIFO#(LogAddr) procQ <- mkFIFO;

	Reg#(AFTLPhase) phase <- mkReg(P0);

	// for phase2 & 3
	Reg#(Bit#(10)) blkTableReqCnt <- mkReg(0);
	Reg#(Bit#(10)) blkTableCnt <- mkReg(0);
	FIFO#(PhyAddr) allocQ <- mkFIFO;

	// first 14-bit for phy_blk#, next 14-bit for erase#
	Vector#(32, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries0 <- replicateM(mkReg(tagged Invalid));
	Vector#(16, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries1 <- replicateM(mkReg(tagged Invalid));
	Vector#(8, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries2 <- replicateM(mkReg(tagged Invalid));
	Vector#(4, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries3 <- replicateM(mkReg(tagged Invalid));
	Vector#(2, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries4 <- replicateM(mkReg(tagged Invalid));

	Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14)))) blkToAlloc <- mkReg(tagged Invalid);

	rule readReqMapTable (phase == P0) ;
		LPA lpa <- toGet(reqs).get;
		$display("[FTL.bsv] lpa received: %d & bram_req sent", lpa);

		let logAddr = getLogAddr(lpa);
		$display("[FTL.bsv] logAddr: %b %b %b", lpa[25:14] , lpa[13:6], lpa[5:0]);
		$display("[FTL.bsv] logAddr: %b %b %b", logAddr.segment, logAddr.page, logAddr.block);

		procQ.enq(logAddr);

		// dram: 64-byte word "with three LSBs = 0"
		// each entry: 2byte -> 32 entries -> indexed by logAddr.block[4:0]
		// Addr[16] = 0 for Mapping Table
		bram_ctrl.readReq( zeroExtend({ 1'b0, logAddr.segment, logAddr.block[5] }) );

		phase <= P1;
	endrule

	rule readMapTable (phase == P1) ;
		let map <- bram_ctrl.read;
		let logAddr = procQ.first;
		Bit#(10) idx = zeroExtend(logAddr.block[4:0]) << 4;
		MapEntry entry = unpack(truncate( map >> idx ));
		$display("[FTL.bsv] bram read: %x", map);
		$display("[FTL.bsv] my_entry: %x", ( map >> idx) );
		
		case (entry.status)
			NOT_ALLOCATED:
			begin
				// initialization for P2
				blkTableReqCnt <= 0;
				blkTableCnt <= 0;
				blkToAlloc <= tagged Invalid;
				phase <= P2;
				writeVReg( minEntries0, replicate( tagged Invalid ) );

				let phyAddr = PhyAddr{
					page: zeroExtend(logAddr.page),
					block: ?,
					chip: truncate(logAddr.block >> 3),
					bus: truncate(logAddr.block[2:0])
				};
				allocQ.enq(phyAddr);
				$display("[FTL.bsv] bram read @ readMapTable, NOT_ALLOCATED");
				$display("[FTL.bsv] phyAddr: %d %d %d %d", phyAddr.bus, phyAddr.chip, phyAddr.block, phyAddr.page);
			end
			ALLOCATED:
			begin
				// if there is a valid mapping entry:
				// blk# from mapping
				// chip# = logBlk % 8
				// chan# = logBlk / 8
				procQ.deq;
				let phyAddr = PhyAddr{
					page: zeroExtend(logAddr.page),
					block: zeroExtend(entry.block),
					chip: truncate(logAddr.block >> 3),
					bus: truncate(logAddr.block[2:0])
				};
				resps.enq(tagged Valid phyAddr);
				phase <= P0;
				$display("[FTL.bsv] bram read @ readMapTable, ALLOCATED");
				$display("[FTL.bsv] phyAddr: %d %d %d %d", phyAddr.bus, phyAddr.chip, phyAddr.block, phyAddr.page);
			end
			//DEAD:
			default:
			begin
				// DEAD or other state -> Invalid
				procQ.deq;
				resps.enq(tagged Invalid);
				phase <= P0;
				$display("[FTL.bsv] bram read @ readMapTable, DEFAULT");
			end
		endcase
	endrule

	rule readReqBlockTable ( (phase == P2) && (blkTableReqCnt<128) );
		//$display("[FTL.bsv] readReqBlockTable %d (bram_req)", blkTableReqCnt);
		blkTableReqCnt <= blkTableReqCnt+1;
		Bit#(3) channel  = allocQ.first.bus;
		Bit#(3) chip     = allocQ.first.chip;
		bram_ctrl.readReq( zeroExtend({ 1'b1, channel, chip, blkTableReqCnt[6:0] }) );
	endrule

	//tpl_1(prevMin): PhyBlk#, tpl_2(prevMin): erase#   (both are 14-bit values)
	function Maybe#(Tuple2#(Bit#(14), Bit#(14))) getMinEntries (Maybe#(Tuple2#(Bit#(14), Bit#(14))) prevMin, BlkEntry blkEntry, Integer idx);
		if (blkEntry.status != FREE_BLK)
			return prevMin;
		else begin
			//compare only if FREE_BLK
			case ( isValid(prevMin) && tpl_2(fromMaybe(?,prevMin)) <= blkEntry.erase )
				True:  return prevMin;
				False: return tagged Valid tuple2( zeroExtend( blkTableCnt ) << 5  + fromInteger(idx) , blkEntry.erase);
			endcase
		end
	endfunction

	// each RAM read contains 32 block entries (total 128 RAM read -> 4096 blocks)
	// Whenever we retreive 32 entries, we keep only the min at each position ( 31 ~ 0 )
	rule readBlockTable0 ( (phase == P2) && (blkTableCnt<128) );
		//$display("[FTL.bsv] readBlockTable %d (bram_read)", blkTableCnt);
		blkTableCnt <= blkTableCnt+1;

		let blkTable <- bram_ctrl.read;
		Vector#(32, BlkEntry) blkEntries = unpack(blkTable);
		Vector#(32, Integer) indices = genVector();
		
		let newMinEntries = zipWith3( getMinEntries, readVReg(minEntries0), blkEntries, indices);
		writeVReg(minEntries0, newMinEntries);
	endrule

	// After we finish readBlockTable0, we have 32 entries with lowest erase# 
	// We finally pick "ONE" out of these 32 entries

	// 32->8->2->1 : 32->8 Timing not met!
	// 32->16->4->1: 4->1 Timing not met!
	// 32->16->4->2->1: also not working
	// Finally, we should reduce by 2 (32 16 8 4 2 1)

	function Maybe#(Tuple2#(Bit#(14), Bit#(14))) min4to1 ( Vector#(4, Maybe#(Tuple2#(Bit#(14), Bit#(14)))) entries);
		Maybe#(Tuple2#(Bit#(14), Bit#(14))) minEntry = tagged Invalid;
		
		for (Integer i=0; i<4; i=i+1) begin
			if(isValid(entries[i])) begin
				if ( !( isValid(minEntry) && tpl_2(fromMaybe(?, minEntry)) <= tpl_2(fromMaybe(?, entries[i])) ) ) begin
					minEntry = entries[i];
				end
			end
		end
		return minEntry;
	endfunction

	function Maybe#(Tuple2#(Bit#(14), Bit#(14))) min2to1 ( Vector#(2, Maybe#(Tuple2#(Bit#(14), Bit#(14)))) entries);
		Maybe#(Tuple2#(Bit#(14), Bit#(14))) minEntry = tagged Invalid;
		for (Integer i=0; i<2; i=i+1) begin
			if(isValid(entries[i])) begin
				if ( !( isValid(minEntry) && tpl_2(fromMaybe(?, minEntry)) <= tpl_2(fromMaybe(?, entries[i])) ) ) begin
					minEntry = entries[i];
				end
			end
		end

		return minEntry;
	endfunction


	rule readBlockTable1 ( (phase == P2) && (blkTableCnt==128) );
		Vector#(16, Maybe#(Tuple2#(Bit#(14), Bit#(14)))) minVec;
		
		for ( Integer i=0; i<16; i=i+1) begin
			minVec[i] = min2to1( takeAt(2*i, readVReg(minEntries0)) );
		end

		writeVReg(minEntries1, minVec);
		phase <= P3;
	endrule


	rule readBlockTable2 ( phase == P3 );
		Vector#(8, Maybe#(Tuple2#(Bit#(14), Bit#(14)))) minVec;
		
		for ( Integer i=0; i<8; i=i+1) begin
			minVec[i] = min2to1( takeAt(2*i, readVReg(minEntries1)) );
		end

		writeVReg(minEntries2, minVec);
		phase <= P4;
	endrule

	
	rule readBlockTable3 ( phase == P4 );
		Vector#(4, Maybe#(Tuple2#(Bit#(14), Bit#(14)))) minVec;

		for ( Integer i=0; i<4; i=i+1) begin
			minVec[i] = min2to1( takeAt(2*i, readVReg(minEntries2)) );
		end

		writeVReg(minEntries3, minVec);
		phase <= P5;
	endrule

	rule readBlockTable4 ( phase == P5 );
		Vector#(2, Maybe#(Tuple2#(Bit#(14), Bit#(14)))) minVec;

		for ( Integer i=0; i<2; i=i+1) begin
			minVec[i] = min2to1( takeAt(2*i, readVReg(minEntries2)) );
		end

		writeVReg(minEntries4, minVec);
		phase <= P6;
	endrule

	rule readBlockTable5 ( phase == P6 );
		Maybe#(Tuple2#(Bit#(14), Bit#(14))) minEntry = min2to1( readVReg(minEntries4) );

		blkToAlloc <= minEntry;
		phase <= P7;
	endrule

	//rule readBlockTable1 ( (phase == P2) && (blkTableCnt==128) );
	//	// bluespec cannot unfold following :(
	//	Maybe#(Tuple2#(Bit#(14), Bit#(14))) minEntry = tagged Invalid;

	//	for (Integer i=0; i<32; i=i+1) begin
	//		if(isValid(minEntries[i])) begin
	//			if ( !( isValid(minEntry) && tpl_2(fromMaybe(?, minEntry)) <= tpl_2(fromMaybe(?, minEntries[i])) ) ) begin
	//				minEntry = minEntries[i];
	//			end
	//		end
	//	end

	//	blkToAlloc <= minEntry;
	//	phase <= P3;
	//endrule

	rule updateBlockTable ( (phase == P7) );
		procQ.deq;
		allocQ.deq;

		phase <= P0;
		if ( isValid(blkToAlloc) ) begin
			// result to resps
			let logAddr = procQ.first;
			let phyAddr = allocQ.first;
			phyAddr.block = zeroExtend(tpl_1(fromMaybe(?, blkToAlloc)));
			$display("[FTL.bsv] update-phyAddr: %d %d %d %d", phyAddr.bus, phyAddr.chip, phyAddr.block, phyAddr.page);
			resps.enq(tagged Valid phyAddr);

			// update map
			//bram_ctrl.readReq( zeroExtend({ 1'b0, logAddr.segment, logAddr.block[5], 3'b0 }) );
			Bit#(10) idx = zeroExtend(logAddr.block[4:0]) << 4;
			MapEntry newEntry = MapEntry{status: ALLOCATED, block: truncate(phyAddr.block)};
			bram_ctrl.write( zeroExtend({ 1'b0, logAddr.segment, logAddr.block[5] }),
							 zeroExtend(pack(newEntry)) << idx ,
							 zeroExtend(  64'b11 << {logAddr.block[4:0],1'b0}  ) );
		end else begin
			resps.enq(tagged Invalid);
		end
	endrule

	method Action translate(LPA lpa) = reqs.enq(lpa);
	method ActionValue#(Maybe#(PhyAddr)) get = toGet(resps).get;
endmodule
endpackage: AFTL
