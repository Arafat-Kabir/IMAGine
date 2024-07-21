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
  Date   : Thu, Aug 24, 04:49 PM CST 2023
  Version: v1.0

  Description:
  This module acts as a simple loop counter for FSMs. You load the counter
  with a value then it counts down until it reaches 0. It generates 2 signals:
  val1 and val0.  val1 is set when counter value is equal to 1 and val0 is set
  when counter value reaches 0.
  - val1 can be used to jump to another state at the SAME CYCLE the counter becomes 0.
  - val0 can be used to jump to another state on the NEXT CYCLE after the counter becomes 0.
    val0 also indicates that the counter is sitting idle.

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module loop_counter #(
  parameter DEBUG = 1,
  parameter VAL_WIDTH = -1      // width of the counter value
) (
  clk,
  loadVal,        // value to load into counter
  loadEn,         // load value into the counter
  countEn,        // enable count-down
  val0,           // signal value == 0
  val1,           // signal value == 1

  // Debug probes
  dbg_clk_enable
);

  `AK_ASSERT(VAL_WIDTH>0)


  // IO Ports
  input                 clk;
  input [VAL_WIDTH-1:0] loadVal;
  input                 loadEn;
  input                 countEn;
  output                val0;
  output                val1;


  // Debug probes
  input   dbg_clk_enable;


  // internal signals
  wire local_ce;    // module-level clock enable, needed for debugging support

  (* extract_enable = "yes", extract_reset = "yes" *)
  reg  [VAL_WIDTH-1:0]  count_reg = 0;      // holds current counter value


  /* counter behavior:
  *   - load the loadVal if load requested (highest priority)
  *   - count-down if requested, until you hit 0
  */
  always@(posedge clk) begin
    if(local_ce) begin      // change state only if local_ce == 1
      // counter behavior
      if(loadEn) 
        count_reg <= loadVal;
      else if(countEn && (count_reg > 0))   // don't underflow
        count_reg <= count_reg - 1;
      else
        count_reg <= count_reg;

    end else begin
      count_reg <= count_reg;     // hold the state if local_ce == 0
    end
  end


  // output signals: if count_reg.len <= 5, val0 and val1 together should require only 1 LUT6
  assign val0 = (count_reg == 0);
  assign val1 = (count_reg == 1);



  // ---- Connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;    // no top-level clock enable
    end
  endgenerate


endmodule

