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
  Date  : Tue, Nov 07, 04:33 PM CST 2023

  Description:
  This module instantiates an array of PiCaSO block. This module can be tied
  to picaso controller to build a M.V tile.

  Version: v1.0

================================================================================*/


`timescale 1ns/100ps
`include "ak_macros.v"


//(* black_box = "yes" *)            // for RTL elaboration in vivado
module picaso_array #(
  parameter DEBUG = 1,
  parameter ARR_ROW_CNT      = 4,    // change these values
  parameter ARR_COL_CNT      = 4,    // change these values
  parameter START_ROW_ID     = 6,    // row-ID of the compute-block (must initialize with a non-negative number of ID_WIDTH size)
  parameter START_COL_ID     = 9,    // column-ID of the compute-block
  parameter NET_STREAM_WIDTH = 1,    // width of the East-to-West movement stream
  parameter MAX_NET_LEVEL    = 3,    // how many levels of the binary tree to support (PE-node count = 2**MAX_LEVEL)
  parameter ID_WIDTH         = 8,    // width of the row/colum IDs
  parameter PE_CNT           = 16,   // Number of Processing-Elements in each block
  parameter RF_DEPTH         = 1024  // Depth of the register-file (usually it's equal to register-width * register-count)
) (
  clk,

  // PiCaSO control signals (grouped inputs)
  netLevel,       // selects the current tree level
  netConfLoad,    // load network configuration
  netCaptureEn,   // enable network capture registers
 
  aluConf,        // configuration for ALU
  aluConfLoad,    // load operation configurations
  aluEn,          // enable ALU for computation (holds the ALU state if aluEN=0)
  aluReset,       // reset ALU state
  aluMbitReset,   // resets previous multiplier-bit storage for booth's encoding
  aluMbitLoad,    // saves (loads) multiplier-bit for booth's encoding

  opmuxConfLoad,  // load operation configurations
  opmuxConf,      // configuration for opmux module
  opmuxEn,        // operand-mux output register clock enable

  extDataSave,    // save external data into BRAM (uses addrA)
  extDataIn,      // external data input port of PiCaSO

  saveAluOut,     // save the output of ALU (uses addrB)
  addrA,          // address of operand A
  addrB,          // address of operand B

  selRow,        // currently selected row ID
  selCol,        // currently selected column ID
  selMode,       // current selection mode: row, column, both, encode
  selEn,         // set the clock-enable of the selection register (value is set based on row, col, and mode)
  selOp,         // 1: perform op if selected, 0: perform op irrespective of selRow/selCol. NOTE: Only specific operations can be performed selectively.

  ptrLoad,       // load local pointer value (uses port-A address)
  ptrIncr,       // enable local pointer increment

  // These are boundary input/outputs (grouped along one dimension, requires conversion to signal array array)
  eastIn,         // east input streams of all blocks on the east edge
  westOut,        // west output streams of all blocks on the west edge
  serialOut,      // serial data output of all blocks on the west edge
  serialOutValid  // serial data valid signal of all blocks on the west edge

);


// ---- Parameter
`AK_ASSERT(NET_STREAM_WIDTH == 1)
`AK_ASSERT(ARR_ROW_CNT >= 1)
`AK_ASSERT(ARR_COL_CNT >= 1)
// Row and Column IDs must be non-negative and fit withing ID_WIDTH
`AK_ASSERT(START_ROW_ID >= 0)
`AK_ASSERT(START_COL_ID >= 0)
`AK_ASSERT((START_ROW_ID + ARR_ROW_CNT - 1) < (1<<ID_WIDTH))
`AK_ASSERT((START_COL_ID + ARR_COL_CNT - 1) < (1<<ID_WIDTH))


`include "clogb2_func.v"
`include "boothR2_serial_alu.inc.v"
`include "alu_serial_unit.inc.v"
`include "opmux_ff.inc.v"
`include "picaso_ff.inc.v"


// Local parameter declarations for IO ports and submodules
localparam REGFILE_RAM_WIDTH  = PE_CNT,
           REGFILE_RAM_DEPTH  = RF_DEPTH,
           REGFILE_ADDR_WIDTH = clogb2(REGFILE_RAM_DEPTH-1);

localparam NET_LEVEL_WIDTH = clogb2(MAX_NET_LEVEL-1);   // compute the no. of bits needed to represent all levels
localparam SEL_MODE_WIDTH  = PICASO_SEL_MODE_WIDTH;


// IO ports
input  wire  clk; 

input  [NET_LEVEL_WIDTH-1:0]  netLevel;
input                         netConfLoad;
input                         netCaptureEn;

