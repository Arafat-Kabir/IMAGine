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

  Author: MD Arafat Kabir
  Email : arafat.sun@gmail.com
  Date  : Mon, Aug 21, 04:34 PM CST 2023

  Description:
  This module implements a dual-control set/reset flip-flop. It can be set or
  reset using 2 different signals. Priority of the signals can be set using
  parameter.

  Version: v1.0

================================================================================*/
`timescale 1ns/100ps


module srFlop #(
  parameter DEBUG = 1,
  parameter SET_PRIORITY = 0      // 0: set has higher priority, otherwise clear has higher priority
) (
  clk,        // clock
  set,
  clear,
  outQ,       // output port

  // Debug probes
  dbg_clk_enable
);

  // IO Ports
  input clk, set, clear;
  output outQ;

  // debug probes
  input dbg_clk_enable;


  // Internal signal
  (* extract_enable = "yes", extract_reset = "yes" *)
  reg flop = 0;        // default state cleared
  wire local_ce;       // for module-level clock-enable (isn't passed to submodules)

  assign outQ = flop;

  
  // instantiate set/clear logic
  generate
    if(SET_PRIORITY == 0) begin
      // flop with higher priority for set
      always@(posedge clk) begin
        if(local_ce) begin
          if(set) flop <= 1;
          else if(clear) flop <= 0;
          else flop <= flop;
        end else begin
          flop <= flop;     // if local_ce==0, hold the state
        end
      end
    end

    else begin
      // flop with higher priority for clear
      always@(posedge clk) begin
        if(local_ce) begin
          if(clear) flop <= 0;
          else if(set) flop <= 1;
          else flop <= flop;
        end else begin
          flop <= flop;     // if local_ce==0, hold the state
        end
      end
    end
  endgenerate


  // connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;    // there is not top-level clock enable signal
    end
  endgenerate

endmodule
