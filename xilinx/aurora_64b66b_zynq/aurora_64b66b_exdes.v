 ///////////////////////////////////////////////////////////////////////////////
 //
 // Project:  Aurora 64B/66B
 // Company:  Xilinx
 //
 //
 //
 // (c) Copyright 2008 - 2009 Xilinx, Inc. All rights reserved.
 //
 // This file contains confidential and proprietary information
 // of Xilinx, Inc. and is protected under U.S. and
 // international copyright and other intellectual property
 // laws.
 //
 // DISCLAIMER
 // This disclaimer is not a license and does not grant any
 // rights to the materials distributed herewith. Except as
 // otherwise provided in a valid license issued to you by
 // Xilinx, and to the maximum extent permitted by applicable
 // law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
 // WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
 // AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
 // BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
 // INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
 // (2) Xilinx shall not be liable (whether in contract or tort,
 // including negligence, or under any other theory of
 // liability) for any loss or damage of any kind or nature
 // related to, arising under or in connection with these
 // materials, including for any direct, or any indirect,
 // special, incidental, or consequential loss or damage
 // (including loss of data, profits, goodwill, or any type of
 // loss or damage suffered as a result of any action brought
 // by a third party) even if such damage or loss was
 // reasonably foreseeable or Xilinx had been advised of the
 // possibility of the same.
 //
 // CRITICAL APPLICATIONS
 // Xilinx products are not designed or intended to be fail-
 // safe, or for use in any application requiring fail-safe
 // performance, such as life-support or safety devices or
 // systems, Class III medical devices, nuclear facilities,
 // applications related to the deployment of airbags, or any
 // other applications that could lead to death, personal
 // injury, or severe property or environmental damage
 // (individually and collectively, "Critical
 // Applications"). Customer assumes the sole risk and
 // liability of any use of Xilinx products in Critical
 // Applications, subject only to applicable laws and
 // regulations governing limitations on product liability.
 //
 // THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
 // PART OF THIS FILE AT ALL TIMES.

 //
 ///////////////////////////////////////////////////////////////////////////////
 //
 //  EXAMPLE_DESIGN
 //
 //
 //  Description:  This module instantiates 1 lane Aurora Module.
 //                Used to exhibit functionality in hardware using the example design
 //                The User Interface is connected to Data Generator and Checker.
 ///////////////////////////////////////////////////////////////////////////////

 // aurora sample file, example design

 `timescale 1 ns / 10 ps

(* DowngradeIPIdentifiedWarnings="yes" *)
 module aurora_64b66b_exdes  #
 (
	parameter CORE_COUNT = 3
 )
 (
	// MY PORTS (4 Aurora Exts: X0Y0 ~ X0Y3)
	RX_DATA_0,
	rx_en_0,
	rx_rdy_0,

	TX_DATA_0,
	tx_en_0,
	tx_rdy_0,

	USER_CLK_0,
	USER_RST_0,
	USER_RST_N_0,
	
	//////////
	RX_DATA_1,
	rx_en_1,
	rx_rdy_1,

	TX_DATA_1,
	tx_en_1,
	tx_rdy_1,

	USER_CLK_1,
	USER_RST_1,
	USER_RST_N_1,

	//////////
	RX_DATA_2,
	rx_en_2,
	rx_rdy_2,

	TX_DATA_2,
	tx_en_2,
	tx_rdy_2,

	USER_CLK_2,
	USER_RST_2,
	USER_RST_N_2,
	
	//////////
	RX_DATA_3,
	rx_en_3,
	rx_rdy_3,

	TX_DATA_3,
	tx_en_3,
	tx_rdy_3,

	USER_CLK_3,
	USER_RST_3,
	USER_RST_N_3,

	// Error Detection Interface
	HARD_ERR_0,
	SOFT_ERR_0,
	DATA_ERR_COUNT_0,
	// Status
	LANE_UP_0,
	CHANNEL_UP_0,

	HARD_ERR_1,
	SOFT_ERR_1,
	DATA_ERR_COUNT_1,
	// Status
	LANE_UP_1,
	CHANNEL_UP_1,

	HARD_ERR_2,
	SOFT_ERR_2,
	DATA_ERR_COUNT_2,
	// Status
	LANE_UP_2,
	CHANNEL_UP_2,

	HARD_ERR_3,
	SOFT_ERR_3,
	DATA_ERR_COUNT_3,
	// Status
	LANE_UP_3,
	CHANNEL_UP_3,

	// System Interface
	RESET_N,
//	GT_RESET_N,
	INIT_CLK_IN,
	GTX_CLK,



	// GTX Serial I/O
	RXP_0,
	RXN_0,
	TXP_0,
	TXN_0,
	
	RXP_1,
	RXN_1,
	TXP_1,
	TXN_1,

	RXP_2,
	RXN_2,
	TXP_2,
	TXN_2,

	RXP_3,
	RXN_3,
	TXP_3,
	TXN_3

 );
 `define DLY #1


 //***********************************Port Declarations*******************************
	///////////////////////////// AURORA PIN_OUTS
	//// Aurora 0
	output [0:63] RX_DATA_0;
	input rx_en_0;
	output rx_rdy_0;

	input [0:63] TX_DATA_0;
	input tx_en_0;
	output tx_rdy_0;

	output USER_CLK_0;
	output USER_RST_0;
	output USER_RST_N_0;

	// Error Detection Interface
	output            HARD_ERR_0;
	output            SOFT_ERR_0;
	output [0:7]      DATA_ERR_COUNT_0;

	// Status
	output             LANE_UP_0;
	output             CHANNEL_UP_0;
	
	//// Aurora 1
	output [0:63] RX_DATA_1;
	input rx_en_1;
	output rx_rdy_1;

	input [0:63] TX_DATA_1;
	input tx_en_1;
	output tx_rdy_1;

	output USER_CLK_1;
	output USER_RST_1;
	output USER_RST_N_1;

	// Error Detection Interface
	output            HARD_ERR_1;
	output            SOFT_ERR_1;
	output [0:7]      DATA_ERR_COUNT_1;

	// Status
	output             LANE_UP_1;
	output             CHANNEL_UP_1;

	//// Aurora2
	output [0:63] RX_DATA_2;
	input rx_en_2;
	output rx_rdy_2;

	input [0:63] TX_DATA_2;
	input tx_en_2;
	output tx_rdy_2;

	output USER_CLK_2;
	output USER_RST_2;
	output USER_RST_N_2;

	// Error Detection Interface
	output            HARD_ERR_2;
	output            SOFT_ERR_2;
	output [0:7]      DATA_ERR_COUNT_2;

	// Status
	output             LANE_UP_2;
	output             CHANNEL_UP_2;

	//// Aurora 3
	output [0:63] RX_DATA_3;
	input rx_en_3;
	output rx_rdy_3;

	input [0:63] TX_DATA_3;
	input tx_en_3;
	output tx_rdy_3;

	output USER_CLK_3;
	output USER_RST_3;
	output USER_RST_N_3;

	// Error Detection Interface
	output            HARD_ERR_3;
	output            SOFT_ERR_3;
	output [0:7]      DATA_ERR_COUNT_3;

	// Status
	output             LANE_UP_3;
	output             CHANNEL_UP_3;

	//////////////////////////////////////////////
	// GTX Serial I/O
	input              RXP_0;
	input              RXN_0;
	output             TXP_0;
	output             TXN_0;

	input              RXP_1;
	input              RXN_1;
	output             TXP_1;
	output             TXN_1;

	input              RXP_2;
	input              RXN_2;
	output             TXP_2;
	output             TXN_2;

	input              RXP_3;
	input              RXN_3;
	output             TXP_3;
	output             TXN_3;

	//////////////////////////////////////////////
	// System Inferface
	input RESET_N;
