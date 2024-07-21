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
  Date  : Wed, Jul 26, 02:42 PM CST 2023

  Description:
  This is the transmitter mux of the network node. This is not designed to be
  reuable across different network architecture. It is used to modularize the
  network module code.
  Based on the level value, it selects either the localIn or capture_reg.

  Version: v1.0

================================================================================*/


/*
Usage: Implements the transmitter logic (combinatorial module)
    levelReg_Q   : connect the level-register output of the network node
    captureReg_Q : connect the network capture-register output of the node
    localIn      : local data stream to be transmitted
*/

`timescale 1ns/100ps
`include "ak_macros.v"


module datanet_txMux #(
  parameter DEBUG = 1,
  parameter EW_STREAM_WIDTH = 1,      // width of the East-to-West movement stream
  parameter LEVEL_WIDTH     = 8,      // how many levels of the binary tree to support (PE-node count = 2**MAX_LEVEL)
  parameter ID_WIDTH        = 8,      // width of the row/colum IDs
  parameter ROW_ID          = -1,     // row-ID of the node (must initialize with a non-negative number of ID_WIDTH size)
  parameter COL_ID          = -1      // column-ID of the node
) (
  levelReg_Q,
  captureReg_Q,
  localIn,
  txOut,

  // debug probes
  dbg_txSelect
);


  // Row and Column IDs must be non-negative and fit withing ID_WIDTH
  `AK_ASSERT(COL_ID >= 0)
  `AK_ASSERT(COL_ID < (1<<ID_WIDTH))

  localparam [ID_WIDTH-1:0] _COL_ID = COL_ID[ID_WIDTH-1:0];  // otherwise 32-bit parameter COL_ID messes up logic optimizations

  // IO ports
  input  [LEVEL_WIDTH-1:0]      levelReg_Q;
  input  [EW_STREAM_WIDTH-1:0]  captureReg_Q;
  input  [EW_STREAM_WIDTH-1:0]  localIn;
  output [EW_STREAM_WIDTH-1:0]  txOut;

  // Debug probes
  output dbg_txSelect;


  // Multiplexter to select between localIn and captureReg_Q
  localparam SELECT_LOCAL   = 1'b0,        // constants to be used in the selection table
             SELECT_CAPTURE = 1'b1;
  wire txSelect;    // mux selection bit
  assign txOut = txSelect ? captureReg_Q : localIn;   // 1: captureReg_Q, 0: localIn


  /* Function to map network-node level to mux selection bit (txSelect)
  *  Note: draw a 1D Array diagram to understand the mappings and following notes.
  *   - These mappings only decide if the local data will be transmitted or the
  *     network stream will the relayed, this does not imply that this block is
  *     "truly" a Transmitters. 
  *   - Depending on the states of other nodes, this stream may be written into 
  *     another node (Receiver) or simply discarded.
  *   - Thus, a "true" Receiver may safely transmit its local data without
  *     worrying about whether it's a "true" transmitter or not.
  *   - The same applies for a passthrough node. It may relay streams that
  *     will eventually be discarded by a "true" transmitter node along the stream.
  *
  *   E -> W uses column-ID only.
  *   level | selection
  *   ------|-----------
  *     0   | all blocks : transmit local
  *     1   | even blocks: transmit local, others: passthrough
  *     2   | multiple of 4   blocks: transmit local, others: passthrough
  *     3   | multiple of 8   blocks: transmit local, others: passthrough
  *     4   | multiple of 16  blocks: transmit local, others: passthrough
  *     5   | multiple of 32  blocks: transmit local, others: passthrough
  *     6   | multiple of 64  blocks: transmit local, others: passthrough
  *     7   | multiple of 128 blocks: transmit local, others: passthrough
  *  Based on the width of level, this function should map to one LUT. For
  *  example, with support for 16-levels (0-15), it can be mapped into a LUT5.
  *  This can support an array with 2**15 = 32k cols.
  */
  function automatic mapLevel2Select_fn;
    input [LEVEL_WIDTH-1:0]  _level;

    reg _selectEW;   // internal variable

    begin
      // compute the selection table based on level: if ID divisible by power of 2, transmit local (_selectEW = 0)
      _selectEW = (_COL_ID % (1<<_level)) == 0 ? 0 : 1;   // select=0 if remainder=0, select=1 otherwise
      mapLevel2Select_fn = _selectEW ? SELECT_CAPTURE : SELECT_LOCAL;   // map to txSelect constants
    end
  endfunction

  assign txSelect = mapLevel2Select_fn(levelReg_Q);


  // Connect debug probes
  generate
    if(DEBUG) assign dbg_txSelect = txSelect;
  endgenerate

endmodule
