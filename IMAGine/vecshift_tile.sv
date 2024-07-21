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
  Date   : Fri, Feb 02, 05:37 PM CST 2024
  Version: v1.0

  Description:
  This is a building block of the vector-shift column of IMAGine.
  Each tile should correspond to one GEMV tile edge.

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module vecshift_tile #(
  parameter DEBUG = 1,
  parameter REG_WIDTH = -1,
  parameter TILE_HEIGHT = -1,      // Number of shift registers in the tile
  parameter ISLAST_TILE = 0        // Set this to 1 to enable last-of-column register behavior
) (
  clk,
  // control signals
  instruction,          // instruction for the tile controller
  inputValid,           // Single-bit input signal, 1: other input signals are valid, 0: other input signals not valid (this is needed to work with shift networks)
  // data IOs
  serialIn,             // serial data input array
  serialIn_valid,       // indicates if the serial input data is valid (array)
  parallelIn,           // parallel input from bottom tile
  parallelOut,          // parallel output to the above tile
  statusIn,             // input status bits from the bottom tile
  statusOut,            // output status bits to the above tile

  // Debug probes
  dbg_clk_enable        // debug clock for stepping
);


  `include "vecshift_tile.svh"


  // validate module parameters
  `AK_ASSERT2(REG_WIDTH > 0, REG_WIDTH_must_be_set)
  `AK_ASSERT2(ISLAST_TILE >= 0, ISLAST_TILE_must_be_0_or_1)
  `AK_ASSERT2(ISLAST_TILE <= 1, ISLAST_TILE_must_be_0_or_1)

  // remove scope prefix for short-hand
  localparam INSTR_WIDTH  = VECSHIFT_INSTR_WIDTH,
             CONFIG_WIDTH = VECSHIFT_CONFIG_WIDTH,
             STATUS_WIDTH = VECSHIFT_STATUS_WIDTH;


  // IO Ports
  input                     clk;
  input  [INSTR_WIDTH-1:0]  instruction;
  input                     inputValid;
  input  [TILE_HEIGHT-1:0]  serialIn;         // array of serial input
  input  [TILE_HEIGHT-1:0]  serialIn_valid;   // array of serial input valid signals
  input  [REG_WIDTH-1:0]    parallelIn;
  output [REG_WIDTH-1:0]    parallelOut;
  input  [STATUS_WIDTH-1:0] statusIn;
  output [STATUS_WIDTH-1:0] statusOut;

  // Debug probes
  input   dbg_clk_enable;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)


  // ---- Controller
  wire [INSTR_WIDTH-1:0]  ctrl_instruction;
  wire                    ctrl_inputValid;
  wire [CONFIG_WIDTH-1:0] ctrl_vecreg_confSig;

  vecshift_controller #(
      .DEBUG(DEBUG) )
    controller (
      .clk(clk),
      .instruction(ctrl_instruction),
      .inputValid(ctrl_inputValid),
      .vecreg_confSig(ctrl_vecreg_confSig),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
  );


  // ---- Fanout tree
  // TODO: Add if needed to meet timing


  // ---- vecshift_reg array
  wire [TILE_HEIGHT-1:0]  shregArr_serialIn;
  wire [TILE_HEIGHT-1:0]  shregArr_serialIn_valid;
  wire [REG_WIDTH-1:0]    shregArr_parallelIn;
  wire [REG_WIDTH-1:0]    shregArr_parallelOut;
  wire [CONFIG_WIDTH-1:0] shregArr_confSig;
  wire [STATUS_WIDTH-1:0] shregArr_statusIn;
  wire [STATUS_WIDTH-1:0] shregArr_statusOut;

  vecshift_array #(
      .DEBUG(DEBUG),
      .REG_WIDTH(REG_WIDTH),
      .ARR_HEIGHT(TILE_HEIGHT),
      .ISLAST_REG(ISLAST_TILE) )
    shreg_array (
      .clk(clk),
      .serialIn(shregArr_serialIn),
      .serialIn_valid(shregArr_serialIn_valid),
      .parallelIn(shregArr_parallelIn),
      .parallelOut(shregArr_parallelOut),
      .confSig(shregArr_confSig),
      .statusIn(shregArr_statusIn),
      .statusOut(shregArr_statusOut),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
  );



  // ---- Local Interconnect ----
  // inputs of tile controller
  assign ctrl_instruction = instruction,
         ctrl_inputValid  = inputValid;

  // inputs of register array
  assign shregArr_serialIn       = serialIn,
         shregArr_serialIn_valid = serialIn_valid,
         shregArr_parallelIn     = parallelIn,
         shregArr_confSig        = ctrl_vecreg_confSig,
         shregArr_statusIn       = statusIn;

  // top-level outputs
  assign parallelOut = shregArr_parallelOut,
         statusOut   = shregArr_statusOut;


  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;   // connect the debug stepper clock

    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule



// This is a very simple non-FSM controller for the vecshift-reg-tile.
module vecshift_controller #(
  parameter DEBUG = 1
) (
  clk,
  instruction,
  inputValid,
  vecreg_confSig,       // control signal output for register array

  // Debug probes
  dbg_clk_enable        // debug clock for stepping
);


  `include "vecshift_tile.svh"


  // remove scope prefix for short-hand
  localparam INSTR_WIDTH  = VECSHIFT_INSTR_WIDTH,
             CONFIG_WIDTH = VECSHIFT_CONFIG_WIDTH;


  // IO Ports
  input                     clk;
  input  [INSTR_WIDTH-1:0]  instruction;
  input                     inputValid;
  output [CONFIG_WIDTH-1:0] vecreg_confSig;

  // Debug probes
  input   dbg_clk_enable;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)


  // ---- instruction storage
  (* extract_enable = "yes" *)
  reg  [INSTR_WIDTH-1:0]  instruction_reg = VECSHIFT_IDLE;    // to hold the instruction word (initially set to NOP)

  // instruction_reg behavior
  always @(posedge clk) begin
    if(local_ce) begin
      if(inputValid) instruction_reg <= instruction;    // record the instruction word when inputValid signal is set
      else instruction_reg <= instruction_reg;          // otherwise, hold the value

    end else begin
      instruction_reg <= instruction_reg;   // hold the state for debugging
    end
  end


  // ---- Use set/reset flop to keep track of new instructions
  wire instr_valid;                 // this signal indicates if current contents of the insturction_reg is valid
  wire instr_valid_ff_clear;
  wire instr_valid_ff_set;

  srFlop #(
      .DEBUG(DEBUG),
      .SET_PRIORITY(0) )     // give "set" higher priority than "clear"
    instr_valid_ff (
      .clk(clk),
      .set(instr_valid_ff_set),
      .clear(instr_valid_ff_clear),
      .outQ(instr_valid),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
  );


  // AK-NOTE: Controller behavior
  //   - if instr_valid_ff is set, instruction_reg has a valid instruction
  //      - generate the corresponding configuration for the vecshift_reg
  //      - request instr_valid_ff clear
  //   - otherwise, generate NOP (VECSHIFT_IDLE)

  assign instr_valid_ff_clear = 1;    // always request clear; set has higher priority.

  (* extract_enable = "yes" *)
  reg [CONFIG_WIDTH-1:0] instrConfig = VECSHIFT_IDLE;

  // pipelined output for vecreg_confSig
  always@(posedge clk) begin
    // generate vecreg configuration
    if(instr_valid) begin
      instrConfig <= instruction_reg;      // instruction has one-one mapping to vecreg_confSig
    end else begin
      instrConfig <= VECSHIFT_IDLE;    // Generate NOP signals if no new instruction arrived
    end
  end


  // ---- Local interconnect
  assign instr_valid_ff_set = inputValid;
  assign vecreg_confSig = instrConfig;




  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;   // connect the debug stepper clock

    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule




// Instantiates and array of vecshift_reg
module vecshift_array #(
  parameter DEBUG = 1,
  parameter REG_WIDTH = -1,
  parameter ARR_HEIGHT = -1,
  parameter ISLAST_REG = 0        // Set this to 1 to enable last-of-column register behavior
) (
  clk,
  confSig,              // configuration signals to change behavior
  serialIn,             // serial data input array
  serialIn_valid,       // indicates if the serial input data is valid (array)
  parallelIn,           // parallel input from bottom
  parallelOut,          // parallel output to above
  statusIn,             // input status bits from bottom
  statusOut,            // output status bits to above

  // Debug probes
  dbg_clk_enable        // debug clock for stepping
);


  `include "vecshift_tile.svh"


  // validate module parameters
  `AK_ASSERT2(REG_WIDTH > 0, REG_WIDTH_must_be_set)
  `AK_ASSERT2(ARR_HEIGHT > 0, ARR_HEIGHT_must_be_set)
  `AK_ASSERT2(ISLAST_REG >= 0, ISLAST_REG_must_be_0_or_1)
  `AK_ASSERT2(ISLAST_REG <= 1, ISLAST_REG_must_be_0_or_1)

  // remove scope prefix for short-hand
  localparam CONFIG_WIDTH = VECSHIFT_CONFIG_WIDTH,
             STATUS_WIDTH = VECSHIFT_STATUS_WIDTH;


  // IO Ports
  input                     clk;
  input  [ARR_HEIGHT-1:0]   serialIn;
  input  [ARR_HEIGHT-1:0]   serialIn_valid;
  input  [REG_WIDTH-1:0]    parallelIn;
  output [REG_WIDTH-1:0]    parallelOut;
  input  [CONFIG_WIDTH-1:0] confSig;
  input  [STATUS_WIDTH-1:0] statusIn;
  output [STATUS_WIDTH-1:0] statusOut;

  // Debug probes
  input   dbg_clk_enable;


  // define per register signals
  typedef struct packed {
    logic                    serialIn;
    logic                    serialIn_valid;
    logic [REG_WIDTH-1:0]    parallelIn;
    logic [REG_WIDTH-1:0]    parallelOut;
    logic [CONFIG_WIDTH-1:0] confSig;
    logic [STATUS_WIDTH-1:0] statusIn;
    logic [STATUS_WIDTH-1:0] statusOut;
    logic                    _dummy;   // to avoid a bug in xsim
  } vecregIO_t;


  wire vecregIO_t vecreg_sigs[0:ARR_HEIGHT-1];

  genvar gi;


  // ---- Register instances
  generate
    for(gi=0; gi<ARR_HEIGHT; ++gi) begin: reginst
      (* keep_hierarchy = "yes" *)
      vecshift_reg #(
          .DEBUG(DEBUG),
          .REG_WIDTH(REG_WIDTH),
          .ISLAST_REG( gi==ARR_HEIGHT-1 ? ISLAST_REG : 0 ) )  // pass on the ISLAST_REG parameter to the last register instance
        vecreg (
          .clk(clk),
          .serialIn(vecreg_sigs[gi].serialIn),
          .serialIn_valid(vecreg_sigs[gi].serialIn_valid),
          .parallelIn(vecreg_sigs[gi].parallelIn),
          .parallelOut(vecreg_sigs[gi].parallelOut),
          .confSig(vecreg_sigs[gi].confSig),
          .statusIn(vecreg_sigs[gi].statusIn),
          .statusOut(vecreg_sigs[gi].statusOut),
          // debug probes
          .dbg_clk_enable(dbg_clk_enable)
      );
    end
  endgenerate


  // last register instance // TODO: Remove this commented block
  // (* keep_hierarchy = "yes" *)
  // vecshift_reg #(
  //     .DEBUG(DEBUG),
  //     .REG_WIDTH(REG_WIDTH),
  //     .ISLAST_REG(ISLAST_REG) )
  //   reglast_vecreg (
  //     .clk(clk),
  //     .serialIn(vecreg_sigs[ARR_HEIGHT-1].serialIn),
  //     .serialIn_valid(vecreg_sigs[ARR_HEIGHT-1].serialIn_valid),
  //     .parallelIn(vecreg_sigs[ARR_HEIGHT-1].parallelIn),
  //     .parallelOut(vecreg_sigs[ARR_HEIGHT-1].parallelOut),
  //     .confSig(vecreg_sigs[ARR_HEIGHT-1].confSig),
  //     .statusIn(vecreg_sigs[ARR_HEIGHT-1].statusIn),
  //     .statusOut(vecreg_sigs[ARR_HEIGHT-1].statusOut),
  //     // debug probes
  //     .dbg_clk_enable(dbg_clk_enable)
  // );


  // ----  interconnect
  generate
    for(gi=0; gi<ARR_HEIGHT; ++gi) begin
      assign vecreg_sigs[gi].serialIn = serialIn[gi];
      assign vecreg_sigs[gi].serialIn_valid = serialIn_valid[gi];
      assign vecreg_sigs[gi].confSig = confSig;   // confSig is broadcasted to all instances
      if(gi<ARR_HEIGHT-1) begin
        assign vecreg_sigs[gi].parallelIn = vecreg_sigs[gi+1].parallelOut;
        assign vecreg_sigs[gi].statusIn = vecreg_sigs[gi+1].statusOut;
      end
    end

    // outputs of first register are top-level outputs
    assign parallelOut = vecreg_sigs[0].parallelOut;
    assign statusOut   = vecreg_sigs[0].statusOut;

    // inputs to last register are top-level inputs
    assign vecreg_sigs[ARR_HEIGHT-1].parallelIn = parallelIn;
    assign vecreg_sigs[ARR_HEIGHT-1].statusIn   = statusIn;
  endgenerate