//	input GT_RESET_N;
	input INIT_CLK_IN;
	input GTX_CLK;


 //***********************************Wire Declarations & assignments*******

	wire [0:CORE_COUNT] system_reset_i;

	assign RX_DATA_0 = rx_tdata_i[0];
	assign RX_DATA_1 = rx_tdata_i[1];
	assign RX_DATA_2 = rx_tdata_i[2];
	assign RX_DATA_3 = rx_tdata_i[3];
	assign rx_rdy_0 = !system_reset_i[0] && channel_up_i[0] && rx_tvalid_i[0] ;
	assign rx_rdy_1 = !system_reset_i[1] && channel_up_i[1] && rx_tvalid_i[1] ;
	assign rx_rdy_2 = !system_reset_i[2] && channel_up_i[2] && rx_tvalid_i[2] ;
	assign rx_rdy_3 = !system_reset_i[3] && channel_up_i[3] && rx_tvalid_i[3] ;

	wire RESET;
	assign RESET = ~RESET_N;

	assign USER_CLK_0 = user_clk_i[0];
	assign USER_RST_0 = system_reset_i[0];
	assign USER_RST_N_0 = !system_reset_i[0];
	assign USER_CLK_1 = user_clk_i[1];
	assign USER_RST_1 = system_reset_i[1];
	assign USER_RST_N_1 = !system_reset_i[1];
	assign USER_CLK_2 = user_clk_i[2];
	assign USER_RST_2 = system_reset_i[2];
	assign USER_RST_N_2 = !system_reset_i[2];
	assign USER_CLK_3 = user_clk_i[3];
	assign USER_RST_3 = system_reset_i[3];
	assign USER_RST_N_3 = !system_reset_i[3];

	wire PMA_INIT;
	assign PMA_INIT = !RESET_N;

	assign tx_tvalid_i[0] = tx_en_0;
	assign tx_rdy_0 = tx_tready_i[0] && channel_up_i[0] && !system_reset_i[0];
	assign tx_tdata_i[0] = TX_DATA_0;
	assign tx_tvalid_i[1] = tx_en_1;
	assign tx_rdy_1 = tx_tready_i[1] && channel_up_i[1] && !system_reset_i[1];
	assign tx_tdata_i[1] = TX_DATA_1;
	assign tx_tvalid_i[2] = tx_en_2;
	assign tx_rdy_2 = tx_tready_i[2] && channel_up_i[2] && !system_reset_i[2];
	assign tx_tdata_i[2] = TX_DATA_2;
	assign tx_tvalid_i[3] = tx_en_3;
	assign tx_rdy_3 = tx_tready_i[3] && channel_up_i[3] && !system_reset_i[3];
	assign tx_tdata_i[3] = TX_DATA_3;

	wire [0:CORE_COUNT] RXP;
	wire [0:CORE_COUNT] RXN;
	wire [0:CORE_COUNT] TXP;
	wire [0:CORE_COUNT] TXN;
	assign TXP_0 = TXP[0]; assign TXN_0 = TXN[0];
	assign RXP[0] = RXP_0; assign RXN[0] = RXN_0;
	assign TXP_1 = TXP[1]; assign TXN_1 = TXN[1];
	assign RXP[1] = RXP_1; assign RXN[1] = RXN_1;
	assign TXP_2 = TXP[2]; assign TXN_2 = TXN[2];
	assign RXP[2] = RXP_2; assign RXN[2] = RXN_2;
	assign TXP_3 = TXP[3]; assign TXN_3 = TXN[3];
	assign RXP[3] = RXP_3; assign RXN[3] = RXN_3;

 //************************External Register Declarations*****************************

	//Error reporting signals
	reg                  HARD_ERR[0:CORE_COUNT];
	reg                  SOFT_ERR[0:CORE_COUNT];
	(* KEEP = "TRUE" *)       reg       [0:7]      DATA_ERR_COUNT[0:CORE_COUNT];
	assign HARD_ERR_0 = HARD_ERR[0];
	assign HARD_ERR_1 = HARD_ERR[1];
	assign HARD_ERR_2 = HARD_ERR[2];
	assign HARD_ERR_3 = HARD_ERR[3];

	assign SOFT_ERR_0 = SOFT_ERR[0];
	assign SOFT_ERR_1 = SOFT_ERR[1];
	assign SOFT_ERR_2 = SOFT_ERR[2];
	assign SOFT_ERR_3 = SOFT_ERR[3];
	assign DATA_ERR_COUNT_0 = DATA_ERR_COUNT[0];
	assign DATA_ERR_COUNT_1 = DATA_ERR_COUNT[1];
	assign DATA_ERR_COUNT_2 = DATA_ERR_COUNT[2];
	assign DATA_ERR_COUNT_3 = DATA_ERR_COUNT[3];

	//Global signals
	reg                  LANE_UP[0:CORE_COUNT];
	reg                  CHANNEL_UP[0:CORE_COUNT];
	assign LANE_UP_0 = LANE_UP[0];
	assign LANE_UP_1 = LANE_UP[1];
	assign LANE_UP_2 = LANE_UP[2];
	assign LANE_UP_3 = LANE_UP[3];
	assign CHANNEL_UP_0 = CHANNEL_UP[0];
	assign CHANNEL_UP_1 = CHANNEL_UP[1];
	assign CHANNEL_UP_2 = CHANNEL_UP[2];
	assign CHANNEL_UP_3 = CHANNEL_UP[3];

 //********************************Wire Declarations**********************************
 //
	// TX Interface
	(* mark_debug = "true" *)       wire      [0:63]     tx_tdata_i[0:CORE_COUNT]; 
	(* mark_debug = "true" *)       wire      [0:CORE_COUNT]           tx_tvalid_i;
	(* mark_debug = "true" *)       wire      [0:CORE_COUNT]           tx_tready_i;

	// RX Interface
	(* mark_debug = "true" *)       wire      [0:63]      rx_tdata_i[0:CORE_COUNT];  
	(* mark_debug = "true" *)       wire      [0:CORE_COUNT]           rx_tvalid_i;

	//Error Detection Interface
	(* mark_debug = "true" *)       wire [0:CORE_COUNT] hard_err_i;
	(* mark_debug = "true" *)       wire [0:CORE_COUNT] soft_err_i;
	//Status
	(* mark_debug = "true" *)       wire [0:CORE_COUNT] channel_up_i;
	(* mark_debug = "true" *)       wire [0:CORE_COUNT] lane_up_i;


	//System Interface
