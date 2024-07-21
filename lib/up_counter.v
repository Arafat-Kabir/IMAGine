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
  Date   : Thu, Aug 24, 06:03 PM CST 2023
  Version: v1.0

  Description:
  This module implements an upcounter. It can be used as pointer with the
  algorithm FSMs.

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module up_counter #(
  parameter DEBUG = 1,
  parameter VAL_WIDTH = -1      // width of the counter value
) (
  clk,
  loadVal,        // value to load into counter
  loadEn,         // load value into the counter
  countEn,        // enable count-up
  countOut,       // counter current value

  // Debug probes
  dbg_clk_enable
);


  `AK_ASSERT(VAL_WIDTH>0)


  // IO Ports
  input                  clk;
  input  [VAL_WIDTH-1:0] loadVal;
  input                  loadEn;
  input                  countEn;
  output [VAL_WIDTH-1:0] countOut;


  // Debug probes
  input   dbg_clk_enable;


  // internal signals
  wire local_ce;    // module-level clock enable, needed for debugging support

  (* extract_enable = "yes", extract_reset = "yes" *)
  reg  [VAL_WIDTH-1:0]  count_reg = 0;      // holds current counter value


  /* counter behavior:
  *   - load the loadVal if load requested (highest priority)
  *   - count-up if requested (does not check for overflow)
  */
  always@(posedge clk) begin
    if(local_ce) begin      // change state only if local_ce == 1
      // counter behavior
      if(loadEn) 
        count_reg <= loadVal;
      else if(countEn)
        count_reg <= count_reg + 1;
      else
        count_reg <= count_reg;

    end else begin
      count_reg <= count_reg;     // hold the state if local_ce == 0
    end
  end

  assign countOut = count_reg;


  // ---- Connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;    // no top-level clock enable
    end
  endgenerate


endmodule
