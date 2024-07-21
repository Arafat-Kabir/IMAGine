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
  Date  : Thu, Jul 20, 12:42 PM CST 2023

  Description: 
  This module uses the fullAddSub function with a FF connected to carry/borrow
  to implement a serialized ALU for booth's radix-2 multiplication.

  Version: v1.1
  It's a self-contained module, not importing external function.

================================================================================*/


/*
Usage:
    reset: Use it to reset the registers
    x    : Connect operand-1 stream
    y    : Connect operand-2 stream
    ce   : Clock-enable for registers
    op   : Use it to specify the opcode (use boothR2_alu_param.v)
    out  : Connect the output stream

Op-codes (check fullAddSub function for details/updates)
-----------------------
  op  |      out           
------|----------------
 ADD  |     x + y      
 SUB  |     x - y      
 CPX  |       x        
 CPY  |       y        
-----------------------
*/

`timescale 1ns/100ps


module boothR2_serial_alu #(
  parameter DEBUG = 1
) (
  clk,    // clock
  reset,  // reset registers
  x,      // operand-1 stream
  y,      // operand-2 stream
  ce,     // clock enable
  op,     // op-code
  out,    // ALU output stream

  // debug probes
  dbg_clk_enable,     // debug clock for stepping
  dbg_cb_reg,
  dbg_cb
);


  `include "boothR2_serial_alu.inc.v"


  localparam OP_WIDTH = BOOTHR2_OP_WIDTH;   // short-hand, removing the scope-prefix


  // IO ports
  input                  clk;   
  input                  reset;
  input                  x;   
  input                  y;  
  input                  ce;
  input  [OP_WIDTH-1:0]  op;
  output                 out;

  // debug probes
  input     dbg_clk_enable;
  output    dbg_cb_reg;
  output    dbg_cb;


  // Internal Signals
  (* extract_enable = "yes", extract_reset = "yes" *)
  reg  cb_reg = 0;    // initially starts as 0
  wire cb;
  wire local_ce;      // local clock-enable, needed for debugging


  // Full-Adder/Subtractor (FA/S) logic
  function automatic [1:0] fullAddSub;
    input _x, _y, _cb;
    input [1:0] _op;

    // Internal Signals
    reg _sum, _carry, _borrow;

    begin
      _sum    = _x ^ _y ^ _cb;
      _carry  = (_x & _y)  | (_x & _cb)  | (_y & _cb);
      _borrow = (!_x & _y) | (!_x & _cb) | (_y & _cb);

      // Assign outputs
      (* full_case *)
      case (_op)
          BOOTHR2_ADD: begin
              fullAddSub[0] = _sum;
              fullAddSub[1] = _carry;
          end
          BOOTHR2_SUB: begin
              fullAddSub[0] = _sum;
              fullAddSub[1] = _borrow;
          end
          BOOTHR2_CPX: begin
              fullAddSub[0] = _x;
              fullAddSub[1] = 0;
          end
          BOOTHR2_CPY: begin
              fullAddSub[0] = _y;
              fullAddSub[1] = 0;
          end
      endcase
    end
  endfunction


  // Assign output stream
  assign {cb, out} = fullAddSub(x, y, cb_reg, op);


  // Store the current carry/borrow for the next cycle
  always @(posedge clk) begin
      if(reset)          cb_reg <= 0;       // reset
      else if(local_ce)  cb_reg <= #1 cb;   // save cb if clock-enable is set, wire delay to avoid race-condition in simulation
      else               cb_reg <= cb_reg;  // hold the current value if clock-enable not set
  end


  // Connect debug probes
  generate
    if(DEBUG) begin
      assign dbg_cb_reg = cb_reg;
      assign dbg_cb = cb;
      assign local_ce = ce & dbg_clk_enable;    // debug clock-enable can be used for stepping
    end else begin
      assign local_ce = ce;     // use module ce as local ce
    end
  endgenerate


endmodule
