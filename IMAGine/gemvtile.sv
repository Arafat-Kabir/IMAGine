/*********************************************************************************
* Copyright (c) 2024, Computer Systems Design Lab, University of Arkansas        *
*                                                                                *
* All rights reserved.                                                           *
*                                                                                *
* Permission is hereby granted, free of charge, to any person obtaining a copy   *
* of this software and associated documentation files (the "Software"), to deal  *
* in the Software without restriction, including without limitation the rights   *
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell      *
* copies of the Software, and to permit persons to whom the Software is          *
* furnished to do so, subject to the following conditions:                       *
*                                                                                *
* The above copyright notice and this permission notice shall be included in all *
* copies or substantial portions of the Software.                                *
*                                                                                *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR     *
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,       *
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE    *
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         *
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  *
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  *
* SOFTWARE.                                                                      *
**********************************************************************************

==================================================================================

  Author : MD Arafat Kabir
  Email  : arafat.sun@gmail.com
  Date   : Thu, Feb 08, 03:22 PM CST 2024
  Version: v1.0

  Description:
  This is the GEMV tile as described in the FCCM-2024 draft. The controller is
  connected to a picaso array. There may or may not have pipeline stagest between
. the controller and the array.

================================================================================*/





`timescale 1ns/100ps


// (* black_box = "yes" *)            // for RTL elaboration in vivado
module gemvtile # (
  parameter DEBUG = 1,
  parameter ROW_CNT = 2,         // No. of PiCaSO rows
  parameter COL_CNT = 8,         // No. of PiCaSO columns
  parameter START_ROW_ID = 0,    // ROW-ID of the top row
  parameter START_COL_ID = 0     // COL-ID of the left column
) (
  clk,
  instruction,
  token_in,
  inputValid,
  busy,
  eastIn,
  westOut,
  serialOut,
  serialOutValid
);

  `include "gemvtile.svh"

  localparam  CTRL_STAGES   = 0;    // no. of pipeline stages to use
  localparam  ARR_ROW_CNT   = ROW_CNT,
              ARR_COL_CNT   = COL_CNT;


  // -- Module IOs
  input                          clk;
  // picaso-controller
  input  [CTRL_INSTR_WIDTH-1:0]  instruction;
  input  [CTRL_TOKEN_WIDTH-1:0]  token_in;
  input                          inputValid;
  output                         busy;
  // picaso-array
  input  [NET_STREAM_WIDTH-1:0]  eastIn[ARR_ROW_CNT];
  output [NET_STREAM_WIDTH-1:0]  westOut[ARR_ROW_CNT];
  output                         serialOut[ARR_ROW_CNT];
  output                         serialOutValid[ARR_ROW_CNT];


  // -- Instantiating PiCaSO 2D array
  // array IOs
  wire  [NET_LEVEL_WIDTH-1:0]  arr2D_netLevel;
  wire                         arr2D_netConfLoad;
  wire                         arr2D_netCaptureEn;

  wire  [ALU_OP_WIDTH-1:0]     arr2D_aluConf;
  wire                         arr2D_aluConfLoad;
  wire                         arr2D_aluEn;
  wire                         arr2D_aluReset;
  wire                         arr2D_aluMbitReset;
  wire                         arr2D_aluMbitLoad;

  wire                         arr2D_opmuxConfLoad;
  wire  [OPMUX_CONF_WIDTH-1:0] arr2D_opmuxConf;
  wire                         arr2D_opmuxEn;

  wire                         arr2D_extDataSave;
  wire [REGFILE_RAM_WIDTH-1:0] arr2D_extDataIn;

  wire                           arr2D_saveAluOut;
  wire  [REGFILE_ADDR_WIDTH-1:0] arr2D_addrA;
  wire  [REGFILE_ADDR_WIDTH-1:0] arr2D_addrB;

  wire [NET_STREAM_WIDTH-1:0]    arr2D_eastIn[ARR_ROW_CNT];
  wire [NET_STREAM_WIDTH-1:0]    arr2D_westOut[ARR_ROW_CNT];
  wire                           arr2D_serialOut[ARR_ROW_CNT];
  wire                           arr2D_serialOutValid[ARR_ROW_CNT];

  wire  [ID_WIDTH-1:0]         arr2D_selRow;
  wire  [ID_WIDTH-1:0]         arr2D_selCol;
  wire  [SEL_MODE_WIDTH-1:0]   arr2D_selMode;
  wire                         arr2D_selEn;
  wire                         arr2D_selOp;

  wire                         arr2D_ptrLoad;
  wire                         arr2D_ptrIncr;


  picaso_array #(
          .DEBUG(DEBUG),
          .ARR_ROW_CNT(ARR_ROW_CNT),
          .ARR_COL_CNT(ARR_COL_CNT),
          .START_ROW_ID(START_ROW_ID),
          .START_COL_ID(START_COL_ID),
          .NET_STREAM_WIDTH(NET_STREAM_WIDTH),
          .MAX_NET_LEVEL(MAX_NET_LEVEL),
          .ID_WIDTH(ID_WIDTH),
          .PE_CNT(PE_CNT),
          .RF_DEPTH(RF_DEPTH) )
      picaso_arr2D (
        .clk(clk),

        .netLevel(arr2D_netLevel),
        .netConfLoad(arr2D_netConfLoad),
        .netCaptureEn(arr2D_netCaptureEn),

        .aluConf(arr2D_aluConf),
        .aluConfLoad(arr2D_aluConfLoad),
        .aluEn(arr2D_aluEn),
        .aluReset(arr2D_aluReset),
        .aluMbitReset(arr2D_aluMbitReset),
        .aluMbitLoad(arr2D_aluMbitLoad),

        .opmuxConfLoad(arr2D_opmuxConfLoad),
        .opmuxConf(arr2D_opmuxConf),
        .opmuxEn(arr2D_opmuxEn),

        .extDataSave(arr2D_extDataSave),
        .extDataIn(arr2D_extDataIn),

        .saveAluOut(arr2D_saveAluOut),
        .addrA(arr2D_addrA),
        .addrB(arr2D_addrB),

        .selRow(arr2D_selRow),
        .selCol(arr2D_selCol),
        .selMode(arr2D_selMode),
        .selEn(arr2D_selEn),
        .selOp(arr2D_selOp),

        .ptrLoad(arr2D_ptrLoad),
        .ptrIncr(arr2D_ptrIncr),

        .eastIn(arr2D_eastIn),
        .westOut(arr2D_westOut),
        .serialOut(arr2D_serialOut),
        .serialOutValid(arr2D_serialOutValid)
      );



  // PiCaSO controller
  wire [CTRL_INSTR_WIDTH-1:0] ctrl_instruction;
  wire [CTRL_TOKEN_WIDTH-1:0] ctrl_token_in;
  wire                        ctrl_inputValid;
  wire [CTRL_TOKEN_WIDTH-1:0] ctrl_token_out;
  wire                        ctrl_busy;

  wire  [NET_LEVEL_WIDTH-1:0]  ctrl_pnetLevel;
  wire                         ctrl_pnetConfLoad;
  wire                         ctrl_pnetCaptureEn;

  wire  [ALU_OP_WIDTH-1:0]     ctrl_paluConf;
  wire                         ctrl_paluConfLoad;
  wire                         ctrl_paluEn;
  wire                         ctrl_paluReset;
  wire                         ctrl_paluMbitReset;
  wire                         ctrl_paluMbitLoad;

  wire                         ctrl_popmuxConfLoad;
  wire  [OPMUX_CONF_WIDTH-1:0] ctrl_popmuxConf;
  wire                         ctrl_popmuxEn;

  wire                         ctrl_pextDataSave;
  wire [REGFILE_RAM_WIDTH-1:0] ctrl_pextDataIn;

  wire                           ctrl_psaveAluOut;
  wire  [REGFILE_ADDR_WIDTH-1:0] ctrl_paddrA;
  wire  [REGFILE_ADDR_WIDTH-1:0] ctrl_paddrB;

  wire  [ID_WIDTH-1:0]         ctrl_pselRow;
  wire  [ID_WIDTH-1:0]         ctrl_pselCol;
  wire  [SEL_MODE_WIDTH-1:0]   ctrl_pselMode;
  wire                         ctrl_pselEn;
  wire                         ctrl_pselOp;

  wire                         ctrl_pptrLoad;
  wire                         ctrl_pptrIncr;


  (* keep_hierarchy = "yes" *)
  picaso_controller #(
      .DEBUG(DEBUG),
      .INSTRUCTION_WIDTH(CTRL_INSTR_WIDTH),
      .NET_LEVEL_WIDTH(NET_LEVEL_WIDTH),
      .OPERAND_WIDTH(PE_OPERAND_WIDTH),
      .PICASO_ID_WIDTH(ID_WIDTH),
      .TOKEN_WIDTH(CTRL_TOKEN_WIDTH),
      .PE_REG_WIDTH(PE_OPERAND_WIDTH),
      .MAX_PRECISION(MAX_PRECISION) )
    controller (
      .clk(clk),
      .instruction(ctrl_instruction),
      .token_in(ctrl_token_in),
      .inputValid(ctrl_inputValid),
      .token_out(ctrl_token_out),
      .busy(ctrl_busy),

      // PiCaSO control signals
      .picaso_netLevel(ctrl_pnetLevel),
      .picaso_netConfLoad(ctrl_pnetConfLoad),
      .picaso_netCaptureEn(ctrl_pnetCaptureEn),

      .picaso_aluConf(ctrl_paluConf),
      .picaso_aluConfLoad(ctrl_paluConfLoad),
      .picaso_aluEn(ctrl_paluEn),
      .picaso_aluReset(ctrl_paluReset),
      .picaso_aluMbitReset(ctrl_paluMbitReset),
      .picaso_aluMbitLoad(ctrl_paluMbitLoad),

      .picaso_opmuxConfLoad(ctrl_popmuxConfLoad),
      .picaso_opmuxConf(ctrl_popmuxConf),
      .picaso_opmuxEn(ctrl_popmuxEn),

      .picaso_extDataSave(ctrl_pextDataSave),
      .picaso_extDataIn(ctrl_pextDataIn),

      .picaso_saveAluOut(ctrl_psaveAluOut),
      .picaso_addrA(ctrl_paddrA),
      .picaso_addrB(ctrl_paddrB),

      .picaso_selRow(ctrl_pselRow),
      .picaso_selCol(ctrl_pselCol),
      .picaso_selMode(ctrl_pselMode),
      .picaso_selEn(ctrl_pselEn),
      .picaso_selOp(ctrl_pselOp),

      .picaso_ptrLoad(ctrl_pptrLoad),
      .picaso_ptrIncr(ctrl_pptrIncr),

      // debug probes
      .dbg_clk_enable(1'b1)
    );


    // Control Signal Pipeline
    wire ctrlsigs_t ctrlsigs_sigsIn;
    wire ctrlsigs_t ctrlsigs_sigsOut;


    _gemvtile_ctrlsig_pipe #(.STAGE_CNT(CTRL_STAGES))
      ctrlsigs (
        .clk(clk),
        .sigsIn(ctrlsigs_sigsIn),
        .sigsOut(ctrlsigs_sigsOut)
      );


    // -- Local interconnect
    // inputs to the controller
    assign ctrl_instruction = instruction,
           ctrl_token_in    = token_in,
           ctrl_inputValid  = inputValid;

    // inputs to pipelining module
    assign ctrlsigs_sigsIn.netLevel = ctrl_pnetLevel,
           ctrlsigs_sigsIn.netConfLoad = ctrl_pnetConfLoad,
           ctrlsigs_sigsIn.netCaptureEn = ctrl_pnetCaptureEn;

    assign ctrlsigs_sigsIn.aluConf = ctrl_paluConf,
           ctrlsigs_sigsIn.aluConfLoad = ctrl_paluConfLoad,
           ctrlsigs_sigsIn.aluEn = ctrl_paluEn,
           ctrlsigs_sigsIn.aluReset = ctrl_paluReset,
           ctrlsigs_sigsIn.aluMbitReset = ctrl_paluMbitReset,
           ctrlsigs_sigsIn.aluMbitLoad = ctrl_paluMbitLoad;

    assign ctrlsigs_sigsIn.opmuxConfLoad = ctrl_popmuxConfLoad,
           ctrlsigs_sigsIn.opmuxConf = ctrl_popmuxConf,
           ctrlsigs_sigsIn.opmuxEn = ctrl_popmuxEn;

    assign ctrlsigs_sigsIn.extDataSave = ctrl_pextDataSave,
           ctrlsigs_sigsIn.extDataIn = ctrl_pextDataIn;

    assign ctrlsigs_sigsIn.saveAluOut = ctrl_psaveAluOut,
           ctrlsigs_sigsIn.addrA = ctrl_paddrA,
           ctrlsigs_sigsIn.addrB = ctrl_paddrB;

    assign ctrlsigs_sigsIn.selRow = ctrl_pselRow,
           ctrlsigs_sigsIn.selCol = ctrl_pselCol,
           ctrlsigs_sigsIn.selMode = ctrl_pselMode,
           ctrlsigs_sigsIn.selEn = ctrl_pselEn,
           ctrlsigs_sigsIn.selOp = ctrl_pselOp;

    assign ctrlsigs_sigsIn.ptrLoad = ctrl_pptrLoad,
           ctrlsigs_sigsIn.ptrIncr = ctrl_pptrIncr;

    // Inputs to arr2D
    assign arr2D_netLevel = ctrlsigs_sigsOut.netLevel,
           arr2D_netConfLoad = ctrlsigs_sigsOut.netConfLoad,
           arr2D_netCaptureEn = ctrlsigs_sigsOut.netCaptureEn;

    assign arr2D_aluConf = ctrlsigs_sigsOut.aluConf,
           arr2D_aluConfLoad = ctrlsigs_sigsOut.aluConfLoad,
           arr2D_aluEn = ctrlsigs_sigsOut.aluEn,
           arr2D_aluReset = ctrlsigs_sigsOut.aluReset,
           arr2D_aluMbitReset = ctrlsigs_sigsOut.aluMbitReset,
           arr2D_aluMbitLoad = ctrlsigs_sigsOut.aluMbitLoad;

    assign arr2D_opmuxConfLoad = ctrlsigs_sigsOut.opmuxConfLoad,
           arr2D_opmuxConf = ctrlsigs_sigsOut.opmuxConf,
           arr2D_opmuxEn = ctrlsigs_sigsOut.opmuxEn;

    assign arr2D_extDataSave = ctrlsigs_sigsOut.extDataSave,
           arr2D_extDataIn = ctrlsigs_sigsOut.extDataIn;

    assign arr2D_saveAluOut = ctrlsigs_sigsOut.saveAluOut,
           arr2D_addrA = ctrlsigs_sigsOut.addrA,
           arr2D_addrB = ctrlsigs_sigsOut.addrB;

    assign arr2D_selRow = ctrlsigs_sigsOut.selRow,
           arr2D_selCol = ctrlsigs_sigsOut.selCol,
           arr2D_selMode = ctrlsigs_sigsOut.selMode,
           arr2D_selEn = ctrlsigs_sigsOut.selEn,
           arr2D_selOp = ctrlsigs_sigsOut.selOp;

    assign arr2D_ptrLoad = ctrlsigs_sigsOut.ptrLoad,
           arr2D_ptrIncr = ctrlsigs_sigsOut.ptrIncr;

    // Top-level IO
    assign busy = ctrl_busy;
    assign arr2D_eastIn = eastIn;
    assign westOut = arr2D_westOut;
    assign serialOut = arr2D_serialOut;
    assign serialOutValid = arr2D_serialOutValid;


endmodule



// Auxiliary module used for pipelining control signals from controller to PiCaSO Array
module _gemvtile_ctrlsig_pipe #(
  parameter STAGE_CNT = -1      // how many register stages to use, should be >= 0
) (
  clk,
  sigsIn,
  sigsOut
);

  // Validate parameters
  `AK_ASSERT2(STAGE_CNT>=0, STAGE_CNT__not_valid)

  `include "gemvtile.svh"


  // IO signals
  input  wire              clk;
  input  wire ctrlsigs_t   sigsIn;
  output wire ctrlsigs_t   sigsOut;


  // Pipeline stages
  (* max_fanout = 4 *)
  ctrlsigs_t stages[STAGE_CNT+1];     // input is stage-0, output is stage-N (total N+1)

  assign stages[0] = sigsIn;
  assign sigsOut   = stages[STAGE_CNT];

  always@(posedge clk) begin
    for(int i=1; i<=STAGE_CNT; ++i) begin
      stages[i] <= stages[i-1];
    end
  end


endmodule
