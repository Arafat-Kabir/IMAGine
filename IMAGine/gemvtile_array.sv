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
  Date   : Thu, Feb 08, 05:12 PM CST 2024
  Version: v1.0

  Description:
  A 2D gemvtile array is created. It'll probably require pipeline stages to
  fanout the input signals to the tile inputs. The dimensions of the tiles and
  the tile-array can be varied to study the performance numbers for a given size.


================================================================================*/



`timescale 1ns/100ps
`include "ak_macros.v"


module gemvtile_array #(
  parameter DEBUG = 1,
  parameter BLK_ROW_CNT  = 32,   // No. of PiCaSO rows in the entire array
  parameter BLK_COL_CNT  = 4,    // No. of PiCaSO columns in the entire array
  parameter TILE_ROW_CNT = 16,   // No. of PiCaSO rows in a tile
  parameter TILE_COL_CNT = 2     // No. of PiCaSO columns in a tile
) (
  clk,
  instruction,
  inputValid,
  serialOut,
  serialOutValid
);

  `include "picaso_instruction_decoder.inc.v"

  localparam  NET_STREAM_WIDTH = 1;   // TODO: Should be imported


  // -- Module IOs
  input                                 clk;
  input  [PICASO_INSTR_WORD_WIDTH-1:0]  instruction;
  input                                 inputValid;
  output logic                          serialOut[BLK_ROW_CNT];
  output logic                          serialOutValid[BLK_ROW_CNT];


  // -- Tile array instantiation
  localparam TOT_ROWS  = `DIV_CEIL(BLK_ROW_CNT, TILE_ROW_CNT),    // total tile rows (full + partial)
             TOT_COLS  = `DIV_CEIL(BLK_COL_CNT, TILE_COL_CNT),    // total tile columns (full + partial)
             FULL_ROWS = BLK_ROW_CNT/TILE_ROW_CNT,      // no. of rows with a full-tile
             FULL_COLS = BLK_COL_CNT/TILE_COL_CNT,      // no. of columns with a full-tile
             PART_ROW_CNT = BLK_ROW_CNT%TILE_ROW_CNT,   // no. of rows in a partial-tile
             PART_COL_CNT = BLK_COL_CNT%TILE_COL_CNT;   // no. of columns in a partial-tile

  // Signal arrays connecting to each tile
  wire [NET_STREAM_WIDTH-1:0] tile_eastIn[TOT_ROWS][TOT_COLS][TILE_ROW_CNT];
  wire [NET_STREAM_WIDTH-1:0] tile_westOut[TOT_ROWS][TOT_COLS][TILE_ROW_CNT];
  wire                        tile_serialOut[TOT_ROWS][TOT_COLS][TILE_ROW_CNT];
  wire                        tile_serialOutValid[TOT_ROWS][TOT_COLS][TILE_ROW_CNT];


  genvar g_row, g_col;

  // following macro is used as an instantiation template
  `define INST_TILE(row_cnt, col_cnt) \
            (* keep_hierarchy = "yes" *)  \
            gemvtile #(                                 \
                .ROW_CNT(row_cnt),                      \
                .COL_CNT(col_cnt),                      \
                .START_ROW_ID(g_row * TILE_ROW_CNT),    \
                .START_COL_ID(g_col * TILE_COL_CNT))    \
              tile_inst (                               \
                .clk(clk),                              \
                .instruction(instruction),              \
                .token_in('0),                          \
                .inputValid(inputValid),                \
                .eastIn(tile_eastIn[g_row][g_col][0:row_cnt-1]),                \
                .westOut(tile_westOut[g_row][g_col][0:row_cnt-1]),              \
                .serialOut(tile_serialOut[g_row][g_col][0:row_cnt-1]),          \
                .serialOutValid(tile_serialOutValid[g_row][g_col][0:row_cnt-1]) \
              );


  // instantiation loop 
  generate 
    for(g_row = 0; g_row < TOT_ROWS; g_row++) begin: tile_row
      for(g_col = 0; g_col < TOT_COLS; g_col++) begin: tile_col

        // AK-NOTE: parenthesis is required around conditionals to be used as macro parameter
        `INST_TILE( 
            ((g_row < FULL_ROWS) ? TILE_ROW_CNT : PART_ROW_CNT), 
            ((g_col < FULL_COLS) ? TILE_COL_CNT : PART_COL_CNT) 
        )

      end   // tile_col
    end   // tile_row
  endgenerate


  // -- Interconnect
  generate
    // inter-tile data network
    for(g_row = 0; g_row < TOT_ROWS; g_row++) begin
      for(g_col = 0; g_col < TOT_COLS - 1; g_col++) begin
        // connect this tile to its right neighbor
        assign tile_eastIn[g_row][g_col] = tile_westOut[g_row][g_col+1];
      end
      assign tile_eastIn[g_row][TOT_COLS-1] = '{default: 0};    // right-most eastIn gets always zeros
    end
  endgenerate


  // edge tiles west-side outputs to top-level port connections
  always@* begin
    int trow, i, j;
    j = 0;
    // full-row connections
    for(trow = 0; trow < FULL_ROWS; ++trow) begin
      for(i = 0; i < TILE_ROW_CNT; ++i) begin
        serialOut[j] = tile_serialOut[trow][0][i];
        serialOutValid[j] = tile_serialOutValid[trow][0][i];
        ++j;
      end
    end
    // partial-row connections
    for(i = 0; i < PART_ROW_CNT; ++i) begin
      serialOut[j] = tile_serialOut[TOT_ROWS-1][0][i];
      serialOutValid[j] = tile_serialOutValid[TOT_ROWS-1][0][i];
      ++j;
    end
  end


  // -- remove temporary macros
  `undef INST_TILE

endmodule