//	wire     [0:CORE_COUNT]            reset_i;
	wire                 gt_rxcdrovrden_i ;
	wire                 powerdown_i ;
	wire      [2:0]      loopback_i ;
	(* mark_debug = "true" *)       wire                 fsm_resetdone_i ;

	// Error signals from the frame checker
	(* KEEP = "TRUE" *) (* mark_debug = "true" *)       wire      [0:7]       data_err_count_o;
	(* mark_debug = "true" *)       wire                  data_err_init_clk_i;


	// clock
	(* KEEP = "TRUE" *) wire [0:CORE_COUNT]   user_clk_i;
	(* KEEP = "TRUE" *) wire               INIT_CLK_i;

////       wire                 gt_pll_lock_i ;   // gonna be removed
////       wire                 tx_out_clk_i ;

////     wire               drp_clk_i = INIT_CLK_i;
////     wire    [8:0] drpaddr_in_i;
////     wire    [15:0]     drpdi_in_i;
////       wire    [15:0]     drpdo_out_i;
////       wire               drprdy_out_i;
////       wire               drpen_in_i;
////       wire               drpwe_in_i;
////       wire    [7:0]      qpll_drpaddr_in_i;
////       wire    [15:0]     qpll_drpdi_in_i;
////       wire    [15:0]     qpll_drpdo_out_i;
////       wire               qpll_drprdy_out_i;
////       wire               qpll_drpen_in_i;
////       wire               qpll_drpwe_in_i;
////       wire    [31:0]     s_axi_awaddr_i;
////       wire    [31:0]     s_axi_araddr_i;
////       wire    [31:0]     s_axi_wdata_i;
////       wire    [3:0]     s_axi_wstrb_i;
////       wire    [31:0]     s_axi_rdata_i;
////       wire               s_axi_awvalid_i;
////       wire               s_axi_arvalid_i;
////       wire               s_axi_wvalid_i;
////       wire               s_axi_rvalid_i;
////       wire               s_axi_bvalid_i;
////       wire    [1:0]      s_axi_bresp_i;
////       wire    [1:0]      s_axi_rresp_i;
////       wire               s_axi_bready_i;
////       wire               s_axi_awready_i;
////       wire               s_axi_arready_i;
////       wire               s_axi_wready_i;
////       wire               s_axi_rready_i;
////       wire               link_reset_i;
////       wire               sysreset_from_vio_i;
////       wire               gtreset_from_vio_i;
////       wire               rx_cdrovrden_i;
////       wire               gt_reset_i;
////       wire               gt_reset_i_tmp;
////       wire               gt_reset_i_tmp2;
////       wire               sysreset_from_vio_r3;
////       wire               sysreset_from_vio_r3_initclkdomain;
////       wire               gtreset_from_vio_r3;
////       wire               tied_to_ground_i;
////       wire               tied_to_vcc_i;
////       wire               gt_reset_i_eff;
////       wire               system_reset_i;
////       wire                          pll_not_locked_i;
 
///reg  pma_init_from_fsm = 0;
///reg pma_init_from_fsm_r1 = 0;
///reg lane_up_vio_usrclk_r1 = 0;
///reg data_err_count_o_r1  = 0;
///
///     wire reset2FrameGenCheck;
///
///
/// //*********************************Main Body of Code**********************************
///     assign reset2FrameGenCheck = reset_i | !channel_up_i;



//--- Instance of GT differential buffer ---------//

     //____________________________Register User I/O___________________________________

     // Register User Outputs from core.
	always @(posedge user_clk_i[0]) // currently all user_clk_i s are same
	begin
		HARD_ERR[0]         <=  hard_err_i[0];
		SOFT_ERR[0]         <=  soft_err_i[0];
		LANE_UP[0]          <=  lane_up_i[0];
		CHANNEL_UP[0]       <=  channel_up_i[0];
		DATA_ERR_COUNT[0]   <=  data_err_count_o[0];


		HARD_ERR[1]         <=  hard_err_i[1];
		SOFT_ERR[1]         <=  soft_err_i[1];
		LANE_UP[1]          <=  lane_up_i[1];
		CHANNEL_UP[1]       <=  channel_up_i[1];
		DATA_ERR_COUNT[1]   <=  data_err_count_o[1];

		HARD_ERR[2]         <=  hard_err_i[2];
		SOFT_ERR[2]         <=  soft_err_i[2];
		LANE_UP[2]          <=  lane_up_i[2];
		CHANNEL_UP[2]       <=  channel_up_i[2];
		DATA_ERR_COUNT[2]   <=  data_err_count_o[2];
		
		HARD_ERR[3]         <=  hard_err_i[3];
		SOFT_ERR[3]         <=  soft_err_i[3];
		LANE_UP[3]          <=  lane_up_i[3];
		CHANNEL_UP[3]       <=  channel_up_i[3];
		DATA_ERR_COUNT[3]   <=  data_err_count_o[3];
	end
