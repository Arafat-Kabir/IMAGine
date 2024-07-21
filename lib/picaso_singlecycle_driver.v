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
  Date   : Fri, Sep 01, 05:48 PM CST 2023
  Version: v1.0

  Description:
  This module decodes the instruction and generates the the control signals
  for single-cycle instructions. This includes BRAM read/write, block select,
  etc. It is a purely combinatorial block.

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module picaso_singlecycle_driver #(
  parameter DEBUG = 1,
  parameter OPCODE_WIDTH = -1,
  parameter ADDR_WIDTH = -1,
  parameter DATA_WIDTH = -1,
  parameter REG_BASE_WIDTH = -1,
  parameter PICASO_ID_WIDTH = -1,
  parameter FN_WIDTH = -1,
  parameter OFFSET_WIDTH = -1,
  parameter INSTR_PARAM_WIDTH = -1,
  parameter NET_LEVEL_WIDTH = -1
) (
  // fields from instruction word 
  opcode,
  addr,
  data,
  rd, rs1, rs2,
  rowID, colID,
  fncode,
  sCode,
  offset,
  param,

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
  sigSelOp
);

  `include "boothR2_serial_alu.inc.v"
  `include "alu_serial_unit.inc.v"
  `include "opmux_ff.inc.v"
  `include "picaso_ff.inc.v"
  `include "picaso_instruction_decoder.inc.v"


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

  // remove scope prefix for short-hand
  localparam SCODE_WIDTH = PICASO_INSTR_SCODE_WIDTH;


  // IO Ports
  input [OPCODE_WIDTH-1:0]      opcode;
  input [ADDR_WIDTH-1:0]        addr;
  input [DATA_WIDTH-1:0]        data;
  input [REG_BASE_WIDTH-1:0]    rd, rs1, rs2;
  input [PICASO_ID_WIDTH-1:0]   rowID, colID;
  input [FN_WIDTH-1:0]          fncode;
  input [SCODE_WIDTH-1:0]       sCode;
  input [OFFSET_WIDTH-1:0]      offset;
  input [INSTR_PARAM_WIDTH-1:0] param;

  output [NET_LEVEL_WIDTH-1:0]       sigNetLevel;
  output                             sigNetConfLoad;
  output                             sigNetCaptureEn;

  output [ALU_OP_WIDTH-1:0]          sigAluConf;
  output                             sigAluConfLoad;
  output                             sigAluEn;
  output                             sigAluReset;
  output reg                         sigAluMbitReset;
  output                             sigAluMbitLoad;

  output                             sigOpmuxConfLoad;
  output [OPMUX_CONF_WIDTH-1:0]      sigOpmuxConf;
  output                             sigOpmuxEn;

  output reg                         sigExtDataSave;
  output     [DATA_WIDTH-1:0]        sigExtDataIn;

  output                             sigSaveAluOut;
  output reg [ADDR_WIDTH-1:0]        sigAddrA;
  output     [ADDR_WIDTH-1:0]        sigAddrB;
  output                             sigPtrLoad;
  output                             sigPtrIncr;

  output reg [PICASO_ID_WIDTH-1:0]       sigSelRow;  // defined reg for behavioral modeling
  output reg [PICASO_ID_WIDTH-1:0]       sigSelCol;
  output reg [PICASO_SEL_MODE_WIDTH-1:0] sigSelMode;
  output reg                             sigSelEn;
  output reg                             sigSelOp;


  // Following signals are not used in single-cycle operations
  assign sigAluConf = 0;
  assign sigAluConfLoad = 0;    // NOP
  assign sigAluEn = 0;          // NOP
  assign sigAluReset = 0;       // NOP
  assign sigAluMbitLoad = 0;    // NOP

  assign sigOpmuxConfLoad = 0;  // NOP
  assign sigOpmuxConf = 0;
  assign sigOpmuxEn = 0;        // NOP

  assign sigNetLevel = 0;
  assign sigNetConfLoad = 0;    // NOP
  assign sigNetCaptureEn = 0;   // NOP

  assign sigSaveAluOut = 0;     // NOP
  assign sigPtrLoad = 0;        // NOP
  assign sigPtrIncr = 0;        // NOP


  // following signal decodings are not dependent on opcode
  assign sigExtDataIn  = data;   // external data is taken from instruction data field
  assign sigAddrB      = 0;      // not used by single-cycle instructions


  `AK_TOP_WARN("Add control signals for precision register")      // TODO: check the macro message


  // decoding logic for block selection signals
  always@* begin
    // start with NOP
    sigSelRow  = rowID;
    sigSelCol  = colID;
    sigSelMode = fncode;
    sigSelEn   = 0;   // NOP
    sigSelOp   = 0;   // NOP

    (* full_case, parallel_case *)
    case(opcode)
      PICASO_SELECT: sigSelEn = 1;   // set the selection register    // TODO: Move SELECT under SUPER-OP
      PICASO_READ:   sigSelOp = 1;   // this is a selective operation  
      PICASO_WRITE:  sigSelOp = 1;   // this is a selective operation
      PICASO_NOP: ;  // default is NOP
      default: ;     // NOP
    endcase
  end


  // decoding logic for read/write signals
  always@* begin
    // start with NOP
    sigAddrA = addr;      // port-A used for saving external data
    sigExtDataSave = 0;   // NOP

    (* full_case, parallel_case *)
    case(opcode)
      PICASO_WRITE:  sigExtDataSave = 1;
      PICASO_NOP: ;  // default is NOP
      default: ;     // NOP
    endcase
  end


  // TODO: Add signals and logic for SET-PRECISION instruction


  // SUPER_OP instruction decoder
  always@* begin
    // start with NOP
    sigAluMbitReset = 0;

    if(opcode==PICASO_SUPEROP) begin
      (* full_case, parallel_case *)
      case(sCode)
        PICASO_SCODE_CLRMBIT: sigAluMbitReset = 1;
        default: ;     // NOP
      endcase
    end
  end


  // -- Following block is for simulation only: setting initial values of reg variables
  initial begin
    sigExtDataSave = 0;
    sigAddrA = 0;
    sigSelRow = 0;
    sigSelCol = 0;
    sigSelMode = 0;
    sigSelEn = 0;
    sigSelOp = 0;
  end

endmodule