input  [ALU_OP_WIDTH-1:0]     aluConf;
input                         aluConfLoad;
input                         aluEn;
input                         aluReset;
input                         aluMbitReset;
input                         aluMbitLoad;

input                         opmuxConfLoad;
input  [OPMUX_CONF_WIDTH-1:0] opmuxConf;
input                         opmuxEn;

input                           extDataSave;
input  [REGFILE_RAM_WIDTH-1:0]  extDataIn; 

input                           saveAluOut;
input  [REGFILE_ADDR_WIDTH-1:0] addrA;    
input  [REGFILE_ADDR_WIDTH-1:0] addrB;   

input  [ID_WIDTH-1:0]           selRow;
input  [ID_WIDTH-1:0]           selCol;
input  [SEL_MODE_WIDTH-1:0]     selMode;
input                           selEn;
input                           selOp;

input                           ptrLoad;
input                           ptrIncr;

input  [NET_STREAM_WIDTH-1:0]   eastIn[ARR_ROW_CNT];
output [NET_STREAM_WIDTH-1:0]   westOut[ARR_ROW_CNT];
output                          serialOut[ARR_ROW_CNT];
output                          serialOutValid[ARR_ROW_CNT];


localparam ROW_ID_MAX = START_ROW_ID + ARR_ROW_CNT - 1,
           COL_ID_MAX = START_COL_ID + ARR_COL_CNT - 1;


// Signal arrays for connecting to each block: array indices are directly mapped to block row/col ids
wire [NET_LEVEL_WIDTH-1:0]  blk_netLevel[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_netConfLoad[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_netCaptureEn[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];

wire [NET_STREAM_WIDTH-1:0] blk_eastIn[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire [NET_STREAM_WIDTH-1:0] blk_westOut[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_serialOut[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_serialOutValid[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];

wire [ALU_OP_WIDTH-1:0]     blk_aluConf[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_aluConfLoad[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_aluEn[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_aluReset[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_aluMbitReset[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_aluMbitLoad[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];

wire                        blk_opmuxConfLoad[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire [OPMUX_CONF_WIDTH-1:0] blk_opmuxConf[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                        blk_opmuxEn[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];

wire                          blk_extDataSave[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire [REGFILE_RAM_WIDTH-1:0]  blk_extDataIn[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX]; 
wire [REGFILE_RAM_WIDTH-1:0]  blk_extDataOut[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];

wire                          blk_saveAluOut[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire [REGFILE_ADDR_WIDTH-1:0] blk_addrA[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];    
wire [REGFILE_ADDR_WIDTH-1:0] blk_addrB[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];   

wire [ID_WIDTH-1:0]           blk_selRow[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire [ID_WIDTH-1:0]           blk_selCol[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire [1:0]                    blk_selMode[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                          blk_selEn[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                          blk_selOp[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];

wire                          blk_ptrLoad[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];
wire                          blk_ptrIncr[START_ROW_ID:ROW_ID_MAX][START_COL_ID:COL_ID_MAX];



// Generate the 2D array of PiCaSO blocks and connect them to signal bus with corresponding indices
genvar g_row, g_col;

generate
  for(g_row = START_ROW_ID; g_row <= ROW_ID_MAX; g_row = g_row+1)  begin: block_row
    for(g_col = START_COL_ID; g_col <= COL_ID_MAX; g_col = g_col+1)  begin: block_col
      (* keep_hierarchy = "yes" *)
      picaso_ff  #(
            .DEBUG(DEBUG),
            .NET_STREAM_WIDTH(NET_STREAM_WIDTH),
            .MAX_NET_LEVEL(MAX_NET_LEVEL),
            .ID_WIDTH(ID_WIDTH),
            .CB_ROW_ID(g_row),
            .CB_COL_ID(g_col),
            .PE_CNT(PE_CNT),
            .RF_DEPTH(RF_DEPTH) )
          block (
            .clk(clk),

            .netLevel(blk_netLevel[g_row][g_col]),
            .netConfLoad(blk_netConfLoad[g_row][g_col]),
            .netCaptureEn(blk_netCaptureEn[g_row][g_col]),

            .eastIn(blk_eastIn[g_row][g_col]),
            .westOut(blk_westOut[g_row][g_col]),
            .serialOut(blk_serialOut[g_row][g_col]),
            .serialOutValid(blk_serialOutValid[g_row][g_col]),

            .aluConf(blk_aluConf[g_row][g_col]),
            .aluConfLoad(blk_aluConfLoad[g_row][g_col]),
            .aluEn(blk_aluEn[g_row][g_col]),
            .aluReset(blk_aluReset[g_row][g_col]),
            .aluMbitReset(blk_aluMbitReset[g_row][g_col]),
            .aluMbitLoad(blk_aluMbitLoad[g_row][g_col]),

            .opmuxConfLoad(blk_opmuxConfLoad[g_row][g_col]),
            .opmuxConf(blk_opmuxConf[g_row][g_col]),
            .opmuxEn(blk_opmuxEn[g_row][g_col]),

            .extDataSave(blk_extDataSave[g_row][g_col]),
            .extDataIn(blk_extDataIn[g_row][g_col]),

            .saveAluOut(blk_saveAluOut[g_row][g_col]),
            .addrA(blk_addrA[g_row][g_col]),
            .addrB(blk_addrB[g_row][g_col]),

            .selRow(blk_selRow[g_row][g_col]),
            .selCol(blk_selCol[g_row][g_col]),
            .selMode(blk_selMode[g_row][g_col]),
            .selEn(blk_selEn[g_row][g_col]),
            .selOp(blk_selOp[g_row][g_col]),

            .ptrLoad(blk_ptrLoad[g_row][g_col]),
            .ptrIncr(blk_ptrIncr[g_row][g_col]),

            // NOTE: Not connecting debug probes, only enabling the debug clock
            .dbg_clk_enable(1'b1)
          );
    end
  end
endgenerate


// ---- Interconnects
// Connect the block array datanet signals
generate
  for(g_row=START_ROW_ID; g_row <= ROW_ID_MAX; g_row = g_row + 1) begin
    for(g_col=START_COL_ID; g_col < COL_ID_MAX; g_col = g_col + 1) begin
      // connect this block to it's right neighbor (that's why g_col < COL_ID_MAX)
      assign blk_eastIn[g_row][g_col] = blk_westOut[g_row][g_col+1];
    end
    // row-edge network connections
    assign blk_eastIn[g_row][COL_ID_MAX] = eastIn[g_row-START_ROW_ID];           // external eastIn connects to right-most blocks (IO ports indexing starts at 0)
    assign westOut[g_row-START_ROW_ID]   = blk_westOut[g_row][START_COL_ID];     // left-most blocks' westOut connects to external westOut (IO ports indexing starts at 0)
    assign serialOut[g_row-START_ROW_ID] = blk_serialOut[g_row][START_COL_ID];   // left-most blocks' serialOut connects to external serialOut (IO ports indexing starts at 0)
    assign serialOutValid[g_row-START_ROW_ID] = blk_serialOutValid[g_row][START_COL_ID];   // same as serialOut
  end
endgenerate


// Broadcast control signals to all blocks
generate
  for(g_row=START_ROW_ID; g_row <= ROW_ID_MAX; g_row = g_row + 1) begin
    for(g_col=START_COL_ID; g_col <= COL_ID_MAX; g_col = g_col + 1) begin
      assign blk_netLevel[g_row][g_col] = netLevel;
      assign blk_netConfLoad[g_row][g_col] = netConfLoad;
      assign blk_netCaptureEn[g_row][g_col] = netCaptureEn;

      assign blk_aluConf[g_row][g_col] = aluConf;
      assign blk_aluConfLoad[g_row][g_col] = aluConfLoad;
      assign blk_aluEn[g_row][g_col] = aluEn;
      assign blk_aluReset[g_row][g_col] = aluReset;
      assign blk_aluMbitReset[g_row][g_col] = aluMbitReset;
      assign blk_aluMbitLoad[g_row][g_col] = aluMbitLoad;

      assign blk_opmuxConfLoad[g_row][g_col] = opmuxConfLoad;
      assign blk_opmuxConf[g_row][g_col] = opmuxConf;
      assign blk_opmuxEn[g_row][g_col] = opmuxEn;

      assign blk_extDataSave[g_row][g_col] = extDataSave;
      assign blk_extDataIn[g_row][g_col] = extDataIn;

      assign blk_saveAluOut[g_row][g_col] = saveAluOut;
      assign blk_addrA[g_row][g_col] = addrA;
      assign blk_addrB[g_row][g_col] = addrB;

      assign blk_selRow[g_row][g_col] = selRow;
      assign blk_selCol[g_row][g_col] = selCol;
      assign blk_selMode[g_row][g_col] = selMode;
      assign blk_selEn[g_row][g_col] = selEn;
      assign blk_selOp[g_row][g_col] = selOp;

      assign blk_ptrLoad[g_row][g_col] = ptrLoad;
      assign blk_ptrIncr[g_row][g_col] = ptrIncr;
    end
  end
endgenerate


endmodule