//	assign  reset_i[0]  =   system_reset_i[0];
//	assign  reset_i[1]  =   system_reset_i[1];
//	assign  reset_i[2]  =   system_reset_i[2];
//	assign  reset_i[3]  =   system_reset_i[3];

     //____________________________Register User I/O___________________________________

	// System Interface
	wire tied_to_ground_i;
	wire tied_to_vcc_i;
	wire [280:0] tied_to_ground_vec_i;
     assign  power_down_i      =   1'b0;
     assign tied_to_ground_i   =   1'b0;
     assign tied_to_ground_vec_i = 281'd0;
     assign tied_to_vcc_i      =   1'b1;

////    // AXI4 Lite Interface
////     assign  s_axi_awaddr_i    =  32'h0;
////     assign  s_axi_wdata_i     =  16'h0;
////     assign  s_axi_wstrb_i     =  4'h0;
////     assign  s_axi_araddr_i    =  32'h0;
////     assign  s_axi_awvalid_i   =  1'b0;
////     assign  s_axi_wvalid_i    =  1'b0;
////     assign  s_axi_arvalid_i   =  1'b0;
////     assign  s_axi_rvalid_i    =  1'b0;
////     assign  s_axi_rready_i    =  1'b0;
////     assign  s_axi_bready_i    =  1'b0;
////
////
////     assign  qpll_drpaddr_in_i   =  8'h0;
////     assign  qpll_drpdi_in_i     =  16'h0;
////     assign  qpll_drpen_in_i    =  1'b0;
////     assign  qpll_drpwe_in_i    =  1'b0;

   reg [127:0]        pma_init_stage = 128'h0;
   (* mark_debug = "TRUE" *) (* KEEP = "TRUE" *) reg [23:0]         pma_init_pulse_width_cnt;
   reg pma_init_assertion = 1'b0;
   reg pma_init_assertion_r;
   reg gt_reset_i_delayed_r1;
   (* mark_debug = "TRUE" *)  reg gt_reset_i_delayed_r2;
   wire gt_reset_i_delayed;

   generate
        always @(posedge INIT_CLK_i)
        begin
            pma_init_stage[127:0] <= {pma_init_stage[126:0], gt_reset_i_tmp};
        end

        assign gt_reset_i_delayed = pma_init_stage[127];

        always @(posedge INIT_CLK_i)
        begin
            gt_reset_i_delayed_r1     <=  gt_reset_i_delayed;
            gt_reset_i_delayed_r2     <=  gt_reset_i_delayed_r1;
            pma_init_assertion_r  <= pma_init_assertion;
            if(~gt_reset_i_delayed_r2 & gt_reset_i_delayed_r1 & ~pma_init_assertion & (pma_init_pulse_width_cnt != 24'hFFFFFF))
                pma_init_assertion <= 1'b1;
            else if (pma_init_assertion & pma_init_pulse_width_cnt == 24'hFFFFFF)
                pma_init_assertion <= 1'b0;

            if(pma_init_assertion)
                pma_init_pulse_width_cnt <= pma_init_pulse_width_cnt + 24'h1;
        end

    //assign gt_reset_i_eff = pma_init_assertion ? 1'b1 : gt_reset_i_delayed;
	assign gt_reset_i_eff = gt_reset_i_delayed;
     
     assign  gt_reset_i_tmp = PMA_INIT;
     //assign  reset_i  =   RESET | gt_reset_i_tmp2;
     assign  gt_reset_i = gt_reset_i_eff;
     assign  gt_rxcdrovrden_i  =  1'b0;
     assign  loopback_i  =  3'b000;

//     if(!USE_LABTOOLS)
//     begin
//aurora_64b66b_rst_sync_exdes   u_rst_sync_gtrsttmpi
//     (
//       .prmry_in     (gt_reset_i_tmp),
//       .scndry_aclk  (user_clk_i),
//       .scndry_out   (gt_reset_i_tmp2)
//      );
//     end

     endgenerate

     //___________________________Module Instantiations_________________________________

// this is non shared mode, the clock, GT common are part of example design.
    aurora_64b66b_support #
	(
		.CORE_COUNT(CORE_COUNT)
	)
	aurora_64b66b_block_i
     (
        // TX AXI4-S Interface
        // RX AXI4-S Interface
	 .s_axi_tx_tdata0(tx_tdata_i[0]),
	 .m_axi_rx_tdata0(rx_tdata_i[0]),
	 .s_axi_tx_tdata1(tx_tdata_i[1]),
	 .m_axi_rx_tdata1(rx_tdata_i[1]),
	 .s_axi_tx_tdata2(tx_tdata_i[2]),
	 .m_axi_rx_tdata2(rx_tdata_i[2]),
	 .s_axi_tx_tdata3(tx_tdata_i[3]),
	 .m_axi_rx_tdata3(rx_tdata_i[3]),

	 .s_axi_tx_tvalid(tx_tvalid_i),
	 .s_axi_tx_tready(tx_tready_i),
	 .m_axi_rx_tvalid(rx_tvalid_i),

        // GT Serial I/O
         .rxp(RXP),
         .rxn(RXN),

         .txp(TXP),
         .txn(TXN),


        //GT Reference Clock Interface
	.refclk1_in (GTX_CLK), 

        // Error Detection Interface
         .hard_err              (hard_err_i),
         .soft_err              (soft_err_i),

        // Status
         .channel_up            (channel_up_i),
         .lane_up               (lane_up_i),

        // System Interface
         .init_clk_out          (INIT_CLK_i),
         .user_clk_out          (user_clk_i),

////         .sync_clk_out(sync_clk_i),
////	.reset(reset_i),
         .reset_pb(RESET), // originally reset_i
         .gt_rxcdrovrden_in(gt_rxcdrovrden_i),
         .power_down(power_down_i),
         .loopback(loopback_i),
         .pma_init(gt_reset_i),
         .drp_clk_in(tied_to_ground_i), // originally DRP_CLK_IN

////     // ---------- AXI4-Lite input signals ---------------
////         .s_axi_awaddr(s_axi_awaddr_i),
////         .s_axi_awvalid(s_axi_awvalid_i),
////         .s_axi_awready(s_axi_awready_i),
////         .s_axi_wdata(s_axi_wdata_i),
////         .s_axi_wstrb(s_axi_wstrb_i),
////         .s_axi_wvalid(s_axi_wvalid_i),
////         .s_axi_wready(s_axi_wready_i),
////         .s_axi_bvalid(s_axi_bvalid_i),
////         .s_axi_bresp(s_axi_bresp_i),
////         .s_axi_bready(s_axi_bready_i),
////         .s_axi_araddr(s_axi_araddr_i),
////         .s_axi_arvalid(s_axi_arvalid_i),
////         .s_axi_arready(s_axi_arready_i),
////         .s_axi_rdata(s_axi_rdata_i),
////         .s_axi_rvalid(s_axi_rvalid_i),
////         .s_axi_rresp(s_axi_rresp_i),
////         .s_axi_rready(s_axi_rready_i),
////
////
////    //---------------------- GTXE2 COMMON DRP Ports ----------------------
////         .qpll_drpaddr_in(qpll_drpaddr_in_i),
////         .qpll_drpdi_in(qpll_drpdi_in_i),
////         .qpll_drpdo_out     (qpll_drpdo_out_i),
////         .qpll_drprdy_out    (qpll_drprdy_out_i),
////         .qpll_drpen_in      (qpll_drpen_in_i),
////         .qpll_drpwe_in      (qpll_drpwe_in_i),
////         .init_clk_p                            (INIT_CLK_P),
////         .init_clk_n                            (INIT_CLK_N),
////         .link_reset_out                        (link_reset_i),
////         .mmcm_not_locked_out                   (pll_not_locked_i),

		.init_clk_in(INIT_CLK_IN),
         .sys_reset_out                            (system_reset_i)
////         .tx_out_clk                               (tx_out_clk_i)
     );

////generate
//// if (USE_CORE_TRAFFIC==1)
//// begin : core_traffic
////
////     //_____________________________ TX AXI SHIM _______________________________
////aurora_64b66b_EXAMPLE_LL_TO_AXI #
////     (
////        .DATA_WIDTH(64),
////        .STRB_WIDTH(8),
////        .USE_4_NFC (0),
////        .REM_WIDTH (3)
////     )
////
////     frame_gen_ll_to_axi_data_i
////     (
////      // LocalLink input Interface
////      .LL_IP_DATA(tx_d_i),
////      .LL_IP_SOF_N(),
////      .LL_IP_EOF_N(),
////      .LL_IP_REM(),
////      .LL_IP_SRC_RDY_N(tx_src_rdy_n_i),
////      .LL_OP_DST_RDY_N(tx_dst_rdy_n_i),
////
////      // AXI4-S output signals
////      .AXI4_S_OP_TVALID(tx_tvalid_i),
////      .AXI4_S_OP_TDATA(tx_tdata_i),
////      .AXI4_S_OP_TKEEP(),
////      .AXI4_S_OP_TLAST(),
////      .AXI4_S_IP_TREADY(tx_tready_i)
////     );
////
////
////
////
////
////    // Frame Generator to provide with input to TX_Stream
////aurora_64b66b_FRAME_GEN frame_gen_i
////    (
////         .TX_D(tx_d_i),
////         .TX_SRC_RDY_N(tx_src_rdy_n_i),
////         .TX_DST_RDY_N(tx_dst_rdy_n_i),
////
////
////
////
////         .CHANNEL_UP(channel_up_i),
////         .USER_CLK(user_clk_i),
////         .RESET(reset2FrameGenCheck)
////    );
////
////     //_____________________________ RX AXI SHIM _______________________________
////aurora_64b66b_EXAMPLE_AXI_TO_LL #
////     (
////        .DATA_WIDTH(64),
////        .STRB_WIDTH(8),
////        .ISUFC(0),
////        .REM_WIDTH (3)
////     )
////     frame_chk_axi_to_ll_data_i
////     (
////      // AXI4-S input signals
////      .AXI4_S_IP_TX_TVALID(rx_tvalid_i),
////      .AXI4_S_IP_TX_TREADY(),
////      .AXI4_S_IP_TX_TDATA(rx_tdata_i),
////      .AXI4_S_IP_TX_TKEEP(),
////      .AXI4_S_IP_TX_TLAST(),
////
////      // LocalLink output Interface
////      .LL_OP_DATA(rx_d_i),
////      .LL_OP_SOF_N(),
////      .LL_OP_EOF_N() ,
////      .LL_OP_REM() ,
////      .LL_OP_SRC_RDY_N(rx_src_rdy_n_i),
////      .LL_IP_DST_RDY_N(1'b0),
////
////      // System Interface
////      .USER_CLK(user_clk_i),
////      .RESET(reset2FrameGenCheck),
////      .CHANNEL_UP(channel_up_i)
////      );
////
////
////
////    // Frame Checker to check output from RX_Stream
////aurora_64b66b_FRAME_CHECK frame_check_i
////    (
////         .RX_D(rx_d_i),
////         .RX_SRC_RDY_N(rx_src_rdy_n_i),
////         .DATA_ERR_COUNT(data_err_count_o),
////
////
////
////         .CHANNEL_UP(channel_up_i),
////         .USER_CLK(user_clk_i),
////         .RESET(reset2FrameGenCheck)
////    );
//// end //end USE_CORE_TRAFFIC=1 block
//// else
//// begin: no_traffic
////     //define traffic generation modules here
//// end //end USE_CORE_TRAFFIC=0 block
////
////endgenerate //End generate for USE_CORE_TRAFFIC
 
//------------------------------------------------------------------------------
 endmodule
