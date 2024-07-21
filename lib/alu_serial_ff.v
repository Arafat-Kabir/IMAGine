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
  Date  : Wed, Dec 28, 05:40 PM CST 2022

  Description: 
  This module instantiates an array of alu_serial_unit module to build the
  compute module to be used in the PE-block16. This version adds a stage
  of register at the output.

================================================================================*/


/*
Usage:
    x_streams   : Connect operand-1 streams
    y_streams   : Connect operand-2 streams
    ce          : Clock-enable for registers
    opConfig    : Use it to specify a given op or use booth's encoding
    opLoad      : Use to load the specified op
    reset       : Use it to reset the registers
    out_streams : Connect the output streams
*/


`timescale 1ns/100ps


module alu_serial_ff #(
  // Parameters
  parameter DEBUG = 1,
  parameter STREAM_WIDTH = 16   // How many x/y streams are coming
)(
  clk,         // clock
  reset,       // reset registers
  x_streams,   // operand-1 streams
  y_streams,   // operand-2 streams
  ce_alu,      // clock enable for the ALU registers
  opConfig,    // configures op-code register
  opLoad,      // clock-enable for the op-code register
  resetMbit,   // resets prevMbit register
  loadMbit,    // loads data into prevMbit register
  out_streams, // ALU output stream

  // debug probes
  dbg_clk_enable,     // debug clock for stepping
  dbg_out_reg,        // output register values
  dbg_out_reg_in      // output register inputs 
);


  `include "boothR2_serial_alu.inc.v"
  `include "alu_serial_unit.inc.v"


  // IO ports
  input                      clk;   
  input                      reset;
  input  [STREAM_WIDTH-1:0]  x_streams;   
  input  [STREAM_WIDTH-1:0]  y_streams;  
  input                      ce_alu;
  input  [ALU_OP_WIDTH-1:0]  opConfig;
  input                      opLoad;
  input                      resetMbit;
  input                      loadMbit;
  output [STREAM_WIDTH-1:0]  out_streams;

  // Debug probes
  input                         dbg_clk_enable;
  output [STREAM_WIDTH-1:0]     dbg_out_reg;
  output [STREAM_WIDTH-1:0]     dbg_out_reg_in;


  // Internal signals
  (* extract_enable = "yes" *)
  reg  [STREAM_WIDTH-1:0]  out_streams_reg = 0;     // output buffer register
  wire [STREAM_WIDTH-1:0]  alu_arr_out;
  wire local_ce;      // local clock-enable, needed for debugging


  // ---- internal debug probe array ----
  // Conditionally make "untouched" debug probes
  localparam dbg_yn = DEBUG ? "yes" : "no";

  (* dont_touch = dbg_yn, mark_debug = dbg_yn *)  reg [BOOTHR2_OP_WIDTH-1:0] dbg_op_reg[STREAM_WIDTH-1:0];
  (* dont_touch = dbg_yn *)                       reg [BOOTHR2_OP_WIDTH-1:0] dbg_op_reg_in[STREAM_WIDTH-1:0];
  (* dont_touch = dbg_yn *)                       reg                        dbg_cb_reg[STREAM_WIDTH-1:0];
  (* dont_touch = dbg_yn *)                       reg                        dbg_cb_reg_in[STREAM_WIDTH-1:0];

  // make flat wires for connecting to array instances, then connect with debug
  // probe arrays for convenient debugging using array index.
  wire [BOOTHR2_OP_WIDTH*STREAM_WIDTH-1:0] flat_dbg_op_reg;
  wire [BOOTHR2_OP_WIDTH*STREAM_WIDTH-1:0] flat_dbg_op_reg_in;
  wire [STREAM_WIDTH-1:0]                  flat_dbg_cb_reg;
  wire [STREAM_WIDTH-1:0]                  flat_dbg_cb_reg_in;

  always @* begin: connect_loop
    integer i;
    for(i=0; i<STREAM_WIDTH; i=i+1) begin
      dbg_op_reg[i] = flat_dbg_op_reg[i*BOOTHR2_OP_WIDTH +: BOOTHR2_OP_WIDTH];
      dbg_op_reg_in[i] = flat_dbg_op_reg_in[i*BOOTHR2_OP_WIDTH +: BOOTHR2_OP_WIDTH];
      dbg_cb_reg[i] = flat_dbg_cb_reg[i];
      dbg_cb_reg_in[i] = flat_dbg_cb_reg_in[i];
    end
  end
  // ---- END: internal probe array ----




  /* Array of alu_serial_unit modules
  *  Connection summary:
  *     alu_unit_arr[i].x   <- x_streams[i]
  *     alu_unit_arr[i].y   <- y_streams[i]
  *     alu_unit_arr[i].out -> out_streams[i]
  */
  alu_serial_unit #(.DEBUG(DEBUG))
    alu_unit_arr[STREAM_WIDTH-1:0] (
      .clk(clk),
      .reset(reset),
      .x(x_streams),         // array connection
      .y(y_streams),         // array connection
      .ce_alu(ce_alu),
      .opConfig(opConfig),
      .opLoad(opLoad),
      .resetMbit(resetMbit),
      .loadMbit(loadMbit),
      .out(alu_arr_out),     // array connection

      // debug probes
      .dbg_clk_enable(dbg_clk_enable),      // debug clock for stepping
      .dbg_op_reg(flat_dbg_op_reg),         // array connection
      .dbg_op_reg_in(flat_dbg_op_reg_in),   // array connection
      .dbg_cb_reg(flat_dbg_cb_reg),         // array connection
      .dbg_cb_reg_in(flat_dbg_cb_reg_in)    // array connection
  );


  // Update the output registers only if clock-enable is set
  always @(posedge clk) begin
      if(ce_alu && local_ce)             
          out_streams_reg <= alu_arr_out;
      else
          out_streams_reg <= out_streams_reg; 
  end

  assign out_streams = out_streams_reg;   // assign the register value to the output port


  // connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
      assign dbg_out_reg = out_streams_reg;
      assign dbg_out_reg_in = alu_arr_out;
      // NOTE: dbg_op_reg, dbg_op_reg_in, dbg_cb_reg, dbg_cb_reg_in are directly
      // connected to alu_unit_arr via their flat versions.

    end else begin
      assign local_ce = 1;     // there is no top-level clock enable control
    end
  endgenerate


endmodule