endmodule




// Shift register modules for the vecshift tile
module vecshift_reg #(
  parameter DEBUG = 1,
  parameter REG_WIDTH = -1,
  parameter ISLAST_REG = 0        // Set this to 1 to enable last-of-column register behavior
) ( 
  clk,
  serialIn,             // serial data input
  serialIn_valid,       // indicates if the serial input data is valid
  parallelIn,           // parallel input 
  parallelOut,          // parallel output
  confSig,              // configuration signals to change behavior
  statusIn,             // input status bits
  statusOut,            // output status bits
  curConfig,            // outputs the current internal configuration (Needed for the top-level interface logic)

  // Debug probes
  dbg_clk_enable,       // debug clock for stepping

  dbg_shiftSerialEn,
  dbg_shiftParallelEn
);


  `include "vecshift_tile.svh"


  // validate module parameters
  `AK_ASSERT2(REG_WIDTH > 0, REG_WIDTH_must_be_set)
  `AK_ASSERT2(ISLAST_REG >= 0, ISLAST_REG_must_be_0_or_1)
  `AK_ASSERT2(ISLAST_REG <= 1, ISLAST_REG_must_be_0_or_1)

  // remove scope prefix for short-hand
  localparam CONFIG_WIDTH = VECSHIFT_CONFIG_WIDTH,
             STATUS_WIDTH = VECSHIFT_STATUS_WIDTH;

  // This constant is used to conditionally make "untouched" internal debug probes
  localparam dbg_yn = DEBUG ? "yes" : "no";   // internal debug probes becomes "dont_touch" if DEBUG==True


  // IO Ports
  input                     clk;
  input                     serialIn;
  input                     serialIn_valid;
  input  [REG_WIDTH-1:0]    parallelIn;
  output [REG_WIDTH-1:0]    parallelOut;
  input  [CONFIG_WIDTH-1:0] confSig;
  input  [STATUS_WIDTH-1:0] statusIn;
  output [STATUS_WIDTH-1:0] statusOut;
  output vecshift_reg_intConfig_t curConfig;

  // Debug probes
                            input   dbg_clk_enable;
  (* mark_debug = dbg_yn *) output  dbg_shiftSerialEn;
  (* mark_debug = dbg_yn *) output  dbg_shiftParallelEn;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)


  // ---- Shift register
  wire                 shreg_serialIn;
  wire [REG_WIDTH-1:0] shreg_parallelIn;
  wire                 shreg_serialOut;
  wire [REG_WIDTH-1:0] shreg_parallelOut;
  wire                 shreg_shiftEn;
  wire                 shreg_loadEn;

  shiftReg #(
      .DEBUG(DEBUG),
      .REG_WIDTH(REG_WIDTH),
      .MSB_IN(1) )
    shreg (
      .clk(clk),
      .serialIn(shreg_serialIn),
      .parallelIn(shreg_parallelIn),
      .serialOut(shreg_serialOut),
      .parallelOut(shreg_parallelOut),
      .shiftEn(shreg_shiftEn),
      .loadEn(shreg_loadEn),

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)    // pass the debug stepper clock
    );


  // ---- Control state registers
  (* extract_enable = "yes" *)
  reg shiftSerialEn = 0,        // controls serial shifting operation
      shiftParallelEn = 0;       // controls parallel shifting (higher priority over shiftSerialEn)

  // control state registers behavior
  always@(posedge clk) begin
    if (local_ce) begin
      // select the next state based on confSig
      (* full_case, parallel_case *)
      case(confSig)
        VECSHIFT_IDLE: begin
          // Change nothing
        end
        VECSHIFT_SERIAL_EN: begin
          shiftSerialEn  <= 1;
          shiftParallelEn <= 0;
        end
        VECSHIFT_PARALLEL_EN: begin
          shiftSerialEn  <= 0;
          shiftParallelEn <= 1;
        end
        VECSHIFT_DISABLE: begin
          shiftSerialEn  <= 0;
          shiftParallelEn <= 0;
        end
        default: $display("WARN: invalid confSig for vecshift-reg, confSig: b%0b (%s:%0d)  %0t", confSig, `__FILE__, `__LINE__, $time);
      endcase

    // hold state for debugging (local_ce == 0) 
    end else begin
      shiftSerialEn  <= shiftSerialEn;
      shiftParallelEn <= shiftParallelEn;
    end
  end


  // ---- Status registers
  (* extract_enable = "yes" *)
  reg isData = 0,        // indicates if the data in shift-register is a valid data during column shifting (parallel shift)
      isLast = 0;        // indicates if the data in shift-register is the last data during column shifting (parallel shift)

  // pack-unpack status inputs
  wire isData_inp, isLast_inp;
  assign {isLast_inp, isData_inp} = statusIn;   // unpack input status vector
  assign statusOut = {isLast, isData};          // pack output status vector

  // AK-NOTE: Behavior of isData and isLast status registers
  //   if parallel-shifting is enabled, 
  //       Simply shift-in the status bits
  //   if shifting is about to be enabled in the next cycle,
  //       Set the status bits for parallel shifting.
  //       The status and shiftParallelEn will be set on the next posedge.
  //       Shifting will start in the subsequent edge.
  //  otherwise,
  //       Set them to zeros.
  always@(posedge clk) begin
    if (local_ce) begin
      // Read the above note for explanation
      if(shiftParallelEn) begin
        isData <= isData_inp;
        isLast <= isLast_inp;
      end else begin
        // shiftParallelEn == 0
        if(confSig == VECSHIFT_PARALLEL_EN) begin    // shiftParallelEn will be set to 1 on the next posedge
          isData <= 1;
          isLast <= ISLAST_REG[0];      // ISLAST_REG = 1 for the last instance of the column shift reg
        end else begin
          isData <= 0;
          isLast <= 0;
        end
      end

    // hold state for debugging (local_ce == 0) 
    end else begin
      isData <= isData;
    end

  end




  // ---- Local Interconnect ----
  // inputs of shreg shift-register
  assign shreg_serialIn   = serialIn,
         shreg_parallelIn = parallelIn,
         shreg_loadEn     = shiftParallelEn,
         shreg_shiftEn    = shiftSerialEn && serialIn_valid;    // Shift-in the serial input if the input is valid and serial-shifting is enabled
        
  // module top-level outputs
  assign parallelOut = shreg_parallelOut,
         curConfig.shiftSerialEn = shiftSerialEn,
         curConfig.shiftParallelEn = shiftParallelEn;
  


  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;   // connect the debug stepper clock

      assign dbg_shiftSerialEn   = shiftSerialEn;
      assign dbg_shiftParallelEn = shiftParallelEn;

    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule


