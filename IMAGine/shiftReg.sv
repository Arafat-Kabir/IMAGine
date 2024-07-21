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
  Date   : Mon, Feb 05, 03:36 PM CST 2024
  Version: v1.0

  Description:
  This is an implementation of a parallel access shift-register. This module
  can be used independently wherever shift-register with parallel read and write
  capabilities are needed.

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module shiftReg #(
  parameter DEBUG = 1,
  parameter REG_WIDTH = -1,
  parameter MSB_IN = 0      // set this to 1 to take the input through MSb, by default inputs through LSb
) ( 
  clk,
  serialIn,             // serial input
  parallelIn,           // parallel input 
  serialOut,            // serial output
  parallelOut,          // parallel output
  shiftEn,              // enables serial shift in/out
  loadEn,               // loads the parallel input (higher priority over shiftEn)

  // Debug probes
  dbg_clk_enable         // debug clock for stepping
);


  // validate module parameters
  `AK_ASSERT2(REG_WIDTH >= 2, REG_WIDTH_must_be_atleast_2)    // if REG_WIDTH < 2, following shifting logic won't work
  `AK_ASSERT2(MSB_IN >= 0, MSB_IN_must_be_0_or_1)
  `AK_ASSERT2(MSB_IN <= 1, MSB_IN_must_be_0_or_1)


  // IO Ports
  input                   clk;
  input                   serialIn;
  input  [REG_WIDTH-1:0]  parallelIn;
  output                  serialOut;
  output [REG_WIDTH-1:0]  parallelOut;
  input                   shiftEn;
  input                   loadEn;

  // Debug probes
  input   dbg_clk_enable;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)


  // ---- Shift register
  (* extract_enable = "yes" *)
  reg  [REG_WIDTH-1:0]  data_reg = 0;
  wire [REG_WIDTH-1:0]  shift_inp;    // input to the shift register for serial input

  generate
    if(MSB_IN) assign shift_inp = {serialIn, data_reg[REG_WIDTH-1:1]};    // serial input through MSb
    else       assign shift_inp = {data_reg[REG_WIDTH-2:0], serialIn};    // serial input through LSb
  endgenerate


  // Typical parallel-access shift register behavior (with debug support)
  always @(posedge clk) begin
    if (local_ce) begin
      // parallel load has higher priority
      if (loadEn) begin
        data_reg <= parallelIn;
      end else if (shiftEn) begin
        data_reg <= shift_inp;
      end else begin
        data_reg <= data_reg;     // hold the previous value
      end
    end

    // hold state for debugging (local_ce == 0) 
    else begin
      data_reg <= data_reg;
    end
  end


  // ---- output ports
  assign parallelOut = data_reg;
  generate
    if(MSB_IN) assign serialOut = data_reg[0];            // serial output is LSb
    else       assign serialOut = data_reg[REG_WIDTH-1];  // serial output is Msb
  endgenerate


  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule


