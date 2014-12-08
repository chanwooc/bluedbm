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

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import BRAM::*;
import Gearbox::*;
import Connectable::*;
import StmtFSM::*;
import MemTypes::*;
import MPEngineBDBM::*;
import MemreadEngine::*;
import Pipe::*;
import ControllerTypes::*;

interface StrstrRequestBDBM;
   method Action setup(Bit#(32) needleSGLId, Bit#(32) mpNextSGLId, Bit#(32) needle_len);
   method Action search(Bit#(32) haystackSGLId, Bit#(32) haystack_len);
endinterface

interface StrstrIndicationBDBM;
   method Action searchResult(Int#(32) v);
endinterface

interface StrstrBDBM#(numeric type haystackBusWidth, numeric type configBusWidth);
   interface StrstrRequestBDBM request;
   //interface MemReadClient#(haystackBusWidth) haystack_read_client;
	interface Vector#(NumMpEngines, FlashReadClient#(haystackBusWidth)) haystack_flash_clients;
   interface MemReadClient#(configBusWidth) config_read_client;
endinterface

// I can't belive we still have to do this shit
function Bool my_or(Bool a, Bool b) = a || b;
   
//typedef `DEGPAR DegPar;   
   
module mkStrstrBDBM#(StrstrIndicationBDBM indication)(StrstrBDBM#(haystackBusWidth, configBusWidth))
   provisos( Add#(0,NumMpEngines,p)
	    ,Log#(p,lp)


   ,Mul#(TDiv#(configBusWidth, 8), 8, configBusWidth)
   ,Mul#(TDiv#(haystackBusWidth, 8), 8, haystackBusWidth)
   ,Add#(1, a__, TDiv#(haystackBusWidth, 8))
   ,Add#(b__, TLog#(TDiv#(haystackBusWidth, 8)), 32)
   ,Mul#(TDiv#(configBusWidth, 32), 32, configBusWidth)
   ,Add#(1, c__, TDiv#(configBusWidth, 32))
   ,Add#(d__, TLog#(TDiv#(configBusWidth, 32)), 32)
   ,Add#(e__, TLog#(TDiv#(configBusWidth, 8)), 32)
   ,Add#(1, f__, TDiv#(configBusWidth, 8))
   ,Add#(g__, TLog#(TDiv#(haystackBusWidth, 32)), 32)
   ,Mul#(TDiv#(haystackBusWidth, 32), 32, haystackBusWidth)
   ,Add#(1, h__, TDiv#(haystackBusWidth, 32))
   ,Add#(i__, 32, haystackBusWidth)
   ,Add#(j__, 8, haystackBusWidth)
   
	    );
   
   let verbose = True;

   Reg#(Bit#(32)) needleLen <- mkReg(0);
   //MemreadEngineV#(haystackBusWidth, 1, p) haystack_re <- mkMemreadEngineBuff(1024);
   MemreadEngineV#(configBusWidth, 1, p) config_re <- mkMemreadEngineBuff(1024);
   
   Reg#(Bit#(32)) needleSGLId <- mkReg(0);
   Reg#(Bit#(32)) mpNextSGLId <- mkReg(0);
   Reg#(Bit#(32)) haystackSGLId <- mkReg(0);
   Reg#(Bit#(32)) haystackLen <- mkReg(0);
   Reg#(Bit#(32)) startCnt <- mkReg(0);
   Reg#(Bit#(32)) startBase <- mkReg(0);
   Reg#(Bit#(32)) setupCnt <- mkReg(0);
   Reg#(Bit#(32)) doneCnt <- mkReg(0);

   //let read_servers = zip(haystack_re.read_servers,config_re.read_servers);
   //Vector#(p, MPEngine#(haystackBusWidth,configBusWidth)) engines <- mapM(uncurry(mkMPEngine),read_servers);
   Vector#(p, MPEngineBDBM#(haystackBusWidth,configBusWidth)) engines = newVector();
	Vector#(p, FlashReadClient#(haystackBusWidth)) mpengine_flash_clients = newVector();
	for (Integer e=0; e<valueOf(p); e=e+1) begin
		engines[e] <- mkMPEngineBDBM(config_re.read_servers[e]);
		mpengine_flash_clients[e] = engines[e].flash_client;
	end


   Vector#(p, PipeOut#(Int#(32))) locdonePipes;

   FIFOF#(Tripple#(Bit#(32))) setsearchFIFO <- mkFIFOF;
   UnFunnelPipe#(1,p,Tripple#(Bit#(32)),1) setsearchPipeUnFunnel <- mkUnFunnelPipesPipelinedRR(cons(toPipeOut(setsearchFIFO),nil), 1);

   for(Integer i = 0; i < valueOf(p); i=i+1) begin 
      locdonePipes[i] = engines[i].locdone;
      mkConnection(setsearchPipeUnFunnel[i],engines[i].setsearch);
   end

   FunnelPipe#(1,p,Int#(32),1) locdonePipe <- mkFunnelPipesPipelined(locdonePipes);
   let lpv = fromInteger(valueOf(lp));
   let pv = fromInteger(valueOf(p));

   rule resr;
		let rv <- toGet(locdonePipe[0]).get;
		
		if (rv == -1) begin  
			// notify the SW when the search is finished
			if (doneCnt+1 == pv) begin
				doneCnt <= 0;
				indication.searchResult(-1);
			end
			else begin
				doneCnt <= doneCnt+1;
			end
		end
		else begin    
			// send results back to SW
			indication.searchResult(rv);
			if (verbose) $display("strstr search result %d", rv);
		end
		
	  $display("Got locdone pipe value = %d", rv);
   endrule
   
   // setup the MPEngines when new configuration arrives
   Stmt setupStmt = 
   seq
      action
	 if (verbose) $display("setupStmt (begin)");
	 setupCnt <= 0;
      endaction
      while(setupCnt < pv) action
	 setupCnt <= setupCnt+1;
	 let tup = tuple3(needleSGLId, mpNextSGLId, needleLen);
	 setsearchFIFO.enq(tup);
	 if (verbose) $display(fshow("setupStmt (mid) ")+fshow(tup));
      endaction
      if (verbose) $display("setupStmt (end)");
   endseq;
   FSM setupFSM <- mkFSM(setupStmt);

   // start the search;
   Stmt startStmt = 
   seq
      action
	 if (verbose) $display("startStmt (begin)");
	 startCnt <= 0;
	 startBase <= 0;
      endaction
      while (startCnt < pv-1) action
	 let tup = tuple3(haystackSGLId, (haystackLen>>lpv)+needleLen, startBase);
	 setsearchFIFO.enq(tup);
	 startBase <= startBase + (haystackLen>>lpv);
	 startCnt <= startCnt+1;
	 if (verbose) $display(fshow("startStmt ")+fshow(tup)+fshow(" (mid)"));
      endaction
      action
	 let tup = tuple3(haystackSGLId, haystackLen>>lpv, startBase);
	 setsearchFIFO.enq(tup);
	 if (verbose) $display(fshow("startStmt ")+fshow(tup)+fshow(" (end)"));
      endaction
   endseq;
   FSM startFSM <- mkFSM(startStmt);
      
   interface StrstrRequestBDBM request;
      method Action setup(Bit#(32) needle_sglId, Bit#(32) mpNext_sglId, Bit#(32) needle_len);
	 if (verbose) $display("mkStrstr::setup %d %d %d", needle_sglId, mpNext_sglId, needle_len);
	 needleLen <= needle_len;
	 needleSGLId <= needle_sglId;
	 mpNextSGLId <= mpNext_sglId;
	 setupFSM.start();
      endmethod
   
      method Action search(Bit#(32) haystack_sglId, Bit#(32) haystack_len);
	 if (verbose) $display("mkStrstr::search %d %d", haystack_sglId, haystack_len);
	 haystackLen <= haystack_len;
	 haystackSGLId <= haystack_sglId;
	 startFSM.start();
      endmethod
   endinterface
   interface config_read_client = config_re.dmaClient;
   //interface haystack_read_client = haystack_re.dmaClient;
	interface haystack_flash_clients = mpengine_flash_clients;
endmodule
   
   
