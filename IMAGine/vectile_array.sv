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
  Date   : Tue, Feb 27, 05:04 PM CST 2024
  Version: v1.0

  Description:
  A 1D vecshift_tile array is created. It'll probably require pipeline stages to
  fanout the input signals to the tile inputs. The dimensions of the tiles and
  the tile-array can be varied to study the performance numbers for a given size.

================================================================================*/



`timescale 1ns/100ps
`include "ak_macros.v"


module vectile_array #(
  parameter DEBUG = 1,
  parameter REG_WIDTH = -1,
  parameter REG_COUNT = -1,         // Total no. of vector-shift registers in the whole array
  parameter TILE_HEIGHT = -1,       // Number of vector-shift registers in a tile
  parameter INTERTILE_STAGE = 0     // Number of pipeline stages between consecutive tiles
) (
  clk,
  // control signals
  instruction,          // instruction for the tile controller
  inputValid,           // Single-bit input signal, 1: other input signals are valid, 0: other input signals not valid (this is needed to work with shift networks)
  // data IOs
  serialIn,             // serial data input array
  serialIn_valid,       // indicates if the serial input data is valid (array)
  parallelOut,          // parallel output to the above tile
  statusOut,            // output status bits to the above tile

  // Debug probes
  dbg_clk_enable        // debug clock for stepping
);


  `include "vecshift_tile.svh"


  // validate module parameters
  `AK_ASSERT2(REG_WIDTH > 0, REG_WIDTH_must_be_set)
  `AK_ASSERT2(REG_COUNT > 0, REG_COUNT_must_be_set)
  `AK_ASSERT2(TILE_HEIGHT > 0, TILE_HEIGHT_must_be_set)

  // remove scope prefix for short-hand
  localparam INSTR_WIDTH  = VECSHIFT_INSTR_WIDTH,
             CONFIG_WIDTH = VECSHIFT_CONFIG_WIDTH,
             STATUS_WIDTH = VECSHIFT_STATUS_WIDTH;

  // IO Ports
  input                     clk;
  input  [INSTR_WIDTH-1:0]  instruction;
  input                     inputValid;
  input                     serialIn[REG_COUNT];         // array of serial input
  input                     serialIn_valid[REG_COUNT];   // array of serial input valid signals
  output [REG_WIDTH-1:0]    parallelOut;
  output [STATUS_WIDTH-1:0] statusOut;

  // Debug probes
  input dbg_clk_enable;

  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)



  // -- Tile array instantiation
  localparam TOT_TILE  = `DIV_CEIL(REG_COUNT, TILE_HEIGHT),   // total no. of tiles (full + partial)
             FULL_CNT  = REG_COUNT/TILE_HEIGHT,               // no. of full-tiles
             PART_REG_CNT = REG_COUNT%TILE_HEIGHT;            // no. of regs in a partial-tile

  // Signal arrays connecting to each tile
  logic [TILE_HEIGHT-1:0]  tile_serialIn[TOT_TILE];
  logic [TILE_HEIGHT-1:0]  tile_serialIn_valid[TOT_TILE];
  logic [REG_WIDTH-1:0]    tile_parallelIn[TOT_TILE];
  logic [REG_WIDTH-1:0]    tile_parallelOut[TOT_TILE];
  logic [STATUS_WIDTH-1:0] tile_statusIn[TOT_TILE];
  logic [STATUS_WIDTH-1:0] tile_statusOut[TOT_TILE];


  genvar g_tile, gi;


  // following macro is used as an instantiation template
  `define INST_TILE(tile_height, is_last)   \
            vecshift_tile #(                \
                .DEBUG(DEBUG),              \
                .REG_WIDTH(REG_WIDTH),      \
                .TILE_HEIGHT(tile_height),  \
                .ISLAST_TILE(is_last) )     \
              vectile (                     \
                .clk(clk),                  \
                .instruction    (instruction),   \
                .inputValid     (inputValid),    \
                .serialIn       (tile_serialIn[g_tile]       [tile_height-1:0] ),  \
                .serialIn_valid (tile_serialIn_valid[g_tile] [tile_height-1:0]),   \
                .parallelIn     (tile_parallelIn[g_tile]),   \
                .parallelOut    (tile_parallelOut[g_tile]),   \
                .statusIn       (tile_statusIn[g_tile]),     \
                .statusOut      (tile_statusOut[g_tile]),    \
                .dbg_clk_enable(dbg_clk_enable)              \
            );


  // instantiation loop 
  generate
    for(g_tile = 0; g_tile < TOT_TILE; ++g_tile) begin: tile
      `INST_TILE(
        (g_tile<FULL_CNT ? TILE_HEIGHT : PART_REG_CNT),   // selects between full/partial tile height
        (g_tile==TOT_TILE-1 ? 1 : 0)    // checks if this the last tile
      )
    end
  endgenerate


  // -- Interconnect
  generate
    // inter-tile connection: bottom-out -> top-in
    for(g_tile = 0; g_tile < TOT_TILE; ++g_tile) begin
      if(g_tile != TOT_TILE-1) begin
        assign tile_parallelIn[g_tile] = tile_parallelOut[g_tile+1];
        assign tile_statusIn[g_tile]   = tile_statusOut[g_tile+1];
      end else begin
        // the last tile
        assign tile_parallelIn[g_tile] = '0;
        assign tile_statusIn[g_tile]   = '0;   // not isData, not isLast
      end
    end

    // top-level serial input singals
    for(gi = 0; gi < REG_COUNT; ++gi) begin
      // tile_id = gi / TILE_HEIGHT,   tile_reg = gi % TILE_HEIGHT
      assign tile_serialIn[gi/TILE_HEIGHT] [gi%TILE_HEIGHT] = serialIn[gi];
      assign tile_serialIn_valid[gi/TILE_HEIGHT] [gi%TILE_HEIGHT] = serialIn_valid[gi];
    end
  
    // top-level output signals
    assign parallelOut = tile_parallelOut[0];
    assign statusOut   = tile_statusOut[0];
  endgenerate


  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


  // -- remove temporary macros
  `undef INST_TILE

endmodule

