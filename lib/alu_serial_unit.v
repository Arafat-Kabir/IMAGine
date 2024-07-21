/*********************************************************************************
* Copyright (c) 2022, Computer Systems Design Lab, University of Arkansas        *
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

  Author: MD Arafat Kabir
  Email : arafat.sun@gmail.com
  Date  : Thu, Jul 20, 12:39 PM CST 2023

  Description: 
  This module uses the boothR2_serial_alu module to build the configurable
  alu unit for PiCaSO.

  Version: v1.1
  <----update me---->

================================================================================*/


/*
Usage:
    x       : Connect operand-1 stream
    y       : Connect operand-2 stream
    ce      : Clock-enable for registers
    opConfig: Use it to specify a given op or use booth's encoding
    opLoad  : Use to load the specified op
    reset   : Use it to reset the registers
    out     : Connect the output stream

check alu_serial_unit_params.v for opConfig codes.
*/

`timescale 1ns/100ps


module alu_serial_unit #(
  parameter DEBUG = 1
) (
  clk,        // clock
  reset,      // reset registers
  x,          // operand-1 stream
  y,          // operand-2 stream
  ce_alu,     // clock enable for the ALU registers
  opConfig,   // configures op-code register
  opLoad,     // clock-enable for the op-code register
  resetMbit,  // resets prevMbit register
  loadMbit,   // loads data into prevMbit register
  out,        // ALU output stream

  // debug probes
  dbg_clk_enable,     // debug clock for stepping
  dbg_op_reg,
  dbg_op_reg_in,
  dbg_cb_reg,
  dbg_cb_reg_in,
  dbg_prevMbit_reg,
  dbg_prevMbit_reg_in
);


  `include "boothR2_serial_alu.inc.v"
  `include "alu_serial_unit.inc.v"


  localparam OP_WIDTH = ALU_OP_WIDTH;  // short-hand, removing the scope-prefix


  // IO ports
  input                  clk;   
  input                  reset;
  input                  x;   
  input                  y;  
  input                  ce_alu;
  input  [OP_WIDTH-1:0]  opConfig;
  input                  opLoad;
  input                  resetMbit;
  input                  loadMbit;
  output                 out;

  // Debug probes
  input                         dbg_clk_enable;
  output [BOOTHR2_OP_WIDTH-1:0] dbg_op_reg;
  output [BOOTHR2_OP_WIDTH-1:0] dbg_op_reg_in;
  output                        dbg_cb_reg;
  output                        dbg_cb_reg_in;
  output                        dbg_prevMbit_reg;
  output                        dbg_prevMbit_reg_in;




  /*
  Booth'r Radix-2 Encoding table
  -----------------------------------------------------
    mult |  Return code
  -------|---------------------------------------------
    00   |  Copy-X (no change to partial product, NOP)
    01   |  ADD    (X + Y)
    10   |  SUB    (X - Y)
    11   |  COPY-X (no change to partial product, NOP)
  -----------------------------------------------------
  */
  function automatic [1:0] boothEncode2;
    input [1:0] _mult;

    begin
      // Booth's radix-2 encoding
      (* full_case, parallel_case *)
      case (_mult) 
          2'b00: boothEncode2 = BOOTHR2_CPX;   // NOP
          2'b01: boothEncode2 = BOOTHR2_ADD;
          2'b10: boothEncode2 = BOOTHR2_SUB;
          2'b11: boothEncode2 = BOOTHR2_CPX;   // NOP
      endcase
    end
  endfunction


  /*
  opEncoder table (function):
    Encoder to generate op-codes for the boothR2_serial_alu module.
    This is basically a multiplixer to select between the given op-code or booth's
    radix-2 encoding based op-code.
    This function should fit in a LUT-6 (2xLUT5)
  -------------------------------------------------------------
    opConfig |  op-code (func[1:0])
  -------------------------------------------------------------
    0xx      |  opConfig[1:0]
    1xx      |  booth's radix-2 encoding using multiplier bits
  -------------------------------------------------------------
  */
  function automatic [1:0] opEncoder;

    input [2:0] _opConfig;
    input [1:0] _mbits;

    // Internal signals
    reg          _booth;
    reg   [1:0]  _opBooth;
    reg   [1:0]  _opGiven;

    begin
      _booth   = _opConfig[2];     // the upper-most bit decides which encoding to use
      _opGiven = _opConfig[1:0];
      _opBooth = boothEncode2(_mbits);
      
      // Assign output
      if(_booth) opEncoder = _opBooth;  // set booth's encoding if requested
      else       opEncoder = _opGiven;  // otherwise, load the given op-code
    end
  endfunction


  // Internal Signals
  (* extract_enable = "yes", extract_reset = "yes" *)
  reg   prevMbit_reg = 0;   // default reset value, it has explicit reset
  wire  prevMbit_reg_in;    // input to the prevMbit_reg

  (* extract_enable = "yes", extract_reset = "yes" *)
  reg  [BOOTHR2_OP_WIDTH-1 : 0] op_reg = 0;       // default reset value, it has explicit reset
  wire [BOOTHR2_OP_WIDTH-1 : 0] op_reg_in;
  wire local_ce;      // local clock-enable, needed for debugging


  // Previous multiplier bit storage register
  always @(posedge clk) begin
    if (local_ce) begin  // don't change state if local_ce is low
      if (resetMbit)     prevMbit_reg <= 0;               // clear the mbit-reg if requested
      else if (loadMbit) prevMbit_reg <= prevMbit_reg_in; // load the register if requested
      else               prevMbit_reg <= prevMbit_reg;    // otherwise, hold the old value
    end
  end

  assign prevMbit_reg_in = x;   // for booth's radix-2, multiplier-bit will be coming through x


  // Load op-code to the op_reg register based on the requested configuration
  always @(posedge clk) begin
      if(reset) 
          op_reg <= 0;              // should correspond to BOOTHR2_ADD
      else if(opLoad && local_ce)   // update value only if opLoad requested (and debug clock set)
          op_reg <= op_reg_in;      // load the op-code for the requested configuration
      else
          op_reg <= op_reg;         // if opLoad not set, hold the current value
  end

  assign op_reg_in = opEncoder(opConfig, {x, prevMbit_reg});   // generate input for op_reg. x: current multiplier bit, prevMbit: previous multiplier bit



  // The full-adder/subtractor for booth's radix-2 multiplication
  boothR2_serial_alu #(.DEBUG(DEBUG))
    boothR2_ALU (
      .clk(clk),
      .reset(reset),
      .x(x), 
      .y(y),
      .ce(ce_alu),
      .op(op_reg),
      .out(out),

      // debug probes
      .dbg_clk_enable(local_ce),
      .dbg_cb_reg(dbg_cb_reg),
      .dbg_cb(dbg_cb_reg_in)
  );


  // Connect debug probes
  generate
    if (DEBUG) begin
      assign local_ce = dbg_clk_enable;    // AND local_ce with ce of different sub-modules
      assign dbg_op_reg = op_reg;
      assign dbg_op_reg_in = op_reg_in;
      assign dbg_prevMbit_reg = prevMbit_reg;
      assign dbg_prevMbit_reg_in = prevMbit_reg_in;
      // NOTE: dbg_cb_reg and dbg_cb_reg_in are directly connect to boothR2_ALU
    end else begin
      assign local_ce = 1;     // there is no top-level clock enable control
    end
  endgenerate


endmodule
