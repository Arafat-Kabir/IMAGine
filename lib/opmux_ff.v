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
  Date  : Wed, Dec 28, 05:37 PM CST 2022

  Description:
  This module sets the operands for the alu-array based on the given 
  configuration. This version adds output register stage to the opmux_behav.

  Version: v1.1

================================================================================*/


/*
Usage:
    This version is implemented using purely behavioral description.
    
    rf_portA     : Connect port-A of the register-file
    rf_portB     : Connect port-B of the register-file
    net_stream   : Connect data stream coming from the network module
    confSig      : Connect operand-selection configuration signals from FSM
    confLoad     : Connect clock-enable coming from FSM
    opnX         : Connect operand-X of ALU
    opnY         : Connect operand-Y of the ALU

    It does not have a reset because it is not essential.
*/

`timescale 1ns/100ps
`include "ak_macros.v"


module opmux_ff #(
  parameter DEBUG = 1,
  parameter RF_STREAM_WIDTH = 16,
  parameter NET_STREAM_WIDTH = 1
) (
  clk,            // clock
  rf_portA,       // Port-A of the register-file
  rf_portB,       // Port-B of the register-file
  net_stream,     // data stream coming from the network module
  confSig,        // operand-selection configuration signals
  confLoad,       // clock-enable for configuration register

  ceOut,          // output register clock enable
  opnX,           // Operand-X output
  opnY,           // Operand-Y output

  // debug probes
  dbg_clk_enable,     // debug clock for stepping
  dbg_conf_reg,       // value of conf_reg
  dbg_opnX_reg_in,    // input to opnX_reg
  dbg_opnY_reg_in     // input to opnY_reg
);


  `include "opmux_ff.inc.v"

  localparam dbg_yn = DEBUG ? "yes" : "no";     // used to conditionally mark debug signals


  localparam                  OPN_WIDTH = RF_STREAM_WIDTH;    // operand width
  localparam [OPN_WIDTH-1:0]  ZEROS = 0;       // a combination of all-zeros, used for padding


  // IO Ports
  input                           clk;
  input   [RF_STREAM_WIDTH-1:0]   rf_portA;
  input   [RF_STREAM_WIDTH-1:0]   rf_portB;
  input   [NET_STREAM_WIDTH-1:0]  net_stream;    // for bit-serial, this will probably always be 1-bit
  input   [OPMUX_CONF_WIDTH-1:0]  confSig;       // OPMUX_CONF_WIDTH defined in the include file
  input                           confLoad;
  input                           ceOut;
  output  [OPN_WIDTH-1:0]         opnX;
  output  [OPN_WIDTH-1:0]         opnY;

  // Debug probes
  input                          dbg_clk_enable;
  (* dont_touch = dbg_yn, mark_debug = dbg_yn *)
  output [OPMUX_CONF_WIDTH-1:0]  dbg_conf_reg;
  output [OPN_WIDTH-1:0]         dbg_opnX_reg_in;
  output [OPN_WIDTH-1:0]         dbg_opnY_reg_in;


  // Internal signals
  (* extract_enable = "yes" *)
  reg  [OPMUX_CONF_WIDTH-1:0]  conf_reg = 0;     // default reset value; no explicit reset
  wire local_ce;      // local clock-enable, needed for debugging


  // Load configuration to the conf_reg register when requested
  always @(posedge clk) begin
    if(confLoad && local_ce)    // update value only if confLoad set
        conf_reg <= confSig;    // load the requested configruation 
    else
        conf_reg <= conf_reg;   // if confLoad not set, hold the current value
  end


  // Output registers
  (* extract_enable = "yes" *)
  reg  [OPN_WIDTH-1:0]  opnX_reg = 0,     // no explicit reset
                        opnY_reg = 0;
  wire [OPN_WIDTH-1:0]  muxX_out;
  wire [OPN_WIDTH-1:0]  muxY_out;


  // Operand-X Muxing function
  function automatic [OPN_WIDTH-1:0] mux_X;
    input [OPN_WIDTH-1:0]         _A;
    input [OPMUX_CONF_WIDTH-1:0]  _select;
    // Muxing logic
    if(_select==OPMUX_0_OP_B)  mux_X = ZEROS;
    else mux_X = _A;
  endfunction

  assign muxX_out = mux_X(rf_portA, conf_reg);

  always @(posedge clk) begin
    if(ceOut && local_ce)     // update value only if output clock-enable set
      opnX_reg <= muxX_out;   // load mux-X output
    else
      opnX_reg <= opnX_reg;   // otherwise, hold the current value
  end

  assign opnX = opnX_reg;         // assign register value to the output port



  // Operand-Y Muxing function
  `AK_ASSERT(RF_STREAM_WIDTH==16)   // mux_Y is specifically written for RF_STREAM_WIDTH=16

  function automatic [OPN_WIDTH-1:0] mux_Y;
    input [OPN_WIDTH-1:0]         _A;
    input [OPN_WIDTH-1:0]         _B;
    input [NET_STREAM_WIDTH-1:0]  _net;
    input [OPMUX_CONF_WIDTH-1:0]  _select;

    // Internal signals
    reg [OPN_WIDTH-1:0] _foldA_1;
    reg [OPN_WIDTH-1:0] _foldA_2;
    reg [OPN_WIDTH-1:0] _foldA_3;
    reg [OPN_WIDTH-1:0] _foldA_4;
    reg [OPN_WIDTH-1:0] _net_comb;
    
    // Different sub-sizes of the operand width
    localparam HALF    = OPN_WIDTH/2,
               QUART   = OPN_WIDTH/4,
               HQUART  = OPN_WIDTH/8,     // Half-Quarter
               HHQUART = OPN_WIDTH/16;    // Half-Quarter/2

    begin
      // Muxing combinations
      _foldA_1  = {ZEROS[HALF +: HALF],          _A[HALF +: HALF]};        // Y[lower-half] = A[upper-half],     Y[remain] = 0
      _foldA_2  = {ZEROS[QUART +: QUART*3],      _A[QUART +: QUART]};      // Y[lower-quarter] = A[2nd-quarter], Y[remain] = 0
      _foldA_3  = {ZEROS[HQUART +: HQUART*7],    _A[HQUART +: HQUART]};    // Y[lq/2] = A[lq/2u],                Y[remain] = 0
      _foldA_4  = {ZEROS[HHQUART +: HHQUART*15], _A[HHQUART +: HHQUART]};  // Y[lq/4] = A[lq/4u],                Y[remain] = 0
      _net_comb = {ZEROS[OPN_WIDTH-1:NET_STREAM_WIDTH], _net};             // Y[lower-bits] = net,               Y[upper-bits] = 0

      // Muxing logic
      (* full_case, parallel_case *)
      case (_select)
        OPMUX_A_OP_B   : mux_Y = _B; 
        OPMUX_A_FOLD_1 : mux_Y = _foldA_1; 
        OPMUX_A_FOLD_2 : mux_Y = _foldA_2; 
        OPMUX_A_FOLD_3 : mux_Y = _foldA_3; 
        OPMUX_A_FOLD_4 : mux_Y = _foldA_4; 
        OPMUX_A_OP_NET : mux_Y = _net_comb; 
        OPMUX_0_OP_B   : mux_Y = _B; 
        OPMUX_A_OP_0   : mux_Y = ZEROS;       // TODO: Need to test this modification
        default        : mux_Y = _B; 
      endcase
    end
  endfunction

  assign muxY_out = mux_Y(rf_portA, rf_portB, net_stream, conf_reg);

  always @(posedge clk) begin
    if(ceOut && local_ce)     // update value only if output clock-enable set
      opnY_reg <= muxY_out;   // load mux-X output
    else
      opnY_reg <= opnY_reg;   // otherwise, hold the current value
  end

  assign opnY = opnY_reg;     // assign register value to the output port


  // connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
      assign dbg_conf_reg = conf_reg;
      assign dbg_opnX_reg_in = muxX_out;
      assign dbg_opnY_reg_in = muxY_out;
    end else begin
      assign local_ce = 1;     // there is no top-level clock enable control
    end
  endgenerate


endmodule
