/*********************************************************************************
* Copyright (c) 2023, Computer Systems Design Lab, University of Arkansas        *
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
  Date   : Mon, Sep 04, 04:02 PM CST 2023
  Version: v1.0

  Description:
  This module decodes the instruction and generates the the control signals
  for multi-cycle instructions. This is basically a wrapper around algorithm
  FSM modules.

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module picaso_multicycle_driver #(
  parameter DEBUG = 1,
  parameter OPCODE_WIDTH = -1,
  parameter ADDR_WIDTH = -1,
  parameter DATA_WIDTH = -1,
  parameter REG_BASE_WIDTH = -1,
  parameter PICASO_ID_WIDTH = -1,
  parameter FN_WIDTH = -1,
  parameter OFFSET_WIDTH = -1,
  parameter INSTR_PARAM_WIDTH = -1,
  parameter NET_LEVEL_WIDTH = -1,
  parameter PE_REG_WIDTH = -1,
  parameter PRECISION_WIDTH = -1
) (
  clk,
  enTransition,     // enables state transitions
  selAlgo,          // selects a particular algorithm
  loadInit,         // loads initial values for algorithm FSMs
  precision,        // current precision for arithmetic computation
  algoDone,         // signals the end of multicycle algorithm 

  // fields from instruction word 
  opcode,
  addr,
  data,
  rd, rs1, rs2,
  rowID, colID,
  fncode,
  offset,
  param,

  // pre-decoded signals
  rs1_base,
  rs2_base,
  rd_base,
  rd_with_offset,
  rs1_with_offset,
  rs2_with_offset,
  rs1_with_param,
  rs2_with_param,
  rd_with_param,

  // picaso control signals
  sigNetLevel,
  sigNetConfLoad,
  sigNetCaptureEn,

  sigAluConf,
  sigAluConfLoad,
  sigAluEn,
  sigAluReset,
  sigAluMbitReset,
  sigAluMbitLoad,

  sigOpmuxConfLoad,
  sigOpmuxConf,
  sigOpmuxEn,

  sigExtDataSave,
  sigExtDataIn,

  sigSaveAluOut,
  sigAddrA,
  sigAddrB,
  sigPtrLoad,
  sigPtrIncr,

  sigSelRow,
  sigSelCol,
  sigSelMode,
  sigSelEn,
  sigSelOp,

  // Debug probes
  dbg_clk_enable         // debug clock for stepping
);

  `include "boothR2_serial_alu.inc.v"
  `include "alu_serial_unit.inc.v"
  `include "opmux_ff.inc.v"
  `include "picaso_ff.inc.v"
  `include "picaso_controller.inc.v"
  `include "picaso_algorithm_decoder.inc.v"
  `include "picaso_algorithm_fsm.inc.v"


  // make sure all parameters are explicitly specified
  `AK_ASSERT2(OPCODE_WIDTH >= 0, OPCODE_WIDTH_not_set)
  `AK_ASSERT2(ADDR_WIDTH >= 0, ADDR_WIDTH_not_set)
  `AK_ASSERT2(DATA_WIDTH >= 0, DATA_WIDTH_not_set)
  `AK_ASSERT2(REG_BASE_WIDTH >= 0, REG_BASE_WIDTH_not_set)
  `AK_ASSERT2(PICASO_ID_WIDTH >= 0, PICASO_ID_WIDTH_not_set)
  `AK_ASSERT2(FN_WIDTH >= 0, FN_WIDTH_not_set)
  `AK_ASSERT2(OFFSET_WIDTH >= 0, OFFSET_WIDTH_not_set)
  `AK_ASSERT2(INSTR_PARAM_WIDTH >= 0, INSTR_PARAM_WIDTH_not_set)
  `AK_ASSERT2(NET_LEVEL_WIDTH >= 0, NET_LEVEL_WIDTH_not_set)
  `AK_ASSERT2(PE_REG_WIDTH >= 0, PE_REG_WIDTH_not_set)


  // IO Ports
  input                            clk;
  input                            enTransition;
  input [ALGORITHM_SEL_WIDTH-1:0]  selAlgo;
  input                            loadInit;
  input [PRECISION_WIDTH-1:0]      precision;
  output                           algoDone;

  input [OPCODE_WIDTH-1:0]         opcode;
  input [ADDR_WIDTH-1:0]           addr;
  input [DATA_WIDTH-1:0]           data;
  input [REG_BASE_WIDTH-1:0]       rd, rs1, rs2;
  input [PICASO_ID_WIDTH-1:0]      rowID, colID;
  input [FN_WIDTH-1:0]             fncode;
  input [OFFSET_WIDTH-1:0]         offset;
  input [INSTR_PARAM_WIDTH-1:0]    param;

  input [ADDR_WIDTH-1:0]  rs1_base;
  input [ADDR_WIDTH-1:0]  rs2_base;
  input [ADDR_WIDTH-1:0]  rd_base;
  input [ADDR_WIDTH-1:0]  rd_with_offset;
  input [ADDR_WIDTH-1:0]  rs1_with_offset;
  input [ADDR_WIDTH-1:0]  rs2_with_offset;
  input [ADDR_WIDTH-1:0]  rs1_with_param;
  input [ADDR_WIDTH-1:0]  rs2_with_param;
  input [ADDR_WIDTH-1:0]  rd_with_param;

  output [NET_LEVEL_WIDTH-1:0]       sigNetLevel;
  output                             sigNetConfLoad;
  output                             sigNetCaptureEn;

  output [ALU_OP_WIDTH-1:0]          sigAluConf;
  output                             sigAluConfLoad;
  output                             sigAluEn;
  output                             sigAluReset;
  output                             sigAluMbitReset;
  output                             sigAluMbitLoad;

  output                             sigOpmuxConfLoad;
  output [OPMUX_CONF_WIDTH-1:0]      sigOpmuxConf;
  output                             sigOpmuxEn;

  output                             sigExtDataSave;
  output     [DATA_WIDTH-1:0]        sigExtDataIn;

  output                             sigSaveAluOut;
  output     [ADDR_WIDTH-1:0]        sigAddrA;
  output     [ADDR_WIDTH-1:0]        sigAddrB;
  output                             sigPtrLoad;
  output                             sigPtrIncr;

  output     [PICASO_ID_WIDTH-1:0]       sigSelRow;  // defined reg for behavioral modeling
  output     [PICASO_ID_WIDTH-1:0]       sigSelCol;
  output     [PICASO_SEL_MODE_WIDTH-1:0] sigSelMode;
  output                                 sigSelEn;
  output                                 sigSelOp;

  // Debug probes
  input   dbg_clk_enable;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)



  // ---- algorithm FSM variable manager
  wire                         algo_var_loadInit;
  wire                         algo_var_selPortA;
  wire                         algo_var_selPortB;
  wire                         algo_var_incPtrA0;
  wire                         algo_var_incPtrA1;
  wire                         algo_var_incPtrB0;
  wire                         algo_var_incPtrB1;
  wire                         algo_var_setNetCaptureEn;
  wire                         algo_var_clrNetCaptureEn;
  wire                         algo_var_setPicasoPtrIncr;
  wire                         algo_var_clrPicasoPtrIncr;

  wire [OPCODE_WIDTH-1:0]      algo_var_opcode;
  wire [ADDR_WIDTH-1:0]        algo_var_addr;
  wire [DATA_WIDTH-1:0]        algo_var_data;
  wire [REG_BASE_WIDTH-1:0]    algo_var_rd;
  wire [REG_BASE_WIDTH-1:0]    algo_var_rs1;
  wire [REG_BASE_WIDTH-1:0]    algo_var_rs2;
  wire [PICASO_ID_WIDTH-1:0]   algo_var_rowID; 
  wire [PICASO_ID_WIDTH-1:0]   algo_var_colID;
  wire [FN_WIDTH-1:0]          algo_var_fncode;
  wire [OFFSET_WIDTH-1:0]      algo_var_offset;
  wire [INSTR_PARAM_WIDTH-1:0] algo_var_param;

  wire [NET_LEVEL_WIDTH-1:0]   algo_var_netLevel;
  wire                         algo_var_netCaptureEn;
  wire [ALU_OP_WIDTH-1:0]      algo_var_aluConf;
  wire [OPMUX_CONF_WIDTH-1:0]  algo_var_opmuxConf;
  wire [ADDR_WIDTH-1:0]        algo_var_addrA;
  wire [ADDR_WIDTH-1:0]        algo_var_addrB;
  wire                         algo_var_picasoPtrIncr;

  picaso_fsm_vars #(
      .DEBUG(DEBUG),
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .FN_WIDTH(FN_WIDTH),
      .INSTR_PARAM_WIDTH(INSTR_PARAM_WIDTH),
      .NET_LEVEL_WIDTH(NET_LEVEL_WIDTH),
      .OFFSET_WIDTH(OFFSET_WIDTH),
      .OPCODE_WIDTH(OPCODE_WIDTH),
      .PICASO_ID_WIDTH(PICASO_ID_WIDTH),
      .REG_BASE_WIDTH(REG_BASE_WIDTH),
      .PE_REG_WIDTH(PE_REG_WIDTH) )
    algo_var_man (
      .clk(clk),
      .loadInit(algo_var_loadInit),
      .selPortA(algo_var_selPortA),
      .selPortB(algo_var_selPortB),
      .incPtrA0(algo_var_incPtrA0),
      .incPtrA1(algo_var_incPtrA1),
      .incPtrB0(algo_var_incPtrB0),
      .incPtrB1(algo_var_incPtrB1),
      .setNetCaptureEn(algo_var_setNetCaptureEn),
      .clrNetCaptureEn(algo_var_clrNetCaptureEn),
      .setPicasoPtrIncr(algo_var_setPicasoPtrIncr),
      .clrPicasoPtrIncr(algo_var_clrPicasoPtrIncr),

      .opcode(algo_var_opcode),
      .addr(algo_var_addr),
      .data(algo_var_data),
      .rd(algo_var_rd), 
      .rs1(algo_var_rs1),
      .rs2(algo_var_rs2), 
      .rowID(algo_var_rowID), 
      .colID(algo_var_colID),
      .fncode(algo_var_fncode),
      .offset(algo_var_offset),
      .param(algo_var_param),

      // directly relaying top-level inputs for pre-decoded signals
      .rs1_base(rs1_base),
      .rs2_base(rs2_base),
      .rd_base(rd_base),
      .rd_with_offset(rd_with_offset),
      .rs1_with_offset(rs1_with_offset),
      .rs2_with_offset(rs2_with_offset),
      .rs1_with_param(rs1_with_param),
      .rs2_with_param(rs2_with_param),
      .rd_with_param(rd_with_param),

      .netLevel(algo_var_netLevel),
      .netCaptureEn(algo_var_netCaptureEn),
      .aluConf(algo_var_aluConf),
      .opmuxConf(algo_var_opmuxConf),
      .addrA(algo_var_addrA),
      .addrB(algo_var_addrB),
      .picasoPtrIncr(algo_var_picasoPtrIncr),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
    );


  // ---- algorithm FSMs
  wire                                algo_fsm_enTransition;
  wire [ALGORITHM_SEL_WIDTH-1:0]      algo_fsm_selAlgo;
  wire [PICASO_ALGO_CODE_WIDTH-1:0]   algo_fsm_ctrlCode;
  wire                                algo_fsm_algoDone;
  wire                                algo_fsm_setNetCaptureEn;
  wire                                algo_fsm_clrNetCaptureEn;
  wire                                algo_fsm_setPicasoPtrIncr;
  wire                                algo_fsm_clrPicasoPtrIncr;


  picaso_algorithm_fsm #(
      .DEBUG(DEBUG),
      .PRECISION_WIDTH(PRECISION_WIDTH),
      .INSTR_PARAM_WIDTH(INSTR_PARAM_WIDTH),
      .NET_LEVEL_WIDTH(NET_LEVEL_WIDTH) )
    algo_fsm (
      .clk(clk),
      .precision(precision),
      .param(param),
      .enTransition(algo_fsm_enTransition),
      .selAlgo(algo_fsm_selAlgo),
      .ctrlCode(algo_fsm_ctrlCode),
      .algoDone(algo_fsm_algoDone),
      .setNetCaptureEn(algo_fsm_setNetCaptureEn),
      .clrNetCaptureEn(algo_fsm_clrNetCaptureEn),
      .setPicasoPtrIncr(algo_fsm_setPicasoPtrIncr),
      .clrPicasoPtrIncr(algo_fsm_clrPicasoPtrIncr),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
    );


  // ---- PiCaSO signal decoder for state-codes
  wire [PICASO_ALGO_CODE_WIDTH-1:0] algo_decoder_signalCode;

  wire [NET_LEVEL_WIDTH-1:0]   algo_decoder_netLevel;
  wire                         algo_decoder_netConfLoad;
  wire                         algo_decoder_netCaptureEn;

  wire [ALU_OP_WIDTH-1:0]      algo_decoder_aluConf;
  wire                         algo_decoder_aluConfLoad;
  wire                         algo_decoder_aluEn;
  wire                         algo_decoder_aluReset;
  wire                         algo_decoder_aluMbitReset;
  wire                         algo_decoder_aluMbitLoad;
  wire                         algo_decoder_sel_aluConf_param;

  wire                         algo_decoder_opmuxConfLoad;
  wire [OPMUX_CONF_WIDTH-1:0]  algo_decoder_opmuxConf;
  wire                         algo_decoder_opmuxEn;
  wire                         algo_decoder_sel_opmuxConf_param;

  wire                         algo_decoder_extDataSave;
  wire                         algo_decoder_saveAluOut;
  wire                         algo_decoder_ptrLoad;

  wire                         algo_decoder_sel_portA_ptr;
  wire                         algo_decoder_sel_portB_ptr;
  wire                         algo_decoder_inc_ptrA0;
  wire                         algo_decoder_inc_ptrA1;
  wire                         algo_decoder_inc_ptrB0;
  wire                         algo_decoder_inc_ptrB1;

  picaso_algorithm_decoder #(
      .DEBUG(DEBUG),
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .NET_LEVEL_WIDTH(NET_LEVEL_WIDTH),
      .PICASO_ID_WIDTH(PICASO_ID_WIDTH))
    algo_decoder (
      .signalCode(algo_decoder_signalCode),

      // PiCaSO control signals
      .picaso_netLevel(algo_decoder_netLevel),
      .picaso_netConfLoad(algo_decoder_netConfLoad),
      .picaso_netCaptureEn(algo_decoder_netCaptureEn),

      .picaso_aluConf(algo_decoder_aluConf),
      .picaso_aluConfLoad(algo_decoder_aluConfLoad),
      .picaso_aluEn(algo_decoder_aluEn),
      .picaso_aluReset(algo_decoder_aluReset),
      .picaso_aluMbitReset(algo_decoder_aluMbitReset),
      .picaso_aluMbitLoad(algo_decoder_aluMbitLoad),
      .sel_aluConf_param(algo_decoder_sel_aluConf_param),

      .picaso_opmuxConfLoad(algo_decoder_opmuxConfLoad),
      .picaso_opmuxConf(algo_decoder_opmuxConf),
      .picaso_opmuxEn(algo_decoder_opmuxEn),
      .sel_opmuxConf_param(algo_decoder_sel_opmuxConf_param),

      .picaso_extDataSave(algo_decoder_extDataSave),
      .picaso_saveAluOut(algo_decoder_saveAluOut),
      .picaso_ptrLoad(algo_decoder_ptrLoad),

      .sel_portA_ptr(algo_decoder_sel_portA_ptr),
      .sel_portB_ptr(algo_decoder_sel_portB_ptr),
      .inc_ptrA0(algo_decoder_inc_ptrA0),
      .inc_ptrA1(algo_decoder_inc_ptrA1),
      .inc_ptrB0(algo_decoder_inc_ptrB0),
      .inc_ptrB1(algo_decoder_inc_ptrB1)
    );


  // ---- Local Interconnect: Connecting Signals and Modules ----
  // inputs of algo_fsm
  assign algo_fsm_enTransition = enTransition,
         algo_fsm_selAlgo      = selAlgo;


  // inputs of fsm variable manager 
  // instruction fields
  assign algo_var_opcode = opcode,
         algo_var_addr = addr,
         algo_var_data = data,
         algo_var_rd = rd, 
         algo_var_rs1 = rs1, 
         algo_var_rs2 = rs2, 
         algo_var_rowID = rowID, 
         algo_var_colID = colID,
         algo_var_fncode = fncode,
         algo_var_offset = offset,
         algo_var_param = param;
  //  top-level inputs
  assign algo_var_loadInit = loadInit;
  // Signals from state-to-signal decoder
  assign algo_var_selPortA = algo_decoder_sel_portA_ptr,
         algo_var_selPortB = algo_decoder_sel_portB_ptr,
         algo_var_incPtrA0 = algo_decoder_inc_ptrA0,
         algo_var_incPtrA1 = algo_decoder_inc_ptrA1,
         algo_var_incPtrB0 = algo_decoder_inc_ptrB0,
         algo_var_incPtrB1 = algo_decoder_inc_ptrB1;
  // Signals from algorithm-fsm
  assign algo_var_setNetCaptureEn  = algo_fsm_setNetCaptureEn,
         algo_var_clrNetCaptureEn  = algo_fsm_clrNetCaptureEn,
         algo_var_setPicasoPtrIncr = algo_fsm_setPicasoPtrIncr,
         algo_var_clrPicasoPtrIncr = algo_fsm_clrPicasoPtrIncr;


  // inputs of algorithm decoder
  assign algo_decoder_signalCode = algo_fsm_ctrlCode;


  /* output port signals: 
   *   - values are loaded from variable manager
   *   - control signals directly come from state-to-signal decoder
   *   - some configurations may come from either variable manager or state-to-signal decoder
   */
  assign sigNetLevel     = algo_var_netLevel,
         sigNetConfLoad  = algo_decoder_netConfLoad,
         sigNetCaptureEn = algo_var_netCaptureEn;

  assign sigAluConf      = algo_var_aluConf,
         sigAluConfLoad  = algo_decoder_aluConfLoad,
         sigAluEn        = algo_decoder_aluEn,
         sigAluReset     = algo_decoder_aluReset,
         sigAluMbitReset = algo_decoder_aluMbitReset,
         sigAluMbitLoad  = algo_decoder_aluMbitLoad; 

  assign sigOpmuxConfLoad = algo_decoder_opmuxConfLoad,
         sigOpmuxEn       = algo_decoder_opmuxEn,
         sigOpmuxConf     = algo_decoder_sel_opmuxConf_param    // Some instructions may need multiple opmux-configs, that are directly generated by the state-decoder
                            ? algo_var_opmuxConf                //   - if algo_decoder_sel_opmuxConf_param is set, selects the opmux-config from the variable manager
                            : algo_decoder_opmuxConf;           //   - otherwise, selects the opmux-config from the state decoder

  assign sigAddrA      = algo_var_addrA,
         sigAddrB      = algo_var_addrB,
         sigSaveAluOut = algo_decoder_saveAluOut,
         sigPtrIncr    = algo_var_picasoPtrIncr,
         sigPtrLoad    = algo_decoder_ptrLoad;

  assign algoDone = algo_fsm_algoDone;


  // following signals are not controlled by this driver
  assign sigExtDataSave = 0,
         sigExtDataIn = 0,
         sigSelRow = 0,
         sigSelCol = 0,
         sigSelMode = 0,
         sigSelEn = 0,
         sigSelOp = 0;



  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule

