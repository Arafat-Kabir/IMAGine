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
  Date   : Wed, Aug 30, 04:01 PM CST 2023
  Version: v1.0

  Description:
  This module decodes the instruction word into different fields. This is
  a purely combinatorial block which provides a level of design abstraction.
  If the instruction format changes, only this module needs to be updated
  keeping the interpretation of the output signals unchanged. Checkout 
  doc/PiCaSO-Controller-Design.md for structure of the instruction word.

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module picaso_instruction_decoder #(
  parameter DEBUG = 1,
  parameter WORD_WIDTH = -1,
  parameter PE_REG_WIDTH = -1
) (
  clk,
  instruction_word,
  // instruction fields
  opcode,
  addr,
  data,
  offset,
  rs1,
  rs2,
  rd,
  rowID,
  colID,
  fn,
  sCode,
  param,
  // extra decoded signals
  algoselCode,
  instrType,
  rs1_base,
  rs2_base,
  rd_base,
  rd_with_offset,
  rs1_with_offset,
  rs2_with_offset,
  rs1_with_param,
  rs2_with_param,
  rd_with_param
);

  `include "picaso_instruction_decoder.inc.v"
  `include "picaso_algorithm_fsm.inc.v"

  // Validate parameters
  `AK_ASSERT2(PE_REG_WIDTH >= 0, PE_REG_WIDTH_not_set)
  // checking if parameters from top are consistent with decoding assumptions
  `AK_ASSERT(WORD_WIDTH == PICASO_INSTR_WORD_WIDTH)


  // remove scope prefix for short-hand
  localparam OPCODE_WIDTH = PICASO_INSTR_OPCODE_WIDTH,
             FN_WIDTH = PICASO_INSTR_FN_WIDTH,
             ADDR_WIDTH = PICASO_INSTR_ADDR_WIDTH,
             DATA_WIDTH = PICASO_INSTR_DATA_WIDTH,
             OFFSET_WIDTH = PICASO_INSTR_OFFSET_WIDTH,
             REG_BASE_WIDTH = PICASO_INSTR_REG_BASE_WIDTH,
             PARAM_WIDTH = PICASO_INSTR_PARAM_WIDTH,
             ID_WIDTH = PICASO_INSTR_ID_WIDTH,
             SCODE_WIDTH = PICASO_INSTR_SCODE_WIDTH;

  localparam SEG0_WIDTH = PICASO_INSTR_SEG0_WIDTH,
             SEG1_WIDTH = PICASO_INSTR_SEG1_WIDTH,
             SEG2_WIDTH = PICASO_INSTR_SEG2_WIDTH;


  // IO Ports
  input  wire                        clk;
  input  wire [WORD_WIDTH-1:0]       instruction_word;
  output reg  [OPCODE_WIDTH-1:0]     opcode = 0;    // NOP
  output reg  [ADDR_WIDTH-1:0]       addr = 0;
  output reg  [DATA_WIDTH-1:0]       data = 0;
  output reg  [OFFSET_WIDTH-1:0]     offset = 0;
  output reg  [REG_BASE_WIDTH-1:0]   rd = 0, rs1 = 0, rs2 = 0;
  output reg  [ID_WIDTH-1:0]         rowID = 0, colID = 0;
  output reg  [FN_WIDTH-1:0]         fn = 0;
  output reg  [SCODE_WIDTH-1:0]      sCode = 0;
  output reg  [PARAM_WIDTH-1:0]      param = 0;

  // Pipelined decoded output signals
  output reg  [ALGORITHM_SEL_WIDTH-1:0]           algoselCode = 0;   // algorithm selection code for multicycle driver
  output reg  [PICASO_INSTR_TYPE_CODE_WIDTH-1:0]  instrType = INSTR_TYPE_MULTI_CYCLE;   // on reset multi-cycle instruction is selected, which is supposed to generate NOP

  output reg  [ADDR_WIDTH-1:0]  rs1_base = 0;
  output reg  [ADDR_WIDTH-1:0]  rs2_base = 0;
  output reg  [ADDR_WIDTH-1:0]  rd_base = 0;
  output reg  [ADDR_WIDTH-1:0]  rd_with_offset = 0;
  output reg  [ADDR_WIDTH-1:0]  rs1_with_offset = 0;
  output reg  [ADDR_WIDTH-1:0]  rs2_with_offset = 0;
  output reg  [ADDR_WIDTH-1:0]  rs1_with_param = 0;
  output reg  [ADDR_WIDTH-1:0]  rs2_with_param = 0;
  output reg  [ADDR_WIDTH-1:0]  rd_with_param = 0;


  // separate the instruction segments
  wire [SEG0_WIDTH-1:0] segment0;
  wire [SEG1_WIDTH-1:0] segment1;
  wire [SEG2_WIDTH-1:0] segment2;

  assign segment0 = instruction_word[0 +: SEG0_WIDTH];
  assign segment1 = instruction_word[SEG0_WIDTH +: SEG1_WIDTH];
  assign segment2 = instruction_word[(SEG0_WIDTH+SEG1_WIDTH) +: SEG2_WIDTH];


  // ---- Extract instruction fields and put into output registers
  wire [OPCODE_WIDTH-1:0]   fld_opcode;
  wire [FN_WIDTH-1:0]       fld_fncode;
  wire [ADDR_WIDTH-1:0]     fld_addr;
  wire [DATA_WIDTH-1:0]     fld_data;
  wire [OFFSET_WIDTH-1:0]   fld_offset;
  wire [REG_BASE_WIDTH-1:0] fld_rd, fld_rs1, fld_rs2;
  wire [ID_WIDTH-1:0]       fld_rowID, fld_colID;
  wire [SCODE_WIDTH-1:0]    fld_sCode;
  wire [PARAM_WIDTH-1:0]    fld_param;


  // Decode instruction: [ OpCode ][ ADDR ][ DATA ]
  assign fld_data   = segment0;
  assign fld_addr   = segment1[0 +: ADDR_WIDTH];
  assign fld_opcode = segment2;

  always@(posedge clk) begin
    data   <= fld_data;
    addr   <= fld_addr;
    opcode <= fld_opcode;
  end


  // Decode instruction: [ opcode ] [ OFFSET, RD ] [ RS2, RS1 ]
  assign fld_rs1    = segment0[0 +: REG_BASE_WIDTH];
  assign fld_rs2    = segment0[REG_BASE_WIDTH +: REG_BASE_WIDTH];
  assign fld_rd     = segment1[0 +: REG_BASE_WIDTH];
  assign fld_offset = segment1[REG_BASE_WIDTH +: OFFSET_WIDTH];

  always@(posedge clk) begin
    rs1    <= fld_rs1;
    rs2    <= fld_rs2;
    rd     <= fld_rd;
    offset <= fld_offset;
  end


  // Decode instruction: [ opcode ] [ Fn, RD    ] [ RS2, RS1 ]
  //                     [ opcode ] [ Fn, xx    ] [  xx, R   ]
  //                     [ opcode ] [ Fn, Param ] [  xx, R   ]
  // R = rs1
  assign fld_fncode = segment1[REG_BASE_WIDTH +: FN_WIDTH];
  assign fld_param  = segment1[0 +: PARAM_WIDTH];

  always@(posedge clk) begin
    fn    <= fld_fncode;
    param <= fld_param;
  end


  // Decode instruction: [ super-op ] [ super-code ] [ param(s) ]
  assign fld_sCode  = segment1[0 +: SCODE_WIDTH];

  always@(posedge clk) begin
    sCode <= fld_sCode;
  end


  // TODO: Merge select with super-op
  // Decode instruction: [ opcode ] [ Fn, xx ] [ Row, Col ]
  assign fld_colID = segment0[0 +: ID_WIDTH];
  assign fld_rowID = segment0[ID_WIDTH +: ID_WIDTH];

  always@(posedge clk) begin
    colID <= fld_colID;
    rowID <= fld_rowID;
  end



  // ---- Additional decoder logic ----
  // Following signals are decoded for ahead of time (pipeline) for 
  // later logic blocks to use. This reduces the logic depth of the controller.


  // AK-NOTE: Following decoder function was part of the picaso_instruction_fsm.v.
  //          Given the opcode and fncode, it generates the algorithm selection code 
  //          for picaso_algorithm_fsm.
  // Algorithm Selection Table
  function automatic [ALGORITHM_SEL_WIDTH-1:0] get_algoselection;
    input [OPCODE_WIDTH-1:0] _opcode;
    input [FN_WIDTH-1:0]     _fncode;

    // internal variables
    reg [ALGORITHM_SEL_WIDTH-1:0] _selectcode;

    begin
      _selectcode = 0;    // start with a default value
      (* full_case, parallel_case *)
      case(_opcode)
        //PICASO_MULT : _instr_type = MULTI_CYCLE_TYPE;
        PICASO_UPDATEPP: _selectcode = ALGORITHM_UPDATEPP;
        PICASO_ALUOP:    _selectcode = ALGORITHM_ALUOP;

        PICASO_ACCUM: begin
          (* full_case, paralle_case *)
          case(_fncode)
            PICASO_FN_ACCUM_BLK: _selectcode = ALGORITHM_STREAM;     // block-level accumulation is also handled by the STREAM FSM
            PICASO_FN_ACCUM_ROW: _selectcode = ALGORITHM_ACCUMROW;
            default: $display("EROR: Invalid fncode for ACCUM, fncode: %b (%s:%0d) %0t", _fncode, `__FILE__, `__LINE__, $time);  // keep the initial values
          endcase
        end

        PICASO_MOV: begin
          _selectcode = ALGORITHM_STREAM;     // initial value
          (* full_case, paralle_case *)
          case(_fncode)
            PICASO_FN_MOV_OFFSET: _selectcode = ALGORITHM_STREAM;
            default: $display("EROR: Invalid fncode for MOV, fncode: b%b (%s:%0d) %0t", _fncode, `__FILE__, `__LINE__, $time);  // keep the initial value
          endcase
        end

        default: ;    // keep initial value
      endcase
      get_algoselection = _selectcode;   // return value
    end
  endfunction


  // AK-NOTE: Following decoder function was part of the picaso_instruction_fsm.v.
  //          Given the opcode, it generates the instruction type code.
  //          Answers the question: is this instruction a single-cycle or a multicycle instruction?
  function automatic [PICASO_INSTR_TYPE_CODE_WIDTH-1:0] get_instruction_type;
    input [OPCODE_WIDTH-1:0] _opcode;

    // internal variables
    reg [PICASO_INSTR_TYPE_CODE_WIDTH-1:0] _instr_type;

    begin
      (* full_case, parallel_case *)
      case(_opcode)
        PICASO_UPDATEPP : _instr_type = INSTR_TYPE_MULTI_CYCLE;
        PICASO_ACCUM:     _instr_type = INSTR_TYPE_MULTI_CYCLE;
        PICASO_ALUOP:     _instr_type = INSTR_TYPE_MULTI_CYCLE;
        PICASO_MOV:       _instr_type = INSTR_TYPE_MULTI_CYCLE;
        default:          _instr_type = INSTR_TYPE_SINGLE_CYCLE;    // every other instruction is single-cycle
      endcase
      get_instruction_type = _instr_type;   // return value
    end
  endfunction


  // set the pipelined decoded signal outputs
  always@(posedge clk) begin
    algoselCode <= get_algoselection(fld_opcode, fld_fncode);
    instrType   <= get_instruction_type(fld_opcode);
  end


  // AK-NOTE: Following addresses decoder logic was part of picaso_fsm_vars.v
  always@(posedge clk) begin
    rs1_base = fld_rs1 * PE_REG_WIDTH;
    rs2_base = fld_rs2 * PE_REG_WIDTH;
    rd_base  = fld_rd  * PE_REG_WIDTH;

    rd_with_offset  = fld_rd  * PE_REG_WIDTH + fld_offset;
    rs1_with_offset = fld_rs1 * PE_REG_WIDTH + fld_offset;
    rs2_with_offset = fld_rs2 * PE_REG_WIDTH + fld_offset;

    rs1_with_param = fld_rs1 * PE_REG_WIDTH + fld_param;
    rs2_with_param = fld_rs2 * PE_REG_WIDTH + fld_param;
    rd_with_param  = fld_rd * PE_REG_WIDTH  + fld_param;
  end


endmodule
