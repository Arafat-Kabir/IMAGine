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
  Date  : Wed, Jul 26, 04:00 PM CST 2023

  Description: 
  BRAM configured in write-first mode with output register

  Version: v1.1 
  Adjusted a little bit from v1.0 for debuggging


================================================================================*/


`timescale 1ns/100ps


module bram_wrfirst_ff #(
  parameter DEBUG = 1,          // there is no debug signals here, this parameter is defined for consistency with other modules
  parameter RAM_WIDTH = 16,
  parameter RAM_DEPTH = 1024
)(
  clk,
  wea,      // write enable port-A
  web,      // write enable port-B
  addra,    // address to write data at port-A
  addrb,    // address to write data at port-B
  dia,      // data input port-A
  dib,      // data input port-B
  doa,      // data output port-A
  dob       // data output port-B
);


  `include "clogb2_func.v"

  localparam  ADDR_WIDTH = clogb2(RAM_DEPTH-1);


  // IO ports
  input  wire                     clk, wea, web;
  input  wire  [ADDR_WIDTH-1:0]   addra, addrb;
  input  wire  [RAM_WIDTH-1 :0]   dia, dib;
  output reg   [RAM_WIDTH-1 :0]   doa, dob;


  // Memory
  (* ram_style = "block" *) 
  reg[RAM_WIDTH-1:0] ram[RAM_DEPTH-1:0];   // * synthesis syn_ramstyle=no_rw_check */ // this meta-comment's effect needs to be tested	
  reg [RAM_WIDTH-1:0] doaR, dobR;          // BRAM output registers


  // Port-A
  always @(posedge clk) begin
    if (wea) begin
      doaR <= dia;            // write-first mode: HDL coding practices page-12 pdf
      ram[addra] <= dia;
    end else begin
      doaR <= ram[addra];     // always reading from RAM
    end
  end


  // Port-B
  always @(posedge clk) begin  
    if (web) begin
      dobR <= dib;
      ram[addrb] <= dib;
    end else begin
      dobR <= ram[addrb];
    end
  end


  // Output registers
  always @(posedge clk) 
  begin  
    doa <= doaR;
    dob <= dobR;
  end


endmodule

