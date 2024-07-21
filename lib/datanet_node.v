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
  Date  : Wed, Jul 26, 02:01 PM CST 2023

  Description:
  This module implements a binary-tree-shift network node for data movement over
  a LE (local/East) network, through Compute Block (PiCaSO). The tree-level
  controls the transmitter mux. There is no receiver mux and direction bit as
  it only supports moving data East-to-West only. It also does not support
  South-to-North data shifting.

  Version: v1.0 
  v1.0 is a specialized version for East-to-West accumulation only. For
  a general version, checkout the implementation at the following URL,
  https://github.com/Arafat-Kabir/SPAR-Prototypes/blob/MV-Engine/BitSerial-v1/PiCaSO-Dev/network/lib/DataNetNode.v 

================================================================================*/


`timescale 1ns/100ps
`include "ak_macros.v"


module datanet_node #(
  parameter DEBUG = 1,
  parameter EW_STREAM_WIDTH = 1,      // width of the East-to-West movement stream
  parameter MAX_LEVEL       = 8,      // how many levels of the binary tree to support (PE-node count = 2**MAX_LEVEL)
  parameter ID_WIDTH        = 8,      // width of the row/colum IDs
  parameter ROW_ID          = -1,     // row-ID of the node (must initialize with a non-negative number of ID_WIDTH size)
  parameter COL_ID          = -1      // column-ID of the node
) (
  clk,

  localIn,      // input stream from the local node itself
  captureOut,   // stream of captured data from network

  eastIn,       // input stream from east
  westOut,      // output stream to west

  level,        // selects the current tree level
  confLoad,     // clock enable for configuration registers (level register)
  captureEn,    // enable network capture registers
  isReceiver,   // receiver mode detection bit

  // debug probes
  dbg_clk_enable,       // debug clock for stepping
  dbg_level_reg,        // value stored in the level register
  dbg_capture_reg,      // value stored in the capture register
  dbg_txSelect          // transmitter mux select bit 
);


  // Row and Column IDs must be non-negative and fit withing ID_WIDTH
  `AK_ASSERT(ROW_ID >= 0)
  `AK_ASSERT(COL_ID >= 0)
  `AK_ASSERT(ROW_ID < (1<<ID_WIDTH))
  `AK_ASSERT(COL_ID < (1<<ID_WIDTH))

  `include "clogb2_func.v"

  localparam LEVEL_WIDTH = clogb2(MAX_LEVEL-1);   // compute the no. of bits needed to represent all levels


  // IO ports
  input                         clk;
  // data ports
  input  [EW_STREAM_WIDTH-1:0]  localIn;
  output [EW_STREAM_WIDTH-1:0]  captureOut;
  input  [EW_STREAM_WIDTH-1:0]  eastIn;
  output [EW_STREAM_WIDTH-1:0]  westOut;
  // configuration ports
  input  [LEVEL_WIDTH-1:0]      level;
  input                         confLoad;
  input                         captureEn;
  output                        isReceiver;

  // Debug probes
  input                           dbg_clk_enable;
  output [LEVEL_WIDTH-1:0]        dbg_level_reg;
  output [EW_STREAM_WIDTH-1:0]    dbg_capture_reg;
  output                          dbg_txSelect;


  // internal signals
  wire local_ce;


  // Register to save the requested configuration
  (* extract_enable = "yes" *)
  reg [LEVEL_WIDTH-1:0]  level_reg = 0;   // default reset value; no explicit reset

  // Load configurations to the registers when requested
  always @(posedge clk) begin
      if(confLoad && local_ce) begin   // update value only if confLoad set
          level_reg <= level;          // load the requested level
      end else begin
          level_reg <= level_reg;      // otherwise, hold current config
      end
  end


  // Network data capture register
  (* extract_enable = "yes" *)
  reg [EW_STREAM_WIDTH-1:0]  capture_reg = 0;   // default reset value; no explicit reset

  // Capture the router output when requested
  always @(posedge clk) begin
      if(captureEn && local_ce)     // update value only if capture requested
          capture_reg <= eastIn;    // capture the east input
      else
          capture_reg <= capture_reg;  // otherwise, hold the current data
  end

  assign captureOut = capture_reg;     // expose the captured data


  // Transmitter Mux
  wire [EW_STREAM_WIDTH-1:0]  txOut;
  datanet_txMux #(
    .DEBUG(DEBUG),
    .EW_STREAM_WIDTH(EW_STREAM_WIDTH),
    .LEVEL_WIDTH(LEVEL_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .COL_ID(COL_ID)  ) 
    muxTX(
        .levelReg_Q(level_reg),
        .captureReg_Q(capture_reg),
        .localIn(localIn),
        .txOut(txOut),

        // debug probes
        .dbg_txSelect(dbg_txSelect)
    );

  assign westOut = txOut;   // connect transmitter mux output to the module port


  // Receiver node detection encoder
  wire recev_detect_isReceiver;
  datanet_receiverDetect #(
    .DEBUG(DEBUG),
    .LEVEL_WIDTH(LEVEL_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .COL_ID(COL_ID)  )
    recev_detect(
      .levelReg_Q(level_reg),
      .isReceiver(recev_detect_isReceiver)
    );

  assign isReceiver = recev_detect_isReceiver;  // connect receiver detect encoder output to output port



  // connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
      assign dbg_level_reg = level_reg;
      assign dbg_capture_reg = capture_reg;
      // NOTE: dbg_txSelect is directly connected to muxTx

    end else begin
      assign local_ce = 1;     // there is no top-level clock enable control
    end
  endgenerate


endmodule





/*================================================================================

  Author: MD Arafat Kabir
  Email : arafat.sun@gmail.com
  Date  : Wed, Oct 11, 01:30 PM CST 2023

  Description:
  This is an encoder to detect if the node is a receiver or not. 
  The detection is performed based on the level value and the ROW/COL ID.
  This is not designed to be reusable across different network architecture. 
  It is purely a combinatorial block, used to modularize the network module code.

  Version: v1.0

================================================================================*/
module datanet_receiverDetect #(
  parameter DEBUG = 1,
  parameter LEVEL_WIDTH = 8,      // how many levels of the binary tree to support (PE-node count = 2**MAX_LEVEL)
  parameter ID_WIDTH    = 8,      // width of the row/colum IDs
  parameter ROW_ID      = -1,     // row-ID of the node (must initialize with a non-negative number of ID_WIDTH size)
  parameter COL_ID      = -1      // column-ID of the node
) (
  levelReg_Q,
  isReceiver
);


  // Row and Column IDs must be non-negative and fit within ID_WIDTH
  `AK_ASSERT(COL_ID >= 0)
  `AK_ASSERT(COL_ID < (1<<ID_WIDTH))

  localparam [ID_WIDTH-1:0] _COL_ID = COL_ID[ID_WIDTH-1:0];  // otherwise 32-bit parameter COL_ID messes up logic optimizations

  // IO ports
  input  [LEVEL_WIDTH-1:0] levelReg_Q;
  output                   isReceiver;

  /* Function to map network-node level to Receiver-detection signal
  *   Notes: draw a 1D Array diagram to understand the mappings
  *    - Compare the following table with datanet_txMux txSelect table
  *      to understand how each level value connects the nodes (Tx -> Rx).
  *
  *   E -> W uses column-ID only.
  *   level | Receivers node IDs
  *   ------|-------------------
  *     0   | multiples of 2
  *     1   | multiples of 4
  *     2   | multiples of 8
  *     3   | multiples of 16
  *     4   | multiples of 32
  *     5   | multiples of 64
  *     6   | multiples of 128
  *     7   | multiples of 256
  *  Based on the width of level, this function should map to one LUT. For
  *  example, with support for 16-levels (0-15), it can be mapped into a LUT5.
  *  This can support an array with 2**15 = 32k cols.
  */
  function automatic isReceiver_fn;
      input [LEVEL_WIDTH-1:0]  _level;

      reg _ismultiple;   // internal variable

      begin
          // compute the selection table based on level
          _ismultiple = (_COL_ID % (1<<(_level+1))) == 0;   // is the COL_ID multiple of 2^(level+1)?
          isReceiver_fn = _ismultiple;  // if it is a multiple of 2^(level+1), it is a receiver
      end
  endfunction

  assign isReceiver = isReceiver_fn(levelReg_Q);


endmodule
