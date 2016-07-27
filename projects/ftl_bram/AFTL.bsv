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
//DRAM FFFF
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
//DRAM FFFF
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

typedef enum { P0, P1, P2, P3, P4, P5, P6, P7, P8 } AFTLPhase deriving (Bits, Eq);


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
	Vector#(16, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries1 = take(minEntries0);
	Vector#(8, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries2  = take(minEntries0);
	Vector#(4, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries3  = take(minEntries0);
	Vector#(2, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries4  = take(minEntries0);

//	Vector#(16, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries1 <- replicateM(mkReg(tagged Invalid));
//	Vector#(8, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries2  <- replicateM(mkReg(tagged Invalid));
//	Vector#(4, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries3  <- replicateM(mkReg(tagged Invalid));
//	Vector#(2, Reg#(Maybe#(Tuple2#(Bit#(14), Bit#(14))))) minEntries4  <- replicateM(mkReg(tagged Invalid));
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
				$display("[FTL.bsv] phyAddr: %d %d x %d", phyAddr.bus, phyAddr.chip, phyAddr.page);
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
			Bit#(14) minBlk = (zeroExtend( blkTableCnt ) << 5) + fromInteger(idx);
			//$display("[func] ");
			case ( isValid(prevMin) && tpl_2(fromMaybe(?,prevMin)) <= blkEntry.erase )
				True:  return prevMin;
				False: return tagged Valid tuple2( minBlk , blkEntry.erase);
			endcase
		end
	endfunction

	// each RAM read contains 32 block entries (total 128 RAM read -> 4096 blocks)
	// Whenever we retreive 32 entries, we keep only the min at each position ( 31 ~ 0 )
	rule readBlockTable0 ( (phase == P2) && (blkTableCnt<128) );
		let blkTable <- bram_ctrl.read;
		blkTableCnt <= blkTableCnt+1;
		
		$display("[FTL.bsv] readBlockTable0_1 %x (bram_read)", blkTable);

		Vector#(32, BlkEntry) blkEntries = unpack(blkTable);
		Vector#(32, Integer) indices = genVector();
		
		let newMinEntries = zipWith3( getMinEntries, readVReg(minEntries0), blkEntries, indices);
		Bit#(14) minBlk = (zeroExtend( blkTableCnt ) << 5) + fromInteger(indices[1]);
		$display("[FTL.bsv] readBlockTable0_2  newminEntries[1]: blkTableCnt: %d, index: %d, calc_blk: %d, blk: %d, erase: %x",
		                                               blkTableCnt, indices[1], minBlk, tpl_1(fromMaybe(?,newMinEntries[1])), tpl_2(fromMaybe(?,newMinEntries[1])));
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

		$display("[FTL.bsv] readBlockTable1 %x", minVec);
		writeVReg(minEntries1, minVec);
		phase <= P3;
	endrule


	rule readBlockTable2 ( phase == P3 );
		Vector#(8, Maybe#(Tuple2#(Bit#(14), Bit#(14)))) minVec;
		
		for ( Integer i=0; i<8; i=i+1) begin
			minVec[i] = min2to1( takeAt(2*i, readVReg(minEntries1)) );
		end

		$display("[FTL.bsv] readBlockTable2 %x", minVec);
		writeVReg(minEntries2, minVec);
		phase <= P4;
	endrule

	
	rule readBlockTable3 ( phase == P4 );
		Vector#(4, Maybe#(Tuple2#(Bit#(14), Bit#(14)))) minVec;

		for ( Integer i=0; i<4; i=i+1) begin
			minVec[i] = min2to1( takeAt(2*i, readVReg(minEntries2)) );
		end

		$display("[FTL.bsv] readBlockTable3 %x", minVec);
		writeVReg(minEntries3, minVec);
		phase <= P5;
	endrule

	rule readBlockTable4 ( phase == P5 );
		Vector#(2, Maybe#(Tuple2#(Bit#(14), Bit#(14)))) minVec;

		for ( Integer i=0; i<2; i=i+1) begin
			minVec[i] = min2to1( takeAt(2*i, readVReg(minEntries2)) );
		end

		$display("[FTL.bsv] readBlockTable4 %x", minVec);
		writeVReg(minEntries4, minVec);
		phase <= P6;
	endrule

	rule readBlockTable5 ( phase == P6 );
		Maybe#(Tuple2#(Bit#(14), Bit#(14))) minEntry = min2to1( readVReg(minEntries4) );

		$display("[FTL.bsv] readBlockTable5 isValid: %d Block: %d Erase: %x", isValid(minEntry), tpl_1(fromMaybe(?, minEntry)), tpl_2(fromMaybe(?, minEntry)));
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

	rule updateMapTable ( (phase == P7) );
		if ( isValid(blkToAlloc) ) begin
			phase <= P8;

			let logAddr = procQ.first;
			let phyAddr = allocQ.first;
			phyAddr.block = zeroExtend(tpl_1(fromMaybe(?, blkToAlloc)));
			// update mapping
			Bit#(10) idx = zeroExtend(logAddr.block[4:0]) << 4;
			MapEntry newEntry = MapEntry{status: ALLOCATED, block: truncate(phyAddr.block)};
			bram_ctrl.write( zeroExtend({ 1'b0, logAddr.segment, logAddr.block[5] }),
							 zeroExtend(pack(newEntry)) << idx ,
							 zeroExtend(  64'b11 << {logAddr.block[4:0],1'b0}  ) );
		
			$display("[FTL.bsv] updateMapAddr: %x", ({ 1'b0, logAddr.segment, logAddr.block[5] }));
			$display("[FTL.bsv] updateMapData: %x", (pack(newEntry)) << idx );
			$display("[FTL.bsv] updateMapMast: %x", 64'b11 << {logAddr.block[4:0],1'b0});

			$display("[FTL.bsv] updateMap: %d %d %d %d", phyAddr.bus, phyAddr.chip, phyAddr.block, phyAddr.page);
		end else begin
			phase <= P0;
			procQ.deq;
			allocQ.deq;

			resps.enq(tagged Invalid);
		end
	endrule

	rule updateBlockTable ( (phase == P8) );
		phase <= P0;
		procQ.deq;
		allocQ.deq;

		let phyAddr = allocQ.first;
		phyAddr.block = zeroExtend(tpl_1(fromMaybe(?, blkToAlloc)));

		Bit#(3) channel  = phyAddr.bus;
		Bit#(3) chip     = phyAddr.chip;
		Bit#(14) block   = tpl_1(fromMaybe(?, blkToAlloc));
		Bit#(14) erase   = tpl_2(fromMaybe(?, blkToAlloc));

		// result to resps
		resps.enq(tagged Valid phyAddr);

		// update block table
		Bit#(10) idx = zeroExtend(block[4:0]) << 4;
		BlkEntry newEntry = BlkEntry{status: CLEAN_BLK, erase: erase};
		bram_ctrl.write( zeroExtend({ 1'b1, channel, chip, block[11:5] }),
						 zeroExtend(pack(newEntry)) << idx ,
						 zeroExtend(  64'b11 << {block[4:0],1'b0}  ) );

		$display("[FTL.bsv] updateMgrAddr: %x", ({ 1'b1, channel, chip, block[11:5] }));
		$display("[FTL.bsv] updateMgrData: %x", (pack(newEntry)) << idx );
		$display("[FTL.bsv] updateMgrMast: %x", 64'b11 << {block[4:0],1'b0});
	endrule

	method Action translate(LPA lpa) = reqs.enq(lpa);
	method ActionValue#(Maybe#(PhyAddr)) get = toGet(resps).get;
endmodule
endpackage: AFTL
