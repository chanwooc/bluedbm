
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
 //
 //  Description:  
 //                
 //                
 ///////////////////////////////////////////////////////////////////////////////
 `timescale 1 ns / 10 ps

(* DowngradeIPIdentifiedWarnings="yes" *)
 module aurora_64b66b_support #
 (
	 parameter CORE_COUNT = 3
 )
  (
     // TX AXI Interface 
     // RX AXI Interface 
	 input  [0:63]     s_axi_tx_tdata0, 
	 output [0:63]     m_axi_rx_tdata0, 
	 input  [0:63]     s_axi_tx_tdata1, 
	 output [0:63]     m_axi_rx_tdata1, 
	 
	 input  [0:63]     s_axi_tx_tdata2, 
	 output [0:63]     m_axi_rx_tdata2, 
	 input  [0:63]     s_axi_tx_tdata3, 
	 output [0:63]     m_axi_rx_tdata3, 

	 input [0:CORE_COUNT] s_axi_tx_tvalid,
	 output [0:CORE_COUNT] s_axi_tx_tready, 

	 output [0:CORE_COUNT] m_axi_rx_tvalid, 


 
 
     // GTX Serial I/O
	 input [0:CORE_COUNT]  rxp, 
	 input  [0:CORE_COUNT] rxn, 

	 output [0:CORE_COUNT] txp, 
	 output [0:CORE_COUNT] txn,

	 // Error Detection Interface
	 output [0:CORE_COUNT] hard_err, 
	 output [0:CORE_COUNT] soft_err, 

	 // Status
	 output [0:CORE_COUNT] channel_up, 
	 output [0:CORE_COUNT] lane_up,


	 // System Interface
	 output              init_clk_out, 
	 output [0:CORE_COUNT]  user_clk_out, 

	 //input  [0:CORE_COUNT]            reset, 
	 input              reset_pb, 

	 input              gt_rxcdrovrden_in, 

	 input              power_down, 
	 input   [2:0]      loopback,
	 input              pma_init, 
	 input    drp_clk_in,
 
     //-------------------- AXI4-Lite Interface -------------------------------
 
     //-------------------- Write Address Channel --------------------------
///       input  [31:0]   s_axi_awaddr,
///       input  [31:0]   s_axi_araddr,
///       input  [31:0]   s_axi_wdata,
///       input  [3:0]   s_axi_wstrb,
///       input           s_axi_awvalid, 
///       input           s_axi_rready, 
///       output  [31:0]  s_axi_rdata,
///       output          s_axi_awready,
///       output          s_axi_wready, 
///       output          s_axi_bvalid, 
///       output  [1:0]   s_axi_bresp, 
///       output  [1:0]   s_axi_rresp, 
///       input           s_axi_bready, 
///       output          s_axi_arready, 
///       output          s_axi_rvalid, 
///       input           s_axi_arvalid, 
///       input           s_axi_wvalid, 
    //---------------------- GTXE2 COMMON DRP Ports ----------------------
///       input   [7:0]   qpll_drpaddr_in,
///       input   [15:0]  qpll_drpdi_in,
///       input           qpll_drpen_in, 
///       input           qpll_drpwe_in, 
///       output  [15:0]  qpll_drpdo_out, 
///       output          qpll_drprdy_out, 
///       input               init_clk_p,
///       input               init_clk_n,
///       output              link_reset_out, 
///       output              gt_pll_lock, 
///       output              sys_reset_out,

    //---------------------- GTXE2 COMMON DRP Ports ----------------------
	 input               init_clk_in,
	 output [0:CORE_COUNT] sys_reset_out,

	 // GTX Reference Clock Interface
	 input              refclk1_in
 
///       input              gt_refclk1_p, 
///       input              gt_refclk1_n, 
/// 
///
///       output                 mmcm_not_locked_out,
///       output              tx_out_clk 
 );
 
 
 //***********************************Port Declarations*******************************
 
 
 //************************External Register Declarations*****************************
 
 
 //********************************Wire Declarations**********************************
	// clock
	(* KEEP = "TRUE" *) wire               INIT_CLK_i;
 
	wire [31:0]   s_axi_awaddr = 32'h0;
	wire  [31:0]   s_axi_araddr = 32'h0;
	wire  [31:0]   s_axi_wdata = 32'h0; // 16'h0 ?
	wire           s_axi_awvalid = 1'b0; 
	wire           s_axi_rready = 1'b0; 
	wire           s_axi_bready = 1'b0; 
	wire           s_axi_arvalid = 1'b0; 
	wire           s_axi_wvalid = 1'b0; 
	wire   [7:0]   qpll_drpaddr_in = 8'h0;
	wire   [15:0]  qpll_drpdi_in = 16'h0;
	wire           qpll_drpen_in = 1'b0; 
	wire           qpll_drpwe_in = 1'b0; 
	
	wire                     gt_qpllclk_quad1_i;
	wire                     gt_qpllrefclk_quad1_i;
	wire                     gt_to_common_qpllreset_i;
	wire [0:CORE_COUNT]      gt_to_common_qpllreset_v;
	wire                     gt_qpllrefclklost_i; 
	wire                     gt_qplllock_i; 


	assign gt_to_common_qpllreset_i =
		gt_to_common_qpllreset_v[3] |
		gt_to_common_qpllreset_v[2] |
		gt_to_common_qpllreset_v[1] |
		gt_to_common_qpllreset_v[0];

 
     //System Interface
///       wire                 mmcm_not_locked_i ; 
///       wire                 powerdown_i ; 
/// 
///       wire                  pma_init_i; 
///       wire                  pma_init_sync; 
 
  
     // clock
///       (* KEEP = "TRUE" *) wire               user_clk_i; 
///       (* KEEP = "TRUE" *) wire               sync_clk_i; 
///       (* KEEP = "TRUE" *) wire               GTXQ0_left_i; 
///       (* KEEP = "TRUE" *) wire               INIT_CLK_i  /* synthesis syn_keep = 1 */; 

///       wire               drp_clk_i;
///       wire    [8:0] drpaddr_in_i;
///       wire    [15:0]     drpdi_in_i;
///       wire    [15:0]     drpdo_out_i; 
///       wire               drprdy_out_i; 
///       wire               drpen_in_i; 
///       wire               drpwe_in_i; 
///       wire    [7:0]      qpll_drpaddr_in_i = 8'h0;
///       wire    [15:0]     qpll_drpdi_in_i;
///       wire    [15:0]     qpll_drpdo_out_i; 
///       wire               qpll_drprdy_out_i; 
///       wire               qpll_drpen_in_i; 
///       wire               qpll_drpwe_in_i; 
///       wire    [31:0]     s_axi_awaddr_i;
///       wire    [31:0]     s_axi_araddr_i;
///       wire    [31:0]     s_axi_wdata_i;
///       wire    [3:0]     s_axi_wstrb_i;
///       wire    [31:0]     s_axi_rdata_i;
///       wire               s_axi_awvalid_i; 
///       wire               s_axi_arvalid_i; 
///       wire               s_axi_wvalid_i; 
///       wire               s_axi_rvalid_i; 
///       wire               s_axi_bvalid_i; 
///       wire    [1:0]      s_axi_bresp_i; 
///       wire    [1:0]      s_axi_rresp_i; 
///       wire               s_axi_bready_i; 
///       wire               s_axi_awready_i; 
///       wire               s_axi_arready_i; 
///       wire               s_axi_wready_i; 
///       wire               s_axi_rready_i; 
///       wire               link_reset_i;
///       wire               sysreset_from_vio_i;
///       wire               gtreset_from_vio_i;
///       wire               rx_cdrovrden_i;
///       wire               gt_reset_i;
///       wire               gt_reset_i_tmp;
///
/////---{
///    wire                     gt_qpllclk_quad1_i;
///    wire                     gt_qpllrefclk_quad1_i;
///    wire                     gt_to_common_qpllreset_i;
///    wire                     gt_qpllrefclklost_i; 
///    wire                     gt_qplllock_i; 
/////---}
///    wire                     refclk1_in;
///    wire                     refclk2_in;
/// 
///    wire                     sysreset_from_support;
///      wire sysreset_to_core_sync;



 //*********************************Main Body of Code**********************************
 
 
 
     //___________________________Module Instantiations_________________________________
// to be shared with all Aurora Exts
aurora_64b66b_gt_common_wrapper gt_common_support
(
    .gt_qpllclk_quad1_out    (gt_qpllclk_quad1_i      ),
    .gt_qpllrefclk_quad1_out (gt_qpllrefclk_quad1_i   ),

         .GT0_GTREFCLK0_COMMON_IN             (refclk1_in), 

    //----------------------- Common Block - QPLL Ports ------------------------

    .GT0_QPLLLOCK_OUT (gt_qplllock_i),
    .GT0_QPLLRESET_IN (gt_to_common_qpllreset_i),

    .GT0_QPLLLOCKDETCLK_IN (INIT_CLK_i),

    .GT0_QPLLREFCLKLOST_OUT (gt_qpllrefclklost_i)


    //---------------------- Common DRP Ports ----------------------
///         .qpll_drpaddr_in (qpll_drpaddr_in),
///         .qpll_drpdi_in   (qpll_drpdi_in),
///         .qpll_drpclk_in  (drp_clk_in),
///         .qpll_drpdo_out (qpll_drpdo_out), 
///         .qpll_drprdy_out(qpll_drprdy_out), 
///         .qpll_drpen_in  (qpll_drpen_in), 
///         .qpll_drpwe_in  (qpll_drpwe_in)
);
     

//--- Instance of GT differential buffer ---------//
	BUFG initclk_bufg_i
	(
		.I  (init_clk_in),
		.O  (INIT_CLK_i)
	);


	wire                 mmcm_not_locked_i [0:CORE_COUNT]; 

	// Instantiate a clock module for clock division.
	// wjun: I need one for each core because
	// there are separate tx_out_clks
	(* KEEP = "TRUE" *) wire [0:CORE_COUNT] user_clk_i;
	(* KEEP = "TRUE" *) wire               sync_clk_i[0:CORE_COUNT]; 
	(* KEEP = "TRUE" *) wire [0:CORE_COUNT] gt_pll_lock; 
	(* KEEP = "TRUE" *) wire               tx_out_clk[0:CORE_COUNT]; 

	genvar coreidx;

	/*
	generate
	for ( coreidx = 0; coreidx < CORE_COUNT+1; coreidx=coreidx+1 )
	begin: gen_code_clock_module
	aurora_64b66b_clock_module clock_module_i
	(
		.CLK(tx_out_clk[coreidx]), //in
		.CLK_LOCKED(gt_pll_lock[coreidx]), //in
		.USER_CLK(user_clk_i[coreidx]), //out
		.SYNC_CLK(sync_clk_i[coreidx]), //out
		.MMCM_NOT_LOCKED(mmcm_not_locked_i[coreidx]) //out
	);
	end
	endgenerate
	*/

	aurora_64b66b_CLOCK_MODULE clock_module_i
	(
		.CLK(tx_out_clk[0]), //in
		.CLK_LOCKED(gt_pll_lock[0]), //in
		.USER_CLK(user_clk_i[0]), //out
		.SYNC_CLK(sync_clk_i[0]), //out
		.MMCM_NOT_LOCKED(mmcm_not_locked_i[0]) //out
	);

///	aurora_64b66b_CLOCK_MODULE clock_module_i
///     (
/// 
///         .INIT_CLK_P(init_clk_p),
///         .INIT_CLK_N(init_clk_n),
/// 
///         .INIT_CLK_O(INIT_CLK_i),
///         .CLK(tx_out_clk),
///         .CLK_LOCKED(gt_pll_lock),
///         .USER_CLK(user_clk_i),
///         .SYNC_CLK(sync_clk_i),
///         .MMCM_NOT_LOCKED(mmcm_not_locked_i)
///     );

  //  outputs
  assign init_clk_out          =  INIT_CLK_i;
	assign user_clk_out[0]          =  user_clk_i[0];
	assign user_clk_out[1]          =  user_clk_i[0];
	assign user_clk_out[2]          =  user_clk_i[0];
	assign user_clk_out[3]          =  user_clk_i[0];
///  assign user_clk_out          =  user_clk_i;
///  assign sync_clk_out          =  sync_clk_i;
///  assign mmcm_not_locked_out   =  mmcm_not_locked_i;
///  assign tx_lock               =  gt_pll_lock;

	// Instantiate reset module to generate system reset
	// wjun: 
	wire [0:CORE_COUNT] sysreset_from_support;
	wire [0:CORE_COUNT] pma_init_i; 
	generate
	for ( coreidx = 0; coreidx < CORE_COUNT+1; coreidx=coreidx+1 )
	begin: gen_code_reset_logic
	aurora_64b66b_SUPPORT_RESET_LOGIC support_reset_logic_i
	(
		.RESET(reset_pb), //in
		//.USER_CLK(user_clk_i[coreidx]), //in
		.USER_CLK(user_clk_i[0]), //in
		.INIT_CLK(INIT_CLK_i), //in
		.GT_RESET_IN(pma_init), //in
		.SYSTEM_RESET(sysreset_from_support[coreidx]), //out
		.GT_RESET_OUT(pma_init_i[coreidx]) //out
	);
	end
	endgenerate

  
//----- Instance of _xci -----[
	aurora_64b66b_X0Y0 aurora_64b66b_X0Y0_i
     (
        // TX AXI4-S Interface
         .s_axi_tx_tdata(s_axi_tx_tdata0),
         .s_axi_tx_tvalid(s_axi_tx_tvalid[0]),
         .s_axi_tx_tready(s_axi_tx_tready[0]),

        // RX AXI4-S Interface
         .m_axi_rx_tdata(m_axi_rx_tdata0),
         .m_axi_rx_tvalid(m_axi_rx_tvalid[0]),
  
         // GTX Serial I/O
         .rxp(rxp[0]),
         .rxn(rxn[0]),
         .txp(txp[0]),
         .txn(txn[0]),
 
         //GTX Reference Clock Interface
         .refclk1_in(refclk1_in),


         .hard_err(hard_err[0]),
         .soft_err(soft_err[0]),


         // Status
         .channel_up(channel_up[0]),
         .lane_up(lane_up[0]),

 
         // System Interface
         .mmcm_not_locked(mmcm_not_locked_i[0]),
         .user_clk(user_clk_i[0]),
         .sync_clk(sync_clk_i[0]),
         //.reset(reset[0]),
         .reset_pb(sysreset_from_support[0]),
         .gt_rxcdrovrden_in(gt_rxcdrovrden_in),
         .power_down(power_down),
         .loopback(loopback),
         .pma_init(pma_init_i[0]),
         .gt_pll_lock(gt_pll_lock[0]),
         .drp_clk_in(drp_clk_in),
//---{
       .gt_qpllclk_quad1_in        (gt_qpllclk_quad1_i         ),
       .gt_qpllrefclk_quad1_in     (gt_qpllrefclk_quad1_i      ),   

       .gt_to_common_qpllreset_out  (gt_to_common_qpllreset_v[0]    ),
       .gt_qplllock_in       (gt_qplllock_i        ), 
       .gt_qpllrefclklost_in (gt_qpllrefclklost_i  ),       
//---}
     // ---------- AXI4-Lite input signals ---------------
         .s_axi_awaddr(s_axi_awaddr),
         .s_axi_awvalid(s_axi_awvalid), 
         .s_axi_awready(), 
         .s_axi_wdata(s_axi_wdata),
		 .s_axi_wstrb(),
         .s_axi_wvalid(s_axi_wvalid), 
         .s_axi_wready(), 
         .s_axi_bvalid(), 
		 .s_axi_bresp(),
         .s_axi_bready(s_axi_bready), 
         .s_axi_araddr(s_axi_araddr),
         .s_axi_arvalid(s_axi_arvalid), 
         .s_axi_arready(), 
         .s_axi_rdata(),
         .s_axi_rvalid(), 
		 .s_axi_rresp(),
         .s_axi_rready(s_axi_rready), 
    //---------------------- GTXE2 COMMON DRP Ports ----------------------
         .qpll_drpaddr_in(qpll_drpaddr_in),
         .qpll_drpdi_in(qpll_drpdi_in),
         .qpll_drpdo_out(), 
         .qpll_drprdy_out(), 
         .qpll_drpen_in(qpll_drpen_in), 
         .qpll_drpwe_in(qpll_drpwe_in), 
         .init_clk(INIT_CLK_i),
         .link_reset_out(),
         .sys_reset_out(sys_reset_out[0]),
         .tx_out_clk(tx_out_clk[0])
     );
//----- Instance of _xci -----]

//----- Instance of _xci -----[
aurora_64b66b_X0Y1 aurora_64b66b_X0Y1_i
     (
        // TX AXI4-S Interface
         .s_axi_tx_tdata(s_axi_tx_tdata1), // in //separate
         .s_axi_tx_tvalid(s_axi_tx_tvalid[1]), // in //separate
         .s_axi_tx_tready(s_axi_tx_tready[1]), // out // separate

        // RX AXI4-S Interface
         .m_axi_rx_tdata(m_axi_rx_tdata1), //out separate
         .m_axi_rx_tvalid(m_axi_rx_tvalid[1]), //out separate
  
         // GTX Serial I/O
         .rxp(rxp[1]), //...
         .rxn(rxn[1]),
         .txp(txp[1]),
         .txn(txn[1]),
 
         //GTX Reference Clock Interface
         .refclk1_in(refclk1_in),

         .hard_err(hard_err[1]), // out, separate
         .soft_err(soft_err[1]), // out, separaate


         // Status
         .channel_up(channel_up[1]), // out, separate
         .lane_up(lane_up[1]), // out_separate

 
         // System Interface
		 /*
         .mmcm_not_locked(mmcm_not_locked_i[1]),
         .user_clk(user_clk_i[1]),
         .sync_clk(sync_clk_i[1]),
		 */
         .mmcm_not_locked(mmcm_not_locked_i[0]),
         .user_clk(user_clk_i[0]),
         .sync_clk(sync_clk_i[0]),

         //.reset(reset[1]),
         .reset_pb(sysreset_from_support[1]),
         .gt_rxcdrovrden_in(gt_rxcdrovrden_in),
         .power_down(power_down),
         .loopback(loopback),
         .pma_init(pma_init_i[1]),
         .gt_pll_lock(gt_pll_lock[1]),
         .drp_clk_in(drp_clk_in),
//---{
       .gt_qpllclk_quad1_in        (gt_qpllclk_quad1_i         ),
       .gt_qpllrefclk_quad1_in     (gt_qpllrefclk_quad1_i      ),   

       .gt_to_common_qpllreset_out  (gt_to_common_qpllreset_v[1]    ),
       .gt_qplllock_in       (gt_qplllock_i        ), 
       .gt_qpllrefclklost_in (gt_qpllrefclklost_i  ),       
//---}
     // ---------- AXI4-Lite input signals ---------------
         .s_axi_awaddr(s_axi_awaddr),
         .s_axi_awvalid(s_axi_awvalid), 
         .s_axi_awready(), 
         .s_axi_wdata(s_axi_wdata),
		 .s_axi_wstrb(),
         .s_axi_wvalid(s_axi_wvalid), 
         .s_axi_wready(), 
         .s_axi_bvalid(), 
		 .s_axi_bresp(),
         .s_axi_bready(s_axi_bready), 
         .s_axi_araddr(s_axi_araddr),
         .s_axi_arvalid(s_axi_arvalid), 
         .s_axi_arready(), 
         .s_axi_rdata(),
         .s_axi_rvalid(), 
		 .s_axi_rresp(),
         .s_axi_rready(s_axi_rready), 
    //---------------------- GTXE2 COMMON DRP Ports ----------------------
         .qpll_drpaddr_in(qpll_drpaddr_in),
         .qpll_drpdi_in(qpll_drpdi_in),
         .qpll_drpdo_out(), 
         .qpll_drprdy_out(), 
         .qpll_drpen_in(qpll_drpen_in), 
         .qpll_drpwe_in(qpll_drpwe_in), 
         .init_clk(INIT_CLK_i),
         .link_reset_out(),
         .sys_reset_out(sys_reset_out[1]),
         .tx_out_clk(tx_out_clk[1])
     );
//----- Instance of _xci -----]
//----- Instance of _xci -----[
aurora_64b66b_X0Y2 aurora_64b66b_X0Y2_i
     (
        // TX AXI4-S Interface
         .s_axi_tx_tdata(s_axi_tx_tdata2), // in //separate
         .s_axi_tx_tvalid(s_axi_tx_tvalid[2]), // in //separate
         .s_axi_tx_tready(s_axi_tx_tready[2]), // out // separate

        // RX AXI4-S Interface
         .m_axi_rx_tdata(m_axi_rx_tdata2), //out separate
         .m_axi_rx_tvalid(m_axi_rx_tvalid[2]), //out separate
  
         // GTX Serial I/O
         .rxp(rxp[2]), //...
         .rxn(rxn[2]),
         .txp(txp[2]),
         .txn(txn[2]),
 
         //GTX Reference Clock Interface
         .refclk1_in(refclk1_in),

         .hard_err(hard_err[2]), // out, separate
         .soft_err(soft_err[2]), // out, separaate


         // Status
         .channel_up(channel_up[2]), // out, separate
         .lane_up(lane_up[2]), // out_separate

 
         // System Interface
		 /*
         .mmcm_not_locked(mmcm_not_locked_i[2]),
         .user_clk(user_clk_i[2]),
         .sync_clk(sync_clk_i[2]),
		 */
         .mmcm_not_locked(mmcm_not_locked_i[0]),
         .user_clk(user_clk_i[0]),
         .sync_clk(sync_clk_i[0]),

         //.reset(reset[2]),
         .reset_pb(sysreset_from_support[2]),
         .gt_rxcdrovrden_in(gt_rxcdrovrden_in),
         .power_down(power_down),
         .loopback(loopback),
         .pma_init(pma_init_i[2]),
         .gt_pll_lock(gt_pll_lock[2]),
         .drp_clk_in(drp_clk_in),
//---{
       .gt_qpllclk_quad1_in        (gt_qpllclk_quad1_i         ),
       .gt_qpllrefclk_quad1_in     (gt_qpllrefclk_quad1_i      ),   

       .gt_to_common_qpllreset_out  (gt_to_common_qpllreset_v[2]    ),
       .gt_qplllock_in       (gt_qplllock_i        ), 
       .gt_qpllrefclklost_in (gt_qpllrefclklost_i  ),       
//---}
     // ---------- AXI4-Lite input signals ---------------
         .s_axi_awaddr(s_axi_awaddr),
         .s_axi_awvalid(s_axi_awvalid), 
         .s_axi_awready(), 
         .s_axi_wdata(s_axi_wdata),
		 .s_axi_wstrb(),
         .s_axi_wvalid(s_axi_wvalid), 
         .s_axi_wready(), 
         .s_axi_bvalid(), 
		 .s_axi_bresp(),
         .s_axi_bready(s_axi_bready), 
         .s_axi_araddr(s_axi_araddr),
         .s_axi_arvalid(s_axi_arvalid), 
         .s_axi_arready(), 
         .s_axi_rdata(),
         .s_axi_rvalid(), 
		 .s_axi_rresp(),
         .s_axi_rready(s_axi_rready), 
    //---------------------- GTXE2 COMMON DRP Ports ----------------------
         .qpll_drpaddr_in(qpll_drpaddr_in),
         .qpll_drpdi_in(qpll_drpdi_in),
         .qpll_drpdo_out(), 
         .qpll_drprdy_out(), 
         .qpll_drpen_in(qpll_drpen_in), 
         .qpll_drpwe_in(qpll_drpwe_in), 
         .init_clk(INIT_CLK_i),
         .link_reset_out(),
         .sys_reset_out(sys_reset_out[2]),
         .tx_out_clk(tx_out_clk[2])
     );
//----- Instance of _xci -----]
//----- Instance of _xci -----[
aurora_64b66b_X0Y3 aurora_64b66b_X0Y3_i
     (
        // TX AXI4-S Interface
         .s_axi_tx_tdata(s_axi_tx_tdata3), // in //separate
         .s_axi_tx_tvalid(s_axi_tx_tvalid[3]), // in //separate
         .s_axi_tx_tready(s_axi_tx_tready[3]), // out // separate

        // RX AXI4-S Interface
         .m_axi_rx_tdata(m_axi_rx_tdata3), //out separate
         .m_axi_rx_tvalid(m_axi_rx_tvalid[3]), //out separate
  
         // GTX Serial I/O
         .rxp(rxp[3]), //...
         .rxn(rxn[3]),
         .txp(txp[3]),
         .txn(txn[3]),
 
         //GTX Reference Clock Interface
         .refclk1_in(refclk1_in),

         .hard_err(hard_err[3]), // out, separate
         .soft_err(soft_err[3]), // out, separaate


         // Status
         .channel_up(channel_up[3]), // out, separate
         .lane_up(lane_up[3]), // out_separate

 
         // System Interface
		 /*
         .mmcm_not_locked(mmcm_not_locked_i[3]),
         .user_clk(user_clk_i[3]),
         .sync_clk(sync_clk_i[3]),
		 */
         .mmcm_not_locked(mmcm_not_locked_i[0]),
         .user_clk(user_clk_i[0]),
         .sync_clk(sync_clk_i[0]),

         //.reset(reset[3]),
         .reset_pb(sysreset_from_support[3]),
         .gt_rxcdrovrden_in(gt_rxcdrovrden_in),
         .power_down(power_down),
         .loopback(loopback),
         .pma_init(pma_init_i[3]),
         .gt_pll_lock(gt_pll_lock[3]),
         .drp_clk_in(drp_clk_in),
//---{
       .gt_qpllclk_quad1_in        (gt_qpllclk_quad1_i         ),
       .gt_qpllrefclk_quad1_in     (gt_qpllrefclk_quad1_i      ),   

       .gt_to_common_qpllreset_out  (gt_to_common_qpllreset_v[3]    ),
       .gt_qplllock_in       (gt_qplllock_i        ), 
       .gt_qpllrefclklost_in (gt_qpllrefclklost_i  ),       
//---}
     // ---------- AXI4-Lite input signals ---------------
         .s_axi_awaddr(s_axi_awaddr),
         .s_axi_awvalid(s_axi_awvalid), 
         .s_axi_awready(), 
         .s_axi_wdata(s_axi_wdata),
		 .s_axi_wstrb(),
         .s_axi_wvalid(s_axi_wvalid), 
         .s_axi_wready(), 
         .s_axi_bvalid(), 
		 .s_axi_bresp(),
         .s_axi_bready(s_axi_bready), 
         .s_axi_araddr(s_axi_araddr),
         .s_axi_arvalid(s_axi_arvalid), 
         .s_axi_arready(), 
         .s_axi_rdata(),
         .s_axi_rvalid(), 
		 .s_axi_rresp(),
         .s_axi_rready(s_axi_rready), 
    //---------------------- GTXE2 COMMON DRP Ports ----------------------
         .qpll_drpaddr_in(qpll_drpaddr_in),
         .qpll_drpdi_in(qpll_drpdi_in),
         .qpll_drpdo_out(), 
         .qpll_drprdy_out(), 
         .qpll_drpen_in(qpll_drpen_in), 
         .qpll_drpwe_in(qpll_drpwe_in), 
         .init_clk(INIT_CLK_i),
         .link_reset_out(),
         .sys_reset_out(sys_reset_out[3]),
         .tx_out_clk(tx_out_clk[3])
     );
//----- Instance of _xci -----]
//       assign sysreset_to_core_sync = reset_pb;
// 
//       assign pma_init_sync = pma_init;
//
//     // Instantiate reset module to generate system reset
//     aurora_64b66b_SUPPORT_RESET_LOGIC support_reset_logic_i
//     (
//         .RESET(reset_pb),
//         .USER_CLK(user_clk_i[0]),
//         .INIT_CLK(INIT_CLK_i),
//         .GT_RESET_IN(pma_init_sync),
//         .SYSTEM_RESET(sysreset_from_support),
//         .GT_RESET_OUT(pma_init_i)
//     );

/////----- Instance of _xci -----[
///aurora_64b66b aurora_64b66b_i
///     (
///        // TX AXI4-S Interface
///         .s_axi_tx_tdata(s_axi_tx_tdata),
///         .s_axi_tx_tvalid(s_axi_tx_tvalid),
///         .s_axi_tx_tready(s_axi_tx_tready),
///
/// 
///        // RX AXI4-S Interface
///         .m_axi_rx_tdata(m_axi_rx_tdata),
///         .m_axi_rx_tvalid(m_axi_rx_tvalid),
///  
///       
///
/// 
/// 
///         // GTX Serial I/O
///         .rxp(rxp),
///         .rxn(rxn),
///         .txp(txp),
///         .txn(txn),
/// 
///         //GTX Reference Clock Interface
///         .refclk1_in(refclk1_in),
///         .hard_err(hard_err),
///         .soft_err(soft_err),
///
///
///         // Status
///         .channel_up(channel_up),
///         .lane_up(lane_up),
///
/// 
///         // System Interface
///         .mmcm_not_locked(mmcm_not_locked_i),
///         .user_clk(user_clk_i),
///         .sync_clk(sync_clk_i),
///         .reset_pb(sysreset_from_support),
///         .gt_rxcdrovrden_in(gt_rxcdrovrden_in),
///         .power_down(power_down),
///         .loopback(loopback),
///         .pma_init(pma_init_i),
///         .gt_pll_lock(gt_pll_lock),
///         .drp_clk_in(drp_clk_in),
/////---{
///       .gt_qpllclk_quad1_in       (gt_qpllclk_quad1_i          ), 
///       .gt_qpllrefclk_quad1_in    (gt_qpllrefclk_quad1_i       ),    
///
///       .gt_to_common_qpllreset_out  (gt_to_common_qpllreset_i    ),
///       .gt_qplllock_in       (gt_qplllock_i        ), 
///       .gt_qpllrefclklost_in (gt_qpllrefclklost_i  ),       
/////---}
///     // ---------- AXI4-Lite input signals ---------------
///         .s_axi_awaddr(s_axi_awaddr),
///         .s_axi_awvalid(s_axi_awvalid), 
///         .s_axi_awready(s_axi_awready), 
///         .s_axi_wdata(s_axi_wdata),
///         .s_axi_wstrb(s_axi_wstrb),
///         .s_axi_wvalid(s_axi_wvalid), 
///         .s_axi_wready(s_axi_wready), 
///         .s_axi_bvalid(s_axi_bvalid), 
///         .s_axi_bresp(s_axi_bresp), 
///         .s_axi_bready(s_axi_bready), 
///         .s_axi_araddr(s_axi_araddr),
///         .s_axi_arvalid(s_axi_arvalid), 
///         .s_axi_arready(s_axi_arready), 
///         .s_axi_rdata(s_axi_rdata),
///         .s_axi_rvalid(s_axi_rvalid), 
///         .s_axi_rresp(s_axi_rresp), 
///         .s_axi_rready(s_axi_rready), 
///    //---------------------- GTXE2 COMMON DRP Ports ----------------------
///         .qpll_drpaddr_in(qpll_drpaddr_in),
///         .qpll_drpdi_in(qpll_drpdi_in),
///         .qpll_drpdo_out(), 
///         .qpll_drprdy_out(), 
///         .qpll_drpen_in(qpll_drpen_in), 
///         .qpll_drpwe_in(qpll_drpwe_in), 
///         .init_clk(INIT_CLK_i),
///         .link_reset_out(link_reset_out),
///         .sys_reset_out                            (sys_reset_out),
///         .tx_out_clk                               (tx_out_clk)
///     );
/////----- Instance of _xci -----]
 


 endmodule
