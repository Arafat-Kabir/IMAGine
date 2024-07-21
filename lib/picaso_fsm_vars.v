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
  Date   : Thu, Aug 31, 02:58 PM CST 2023
  Version: v1.0

  Description:
  This module manages the variables for the algorithm FSM. It takes the fields
  from the instruction word and computes the initial values for the algorithm
  FSM variables. It also provides control signals to manipulate those variables.
  The algorithm FSM uses those control signals to generate values for PiCaSO 
  blocks.
  The bottomline is that, algorithm FSM generates the control signals for
  PiCaSO blocks, e.g aluEn, opmux-confload, etc., while this module provides
  values like port-address, alu-configuration, etc.

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module picaso_fsm_vars #(
  parameter DEBUG = 1,
  parameter ADDR_WIDTH = -1,
  parameter DATA_WIDTH = -1,
  parameter FN_WIDTH = -1,
  parameter INSTR_PARAM_WIDTH = -1,
  parameter NET_LEVEL_WIDTH = -1,
  parameter OFFSET_WIDTH = -1,
  parameter OPCODE_WIDTH = -1,
  parameter PICASO_ID_WIDTH = -1,
  parameter REG_BASE_WIDTH = -1,
  parameter PE_REG_WIDTH = -1
) (
  clk,
  loadInit,   // loads the initial values to the variables (regs)
  selPortA,   // select between 2 pointers, A0, A1 for port-A address
  selPortB,   // select between 2 pointers, B0, B1 for port-B address
  incPtrA0,   // increments the pointer
  incPtrA1,
  incPtrB0,
  incPtrB1,
  setNetCaptureEn,    // sets the netCaptureEn flip-flop
  clrNetCaptureEn,    // clears the netCaptureEn flip-flop
  setPicasoPtrIncr,   // sets the picasoPtrIncr flip-flop
  clrPicasoPtrIncr,   // clears the picasoPtrIncr flip-flop
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
  // variables for picaso signals
  netLevel,
  netCaptureEn,
  aluConf,
  opmuxConf,
  addrA,
  addrB,
  picasoPtrIncr,

  // Debug probes
  dbg_clk_enable         // debug clock for stepping
);

  `include "picaso_instruction_decoder.inc.v"  // defines the instructio op-codes
  `include "boothR2_serial_alu.inc.v"          // needed for alu_serial_unit.inc.v
  `include "alu_serial_unit.inc.v"             // defines ALU opcodes
  `include "opmux_ff.inc.v"                    // defines opmux configuration codes
  `include "countbits_func.v"
  `include "picaso_ff.inc.v"


  // Make sure all parameters are explicitly specified
  `AK_ASSERT2(ADDR_WIDTH >= 0, ADDR_WIDTH_not_set)
  `AK_ASSERT2(DATA_WIDTH >= 0, DATA_WIDTH_not_set)
  `AK_ASSERT2(FN_WIDTH >= 0, FN_WIDTH_not_set)
  `AK_ASSERT2(INSTR_PARAM_WIDTH >= 0, INSTR_PARAM_WIDTH_not_set)
  `AK_ASSERT2(NET_LEVEL_WIDTH >= 0, NET_LEVEL_WIDTH_not_set)
  `AK_ASSERT2(OFFSET_WIDTH >= 0, OFFSET_WIDTH_not_set)
  `AK_ASSERT2(OPCODE_WIDTH >= 0, OPCODE_WIDTH_not_set)
  `AK_ASSERT2(PICASO_ID_WIDTH >= 0, PICASO_ID_WIDTH_not_set)
  `AK_ASSERT2(REG_BASE_WIDTH >= 0, REG_BASE_WIDTH_not_set)
  `AK_ASSERT2(PE_REG_WIDTH >= 0, PE_REG_WIDTH_not_set)

  // ensure the field widths meet the variable width requirements
  `AK_ASSERT2(INSTR_PARAM_WIDTH >= NET_LEVEL_WIDTH, INSTR_PARAM_WIDTH_not_big_enough)

  // apply constraints on the PE_REG_WIDTH values
  `AK_ASSERT2(countbits(PE_REG_WIDTH) == 1, PE_REG_WIDTH_not_pow_of_2)       // only supports power of 2


  // IO Ports
  input                         clk;
  input                         loadInit;
  input                         selPortA;
  input                         selPortB;
  input                         incPtrA0;
  input                         incPtrA1;
  input                         incPtrB0;
  input                         incPtrB1;
  input                         setNetCaptureEn;
  input                         clrNetCaptureEn;
  input                         setPicasoPtrIncr;
  input                         clrPicasoPtrIncr;

  input [OPCODE_WIDTH-1:0]      opcode;
  input [ADDR_WIDTH-1:0]        addr;
  input [DATA_WIDTH-1:0]        data;
  input [REG_BASE_WIDTH-1:0]    rd, rs1, rs2;
  input [PICASO_ID_WIDTH-1:0]   rowID, colID;
  input [FN_WIDTH-1:0]          fncode;
  input [OFFSET_WIDTH-1:0]      offset;
  input [INSTR_PARAM_WIDTH-1:0] param;

  input [ADDR_WIDTH-1:0]  rs1_base;
  input [ADDR_WIDTH-1:0]  rs2_base;
  input [ADDR_WIDTH-1:0]  rd_base;
  input [ADDR_WIDTH-1:0]  rd_with_offset;
  input [ADDR_WIDTH-1:0]  rs1_with_offset;
  input [ADDR_WIDTH-1:0]  rs2_with_offset;
  input [ADDR_WIDTH-1:0]  rs1_with_param;
  input [ADDR_WIDTH-1:0]  rs2_with_param;
  input [ADDR_WIDTH-1:0]  rd_with_param;

  output [NET_LEVEL_WIDTH-1:0]  netLevel;
  output                        netCaptureEn;
  output                        picasoPtrIncr;
  output [ALU_OP_WIDTH-1:0]     aluConf;
  output [OPMUX_CONF_WIDTH-1:0] opmuxConf;
  output [ADDR_WIDTH-1:0]       addrA;
  output [ADDR_WIDTH-1:0]       addrB;

  // Debug probes
  input   dbg_clk_enable;

  // internal debug signals
  wire    local_ce;       // module-level clock enable (used for debugging support)


  // Function to map fncode field to aluConf values
  function automatic [ALU_OP_WIDTH-1:0] fncode_to_aluconf;
    input [FN_WIDTH-1:0] _fncode;
  
    // internal signals
    reg [ALU_OP_WIDTH-1:0] _aluconf;

    begin
      _aluconf = 0;
      (* full_case, parallel_case *)
      case (_fncode)
        PICASO_FN_ALU_ADD: _aluconf = ALU_UNIT_ADD;
        PICASO_FN_ALU_CPX: _aluconf = ALU_UNIT_CPX;
        PICASO_FN_ALU_CPY: _aluconf = ALU_UNIT_CPY;
        PICASO_FN_ALU_SUB: _aluconf = ALU_UNIT_SUB;
        default: $display("EROR: Invalid _fncode: %b (%s: %0d)", _fncode, `__FILE__, `__LINE__);
      endcase
      // set the return value
      fncode_to_aluconf = _aluconf;
    end
  endfunction


  // Function to map param field to opmux-conf values
  function automatic [ALU_OP_WIDTH-1:0] param_to_opmuxconf;
    input [INSTR_PARAM_WIDTH-1:0] _param;
  
    // internal signals
    reg [OPMUX_CONF_WIDTH-1:0] _opmuxconf;

    // AK-NOTE: Tue, Oct 10, 12:19 PM CST 2023
    // This function provides an abstract interface for param field to opmux-conf conversion.
    // Following mapping is written in a way to have one-to-one correspondence between 
    // param value and opmux-conf codes. That is why, no LUT is supposed to be generated 
    // to implement the following logic.
    // However, if need be, complicated mappings can be easily generated by modifying the following code.
    reg [OPMUX_CONF_WIDTH-1:0] _param_bits;
    begin
      _param_bits = _param[0 +: OPMUX_CONF_WIDTH];    // upper bits of param are don't-cares
      (* full_case, parallel_case *)
      case (_param_bits)
        1: _opmuxconf = OPMUX_A_FOLD_1;
        2: _opmuxconf = OPMUX_A_FOLD_2;
        3: _opmuxconf = OPMUX_A_FOLD_3;
        4: _opmuxconf = OPMUX_A_FOLD_4;
        // following are redundant and meaningless mappings (can be modified if needed)
        0: _opmuxconf = OPMUX_A_OP_B;
        5: _opmuxconf = OPMUX_A_OP_NET;
        6: _opmuxconf = OPMUX_0_OP_B;
        7: _opmuxconf = OPMUX_A_OP_0;
        default: $display("EROR: Invalid param: %b (%s: %0d)  %0t", _param, `__FILE__, `__LINE__, $time);
      endcase
      // set the return value
      param_to_opmuxconf = _opmuxconf;
    end
  endfunction


  // ---- computing the initial values for the fsm variables
  // following variables are either fixed for a given opcode, or are encoded
  // into the lower-bits of the param field of the related instructions
  reg [NET_LEVEL_WIDTH-1:0]       init_netLevel;
  reg [ALU_OP_WIDTH-1:0]          init_aluConf;
  reg [OPMUX_CONF_WIDTH-1:0]      init_opmuxConf;

  always@* begin
    // Adding a 0-delay event bubble to avoid RTL simulation races
    #0;

    // set initial values
    init_netLevel  = param[0 +: NET_LEVEL_WIDTH];
    init_opmuxConf = OPMUX_A_OP_B;  // most common case
    init_aluConf   = ALU_UNIT_ADD;  // most common case

    // instruction-specific values
    (* full_case, parallel_case *)
    case(opcode)
      PICASO_ALUOP: begin
        // ALU-OP executes a given operation (+, -, cpx, cpy) between 2 operands
        init_opmuxConf = OPMUX_A_OP_B;
        init_aluConf = fncode_to_aluconf(fncode);
      end

      PICASO_UPDATEPP: begin
        // Update-pp basically adds 2 operands: partial-product (A) and multiplicand*mult-bit (B).
        // however, for offset=0, it should use A=0 and thus use 0_op_B opmux configuration. 
        // This special case of offset=0 is used to avoid extra cycles needed
        // to zero out the destination register.
        if(offset == 0) init_opmuxConf = OPMUX_0_OP_B;
        else            init_opmuxConf = OPMUX_A_OP_B;
        init_aluConf = ALU_UNIT_BOOTH;    // will load the ALU opcode based on XY bits
      end

      PICASO_MOV: begin
        // These are a set of streaming instructions, where data is read from one registers
        // and written to another instruction simultaneously. Port-A is always used for 
        // reading from the register and port-B is used for writing (using ALU-save-out)
        init_aluConf   = ALU_UNIT_CPX;    // stream X is directly copied to output
        init_opmuxConf = OPMUX_A_OP_B;    // may change depending on fncode
        (* full_case, paralle_case *)
        case(fncode)
          PICASO_FN_MOV_OFFSET: ;   // default values are for this fncode
          default: ;  // keep the initial values
        endcase
      end

      PICASO_ACCUM: begin
        (* full_case, paralle_case *)
        case(fncode)
          PICASO_FN_ACCUM_BLK: begin
            // ACCUM_BLK adds folded stream-A
            init_aluConf   = ALU_UNIT_ADD;
            init_opmuxConf = param_to_opmuxconf(param);
          end
          PICASO_FN_ACCUM_ROW: begin
            // ACCUM_ROW adds stream-A with network stream
            init_netLevel  = param[0 +: NET_LEVEL_WIDTH];
            init_aluConf   = ALU_UNIT_ADD;
            init_opmuxConf = OPMUX_A_OP_NET;
          end
          default: $display("EROR: Invalid _fncode: %b for PICASO_ACCUM (%s: %0d)", fncode, `__FILE__, `__LINE__); // keep the initial values
        endcase
      end

      default: ;  // keep the initial values
    endcase
  end


  // Following variables are used to initialize the pointers for BRAM
  reg [ADDR_WIDTH-1:0] init_ptrA0, init_ptrA1;
  reg [ADDR_WIDTH-1:0] init_ptrB0, init_ptrB1;

  always@* begin
    // start with some initial value
    // following values are applicable for ALU_OP instruction
    init_ptrA0 = rs1_base;    // read A
    init_ptrB0 = rs2_base;    // read B
    init_ptrB1 = rd_base;     // write A-op-B
    init_ptrA1 = rs1_with_offset;   // not used in ALU_OP instruction, overlaps with UPDATEPP configuration

    // instruction-specific values
    (* full_case, parallel_case *)
    case(opcode)
      PICASO_UPDATEPP: begin
        // rs1: multiplier, rs2: multiplicand
        // alu-opcode is set using rs2[offset]
        // partial-product is updated starting at bit rd[offset]
        init_ptrA0 = rd_with_offset;   // partial-product read
        init_ptrB0 = rs2_base;         // multiplicand read
        init_ptrB1 = rd_with_offset;   // partial-product write
        init_ptrA1 = rs1_with_offset;  // lower-bit of multiplier
      end

      PICASO_MOV: begin
        // rs1: source register-base
        // rs2: destination register-base
        init_ptrA0 = rs1_with_param;    // pointer to read register (address), ptrA0 selected to reuse ALU_OP state-codes
        init_ptrB1 = rs2_base;          // pointer to write register, ptrB1 selected to reuse ALU_OP state-codes
      end

      PICASO_ACCUM: case(fncode)
        // accumulate block requires 2 pointers, it uses the transition_stream states
        PICASO_FN_ACCUM_BLK: begin
          init_ptrA0 = rs1_base;    // pointer to read register
          init_ptrB1 = rs2_base;    // pointer to write register
        end
        // accumulate row requires 3 pointers
        PICASO_FN_ACCUM_ROW: begin
          init_ptrA0 = rs1_base;    // for read at receiver
          init_ptrB1 = rs1_base;    // for write at receiver
          init_ptrA1 = rs1_base;    // for streaming by transmitter block
        end
      endcase

      default: ;    // keep the initial values
    endcase
  end



  // ---- Add registers to be used as variables
  reg [NET_LEVEL_WIDTH-1:0]       netLevel_reg  = 0;
  reg [ALU_OP_WIDTH-1:0]          aluConf_reg   = 0;
  reg [OPMUX_CONF_WIDTH-1:0]      opmuxConf_reg = 0;

  always@(posedge clk) begin
    if(loadInit && local_ce) begin       // local_ce for debugging
      // load initial values when asked
      netLevel_reg  <= init_netLevel;
      aluConf_reg   <= init_aluConf;
      opmuxConf_reg <= init_opmuxConf;
    end else begin
      // otherwise, hold the old values
      netLevel_reg  <= netLevel_reg;
      aluConf_reg   <= aluConf_reg;
      opmuxConf_reg <= opmuxConf_reg;
    end
  end



  // pointers for port-A
  wire [ADDR_WIDTH-1:0] ptr_A0_loadVal;
  wire                  ptr_A0_loadEn;
  wire                  ptr_A0_countEn;
  wire [ADDR_WIDTH-1:0] ptr_A0_countOut;

  up_counter #(
      .DEBUG(DEBUG),
      .VAL_WIDTH(ADDR_WIDTH) )      // pointer widths are equal to BRAM address width
    ptr_A0 (
      .clk(clk),
      .loadVal(ptr_A0_loadVal),
      .loadEn(ptr_A0_loadEn),
      .countEn(ptr_A0_countEn),
      .countOut(ptr_A0_countOut),

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  wire [ADDR_WIDTH-1:0] ptr_A1_loadVal;
  wire                  ptr_A1_loadEn;
  wire                  ptr_A1_countEn;
  wire [ADDR_WIDTH-1:0] ptr_A1_countOut;

  up_counter #(
      .DEBUG(DEBUG),
      .VAL_WIDTH(ADDR_WIDTH) )      // pointer widths are equal to BRAM address width
    ptr_A1 (
      .clk(clk),
      .loadVal(ptr_A1_loadVal),
      .loadEn(ptr_A1_loadEn),
      .countEn(ptr_A1_countEn),
      .countOut(ptr_A1_countOut),

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  // pointers for port-B
  wire [ADDR_WIDTH-1:0] ptr_B0_loadVal;
  wire                  ptr_B0_loadEn;
  wire                  ptr_B0_countEn;
  wire [ADDR_WIDTH-1:0] ptr_B0_countOut;

  up_counter #(
      .DEBUG(DEBUG),
      .VAL_WIDTH(ADDR_WIDTH) )      // pointer widths are equal to BRAM address width
    ptr_B0 (
      .clk(clk),
      .loadVal(ptr_B0_loadVal),
      .loadEn(ptr_B0_loadEn),
      .countEn(ptr_B0_countEn),
      .countOut(ptr_B0_countOut),

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  wire [ADDR_WIDTH-1:0] ptr_B1_loadVal;
  wire                  ptr_B1_loadEn;
  wire                  ptr_B1_countEn;
  wire [ADDR_WIDTH-1:0] ptr_B1_countOut;

  up_counter #(
      .DEBUG(DEBUG),
      .VAL_WIDTH(ADDR_WIDTH) )      // pointer widths are equal to BRAM address width
    ptr_B1 (
      .clk(clk),
      .loadVal(ptr_B1_loadVal),
      .loadEn(ptr_B1_loadEn),
      .countEn(ptr_B1_countEn),
      .countOut(ptr_B1_countOut),

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  // SR-FF for controlling data-network capture register
  wire netCaptureEn_ff_out;
  wire netCaptureEn_ff_clear;
  wire netCaptureEn_ff_set;

  srFlop #(
      .DEBUG(DEBUG),
      .SET_PRIORITY(0) )     // give "set" higher priority than "clear"
    netCaptureEn_ff (
      .clk(clk),
      .set(netCaptureEn_ff_set),
      .clear(netCaptureEn_ff_clear),
      .outQ(netCaptureEn_ff_out),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
  );


  // SR-FF for controlling PiCaSO local pointer increment enable
  wire picasoPtrIncr_ff_out;
  wire picasoPtrIncr_ff_clear;
  wire picasoPtrIncr_ff_set;

  srFlop #(
      .DEBUG(DEBUG),
      .SET_PRIORITY(0) )     // give "set" higher priority than "clear"
    picasoPtrIncr_ff (
      .clk(clk),
      .set(picasoPtrIncr_ff_set),
      .clear(picasoPtrIncr_ff_clear),
      .outQ(picasoPtrIncr_ff_out),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
  );



  // ---- Local interconnect
  // inputs of ptr_A0
  assign ptr_A0_loadVal = init_ptrA0,
         ptr_A0_loadEn  = loadInit,
         ptr_A0_countEn = incPtrA0;
  
  // inputs of ptr_A1
  assign ptr_A1_loadVal = init_ptrA1,
         ptr_A1_loadEn  = loadInit,
         ptr_A1_countEn = incPtrA1;

  // inputs of ptr_B0
  assign ptr_B0_loadVal = init_ptrB0,
         ptr_B0_loadEn  = loadInit,
         ptr_B0_countEn = incPtrB0;
  
  // inputs of ptr_B1
  assign ptr_B1_loadVal = init_ptrB1,
         ptr_B1_loadEn  = loadInit,
         ptr_B1_countEn = incPtrB1;

  // inputs of SR-FFs
  assign netCaptureEn_ff_set    = setNetCaptureEn,
         netCaptureEn_ff_clear  = clrNetCaptureEn,
         picasoPtrIncr_ff_set   = setPicasoPtrIncr,
         picasoPtrIncr_ff_clear = clrPicasoPtrIncr;

  // output ports
  assign netLevel      = netLevel_reg,
         netCaptureEn  = netCaptureEn_ff_out,
         aluConf       = aluConf_reg,
         opmuxConf     = opmuxConf_reg,
         picasoPtrIncr = picasoPtrIncr_ff_out;

  
  // selPort selects the pointer: sel = 0/1 selects A0/A1 and B0/B1
  assign addrA = (selPortA == 1'b0) ? ptr_A0_countOut : ptr_A1_countOut;
  assign addrB = (selPortB == 1'b0) ? ptr_B0_countOut : ptr_B1_countOut;


  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate
endmodule



