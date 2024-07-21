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
  Date   : Tue, Feb 27, 01:38 PM CST 2024
  Version: v1.0

  Description:
  This is the top-level wrapper for IMAGine. It instantiates and connectes the
  submodules of IMAGine: interface, GEMV-tile array, and vector-shift-reg array.
  It does not instantiates the FIFOs. However, this can be directly connected
  to the FIFOs to build the IMAGine IP.

================================================================================*/

`timescale 1ns/100ps


module imagine_wrapper # (
  parameter DEBUG = 1,
  parameter BLK_ROW_CNT   = 10,   // No. of PiCaSO rows in the entire array
  parameter BLK_COL_CNT   =  8,   // No. of PiCaSO columns in the entire array
  parameter TILE_ROW_CNT  =  4,   // No. of PiCaSO rows in a tile
  parameter TILE_COL_CNT  =  4,   // No. of PiCaSO columns in a tile
  parameter DATAOUT_WIDTH = 16    // width of the vector dataout port (also decides the width of the vector shift registers)
) (
  clk,
  // FIFO-in interface
  instruction,          // instruction input 
  instructionValid,     // instruction valid signal input
  instructionNext,      // fetch next instruction signal output
  // FIFO-out interface
  dataout,              // vector data output
  dataAttrib,           // vector data attributes output
  dataoutValid,         // vector data output valid
  // status signals
  eovInterrupt,         // interrupt output for signaling end-of-vector written to FIFO-out
  clearEOV,             // input signal to clear end-of-vector interrupt

  // Debug probes
  dbg_clk_enable         // debug clock for stepping
);

  `include "imagine_interface.svh"
  `include "vecshift_tile.svh"
  `include "picaso_instruction_decoder.inc.v"


  // remove scope prefix for short-hand
  localparam DATA_ATTRIB_WIDTH   = VECSHIFT_STATUS_WIDTH,
             GEMVARR_INSTR_WIDTH = PICASO_INSTR_WORD_WIDTH;


  // -- Module IOs
  // front-end interface signals
  input                            clk;
  input  [IMAGINE_INSTR_WIDTH-1:0] instruction;
  input                            instructionValid;
  output                           instructionNext;
  output [DATAOUT_WIDTH-1:0]       dataout;
  output [DATA_ATTRIB_WIDTH-1:0]   dataAttrib;
  output                           dataoutValid;
  output                           eovInterrupt;
  input                            clearEOV;


  // Debug probes
  input dbg_clk_enable;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)


  // -- imagine_interface IO
  wire  [IMAGINE_INSTR_WIDTH-1:0] imgInt_instruction;
  wire                            imgInt_instructionValid;
  wire                            imgInt_instructionNext;
  wire  [DATAOUT_WIDTH-1:0]       imgInt_dataout;
  wire  [DATA_ATTRIB_WIDTH-1:0]   imgInt_dataAttrib;
  wire                            imgInt_dataoutValid;
  wire                            imgInt_eovInterrupt;
  wire                            imgInt_clearEOV;
  
  wire [GEMVARR_INSTR_WIDTH-1:0]  imgInt_gemvarr_instruction;
  wire                            imgInt_gemvarr_inputValid;
  wire [VECSHIFT_INSTR_WIDTH-1:0] imgInt_shreg_instruction;
  wire                            imgInt_shreg_inputValid;

  wire [DATAOUT_WIDTH-1:0]        imgInt_shreg_parallelOut;
  wire [DATA_ATTRIB_WIDTH-1:0]    imgInt_shreg_statusOut;


  (* keep_hierarchy = "yes" *)
  imagine_interface #(
      .DEBUG(DEBUG),
      .DATA_WIDTH(DATAOUT_WIDTH))
    imgInterface (
			.clk(clk),
			// FIFO-in interface
			.instruction(imgInt_instruction),
			.instructionValid(imgInt_instructionValid),
			.instructionNext(imgInt_instructionNext),
			// FIFO-out interface
			.dataout(imgInt_dataout),
      .dataAttrib(imgInt_dataAttrib),
			.dataoutValid(imgInt_dataoutValid),
			// status signals
			.eovInterrupt(imgInt_eovInterrupt),
      .clearEOV(imgInt_clearEOV),

      // interface to submodule: GEMV array 
      .gemvarr_instruction(imgInt_gemvarr_instruction),
      .gemvarr_inputValid(imgInt_gemvarr_inputValid),

      // interface to submodule: vector shift register column
      .shreg_instruction(imgInt_shreg_instruction),
      .shreg_inputValid(imgInt_shreg_inputValid),
      .shreg_parallelOut(imgInt_shreg_parallelOut),    // inputs connected to parallel output from the shift register column
      .shreg_statusOut(imgInt_shreg_statusOut),      // inputs connected output status bits to the shift register column

			// Debug probes
			.dbg_clk_enable(1'b1)
    );


  // -- GEMV tile array
  wire  [PICASO_INSTR_WORD_WIDTH-1:0]  gemvArr_instruction;
  wire                                 gemvArr_inputValid;
  wire                                 gemvArr_serialOut[BLK_ROW_CNT];
  wire                                 gemvArr_serialOutValid[BLK_ROW_CNT];


  // (* keep_hierarchy = "yes" *)     // We want to keep hierarchy of the tiles, but not the array itsel
  gemvtile_array #(
      .DEBUG(DEBUG),
      .BLK_ROW_CNT(BLK_ROW_CNT),      // No. of PiCaSO rows in the entire array
      .BLK_COL_CNT(BLK_COL_CNT),      // No. of PiCaSO columns in the entire array
      .TILE_ROW_CNT(TILE_ROW_CNT),    // No. of PiCaSO rows in a tile
      .TILE_COL_CNT(TILE_COL_CNT))    // No. of PiCaSO columns in a tile
    gemvArr (
      .clk(clk),
      .instruction(gemvArr_instruction),
      .inputValid(gemvArr_inputValid),
      .serialOut(gemvArr_serialOut),
      .serialOutValid(gemvArr_serialOutValid)
  );


  // -- Vector-shift register array
  wire [VECSHIFT_INSTR_WIDTH-1:0]  vecArr_instruction;
  wire                             vecArr_inputValid;
  wire                             vecArr_serialIn[BLK_ROW_CNT];
  wire                             vecArr_serialIn_valid[BLK_ROW_CNT];
  wire [DATAOUT_WIDTH-1:0]         vecArr_parallelOut;
  wire [VECSHIFT_STATUS_WIDTH-1:0] vecArr_statusOut;


  vectile_array #(
      .DEBUG(DEBUG),
      .REG_WIDTH(DATAOUT_WIDTH),      // vector-shift registers provide the dataout stream
      .REG_COUNT(BLK_ROW_CNT),        // one vector-shift register per PICASO block row
      .TILE_HEIGHT(TILE_ROW_CNT))     // height of GEMV and VECSHIFT tiles need to match for optimal place and route
    vecArr (
      .clk(clk),
      .instruction(vecArr_instruction),
      .inputValid(vecArr_inputValid),
      .serialIn(vecArr_serialIn),
      .serialIn_valid(vecArr_serialIn_valid),
      .parallelOut(vecArr_parallelOut),
      .statusOut(vecArr_statusOut),

			// Debug probes
			.dbg_clk_enable(1'b1)
  );




  // ---- Local interconnect
  // inputs to imgInterface
  assign imgInt_instruction = instruction,
         imgInt_instructionValid = instructionValid,
         imgInt_clearEOV = clearEOV,
         imgInt_shreg_parallelOut = vecArr_parallelOut,
         imgInt_shreg_statusOut = vecArr_statusOut;

  // inputs to gemvArr
  assign gemvArr_instruction = imgInt_gemvarr_instruction,
         gemvArr_inputValid  = imgInt_gemvarr_inputValid;

  // inputs to vecArr
  assign vecArr_instruction = imgInt_shreg_instruction,
         vecArr_inputValid  = imgInt_shreg_inputValid,
         vecArr_serialIn    = gemvArr_serialOut,
         vecArr_serialIn_valid = gemvArr_serialOutValid;
       
  // top-level outputs
  assign dataout = imgInt_dataout,
         dataAttrib = imgInt_dataAttrib,
         dataoutValid = imgInt_dataoutValid,
         eovInterrupt = imgInt_eovInterrupt,
         instructionNext = imgInt_instructionNext;


  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule



