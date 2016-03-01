import AuroraCommon::*;
import AuroraExtImport::*;
import MainTypes::*;
import Vector::*;

interface Top_Pins;
	interface Aurora_Pins#(4) aurora_fmc1;
	interface Aurora_Clock_Pins aurora_clk_fmc1;
	interface Vector#(AuroraExtPerQuad,Aurora_Pins#(1)) aurora_ext;
	interface Aurora_Clock_Pins aurora_quad109;
endinterface
