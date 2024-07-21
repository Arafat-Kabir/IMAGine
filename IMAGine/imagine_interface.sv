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
  Date   : Thu, Feb 15, 03:16 PM CST 2024
  Version: v1.0

  Description:
  This module implements the front-end interface to IMAGine. It provides 3 abstract 
  interfaces: FIFO-in, FIFO-out, and status registers. The clock domain
  crossing must be handled outside IMAGine, probably at the interface inputs.

================================================================================*/

`timescale 1ns/100ps


module imagine_interface # (
  parameter DEBUG = 1,
  parameter DATA_WIDTH = 16     // width of the dataout port
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

  // interface to submodule: GEMV array 
  gemvarr_instruction,
  gemvarr_inputValid,

  // interface to submodule: vector shift register column
  shreg_instruction,
  shreg_inputValid,
  shreg_parallelOut,    // inputs connected to parallel output from the shift register column
  shreg_statusOut,      // inputs connected output status bits to the shift register column

  // Debug probes
  dbg_clk_enable         // debug clock for stepping
);

  `include "imagine_interface.svh"
  `include "picaso_instruction_decoder.inc.v"
  `include "vecshift_tile.svh"


  // remove scope prefix for short-hand
  localparam GEMVARR_INSTR_WIDTH = PICASO_INSTR_WORD_WIDTH,
             DATA_ATTRIB_WIDTH   = VECSHIFT_STATUS_WIDTH;



  // -- Module IOs
  // front-end interface signals
  input                           clk;
  input [IMAGINE_INSTR_WIDTH-1:0] instruction;
  input                           instructionValid;
  output                          instructionNext;
  output [DATA_WIDTH-1:0]         dataout;
  output [DATA_ATTRIB_WIDTH-1:0]  dataAttrib;
  output                          dataoutValid;
  output                          eovInterrupt;
  input                           clearEOV;

  // Submodule control signals
  output [GEMVARR_INSTR_WIDTH-1:0]  gemvarr_instruction;
  output                            gemvarr_inputValid;
  output [VECSHIFT_INSTR_WIDTH-1:0] shreg_instruction;
  output                            shreg_inputValid;
  // submodule data signals
  input  [DATA_WIDTH-1:0]           shreg_parallelOut;
  input  [DATA_ATTRIB_WIDTH-1:0]    shreg_statusOut;


  // Debug probes
  input dbg_clk_enable;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)


  // interface to GEMV array
  wire [PICASO_INSTR_WORD_WIDTH-1:0]  gemvIntf_instruction; 
  wire                                gemvIntf_inputValid;
  wire                                gemvIntf_busy;


  gemvarray_interface # (.DEBUG(DEBUG))
    gemvIntf (
      .clk(clk),
      .instruction(gemvIntf_instruction),
      .inputValid(gemvIntf_inputValid),
      .busy(gemvIntf_busy),

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  // interface to Vector-shift register column
  localparam VECREG_WIDTH = DATA_WIDTH;   // AK-NOTE: DATA_WIDTH and VECREG_WIDTH must be equal

  wire  [VECSHIFT_INSTR_WIDTH-1:0]  vectorIntf_instruction;
  wire                              vectorIntf_inputValid;
  wire                              vectorIntf_busy;
  wire  [VECREG_WIDTH-1:0]          vectorIntf_parallelIn;
  wire  [VECREG_WIDTH-1:0]          vectorIntf_parallelOut;
  wire  [VECSHIFT_STATUS_WIDTH-1:0] vectorIntf_statusIn;
  wire  [VECSHIFT_STATUS_WIDTH-1:0] vectorIntf_statusOut;
  wire                              vectorIntf_endofvector;

  vecshift_interface #(
      .DEBUG(DEBUG),
      .REG_WIDTH(VECREG_WIDTH)) 
    vectorIntf (
      .clk(clk),
      // control signals
      .instruction(vectorIntf_instruction),
      .inputValid(vectorIntf_inputValid),
      .busy(vectorIntf_busy),

      // data IOs
      .parallelIn(vectorIntf_parallelIn),
      .parallelOut(vectorIntf_parallelOut),
      .statusIn(vectorIntf_statusIn),
      .statusOut(vectorIntf_statusOut),
      .endofvector(vectorIntf_endofvector),

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  // -- FIFO-out interface controller logic
  wire isLastVector, isDataVector;
  assign {isLastVector, isDataVector} = vectorIntf_statusOut;   // unpack shift register status bits
  assign dataout = vectorIntf_parallelOut;    // parallel output goes directly to dataout port
  assign dataoutValid = isDataVector;         // if it is a data vector, we need to push it into the FIFO-out


  // -- endofvector interrupt register
  // AK-NOTE: this srFlop is used to establish a handshake 
  // with the front-end processor.
  wire eovInt_Q;
  wire eovInt_clear;
  wire eovInt_set;

  srFlop #(
      .DEBUG(DEBUG),
      .SET_PRIORITY(0) )     // give "set" higher priority than "clear" (necessary to avoid missing eov interrupts)
    eov_ff (
      .clk(clk),
      .set(eovInt_set),
      .clear(eovInt_clear),
      .outQ(eovInt_Q),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
  );


  // -- Fetch and Dispatch unit
  wire [PICASO_INSTR_WORD_WIDTH-1:0]  fdUnit_gemvarr_instruction; 
  wire                                fdUnit_gemvarr_inputValid;
  wire                                fdUnit_gemvarr_busy;
  wire [VECSHIFT_INSTR_WIDTH-1:0]     fdUnit_vecreg_instruction;
  wire                                fdUnit_vecreg_inputValid;
  wire                                fdUnit_vecreg_busy;

  _imagineIntf_fetchDispatch #(.DEBUG(DEBUG))
    fdUnit (
      // top-level IOs
      .instruction(instruction),
      .instructionValid(instructionValid),
      .instructionNext(instructionNext),
      // signals for gemvarray_interface
      .gemvarr_instruction(fdUnit_gemvarr_instruction),
      .gemvarr_inputValid(fdUnit_gemvarr_inputValid),
      .gemvarr_busy(fdUnit_gemvarr_busy),
      // signals for vecshift_interface
      .vecreg_instruction(fdUnit_vecreg_instruction),
      .vecreg_inputValid(fdUnit_vecreg_inputValid),
      .vecreg_busy(fdUnit_vecreg_busy)
    );


  // -- Local interconnect
  // inputs of eovInt register
  assign eovInt_set = vectorIntf_endofvector,    // last element of the the vector (should be a pulse)
         eovInt_clear = clearEOV;      // front-end processor issues clear on eovInt

  // inputs of vectorIntf
  assign vectorIntf_parallelIn = shreg_parallelOut,   // top-level inputs from the register column
         vectorIntf_statusIn = shreg_statusOut,       // top-level inputs from the register column
         vectorIntf_instruction = fdUnit_vecreg_instruction,
         vectorIntf_inputValid  = fdUnit_vecreg_inputValid;

  // inputs of gemvIntf
  assign gemvIntf_instruction = fdUnit_gemvarr_instruction,
         gemvIntf_inputValid  = fdUnit_gemvarr_inputValid;

  // inputs of fdUnit
  assign fdUnit_gemvarr_busy = gemvIntf_busy,
         fdUnit_vecreg_busy  = vectorIntf_busy;

  // Top-level IO
  assign eovInterrupt = eovInt_Q,
         dataAttrib  = {isLastVector, isDataVector};

  assign gemvarr_instruction = fdUnit_gemvarr_instruction,
         gemvarr_inputValid  = fdUnit_gemvarr_inputValid,
         shreg_instruction = fdUnit_vecreg_instruction,
         shreg_inputValid  = fdUnit_vecreg_inputValid;


  // -- 
  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule



// This is a submodule of IMAGine interface. This is not supposed to be Reusable.
// This module generates signals for fetching instruction from FIFO-in and
// distributing the instruction to the appropriate submodule using ready/valid
// handshake. It maps the incoming instructions (IR3) into appropriate
// instructions for the submodule
module _imagineIntf_fetchDispatch #(
  parameter DEBUG = 1
)  (
  instruction,
  instructionValid,
  instructionNext,
  // signals for gemvarray_interface
  gemvarr_instruction,
  gemvarr_inputValid,
  gemvarr_busy,
  // signals for vecshift_interface
  vecreg_instruction,
  vecreg_inputValid,
  vecreg_busy
);


  `include "imagine_interface.svh"
  `include "picaso_instruction_decoder.inc.v"
  `include "vecshift_tile.svh"

  // validate assumptions
  `AK_ASSERT2(PICASO_INSTR_WORD_WIDTH == 30, GEMV_tile_instruction_width_mismatch)
  `AK_ASSERT2(VECSHIFT_INSTR_WIDTH <= PICASO_INSTR_SEG2_WIDTH, Vector_register_instruction_width_mismatch)

  // -- Module IOs
  input  [IMAGINE_INSTR_WIDTH-1:0]      instruction;
  input                                 instructionValid;
  output                                instructionNext;

  output [PICASO_INSTR_WORD_WIDTH-1:0]  gemvarr_instruction; 
  output                                gemvarr_inputValid;
  input                                 gemvarr_busy;

  output [VECSHIFT_INSTR_WIDTH-1:0]     vecreg_instruction;
  output                                vecreg_inputValid;
  input                                 vecreg_busy;


  // -- Extract instruction fields for submodules
  // instruction fields: 
  // [31:30]  : 2-bit submodule selection code
  // [29: 0]  : GEMV array instruction
  // SEG2[1:0]: Vector-shift register instruction (lower 2 bits of the OPCODE segment of picaso-controller instruction)
  localparam SUBMODULE_CODE_WIDTH = IMAGINE_SUBMODULE_CODE_WIDTH;

  localparam [SUBMODULE_CODE_WIDTH-1:0]
             GEMVARR_SELECT = IMAGINE_SUBMODULE_GEMVARR_SELECT,
             VECSHIFT_SELECT = IMAGINE_SUBMODULE_VECSHIFT_SELECT;

  localparam SEG2_WIDTH = PICASO_INSTR_SEG2_WIDTH;

  wire [SUBMODULE_CODE_WIDTH-1:0]  submoduleCode;
  wire [SEG2_WIDTH-1:0]            instrSeg2;

  assign submoduleCode = instruction[PICASO_INSTR_WORD_WIDTH   +: SUBMODULE_CODE_WIDTH];
  assign instrSeg2     = instruction[PICASO_INSTR_WORD_WIDTH-1 -: SEG2_WIDTH];
  assign gemvarr_instruction = instruction[PICASO_INSTR_WORD_WIDTH-1:0];
  assign vecreg_instruction  = instrSeg2[VECSHIFT_INSTR_WIDTH-1:0];


  // -- Generate valid signals
  wire selectVecreg, selectGEMVarr;
  assign selectVecreg  = (submoduleCode == VECSHIFT_SELECT),
         selectGEMVarr = (submoduleCode == GEMVARR_SELECT);

  // vecreg_inputValid will be set if,
  //   - current instruction is valid,
  //   - instruction selects the vecreg submodule,
  //   - and vecreg is not busy
  assign vecreg_inputValid = instructionValid && selectVecreg && !vecreg_busy;
  
  // gemvarr_inputValid will be set if,
  //   - current instruction is valid,
  //   - instruction selects the GEMV-array submodule,
  //   - and gemvarr is not busy
  assign gemvarr_inputValid = instructionValid && selectGEMVarr && !gemvarr_busy;


  // -- Generate instruction fetch signal
  // Instruction will be fetched if any one of the submodules
  // consumes the current instruction.
  assign instructionNext = vecreg_inputValid || gemvarr_inputValid;


endmodule




// This is a submodule of IMAGine interface. This is not supposed to be Reusable.
// This module uses parts of the GEMV tile to mimic the controller state and generates
// signals needed for synchronization.
module gemvarray_interface # (
  parameter DEBUG = 1
) (
  clk,
  // Same inputs as gemvtile
  instruction,
  inputValid,
  // these are the signal of interest for IMAGine interface
  busy,

  // Debug probes
  dbg_clk_enable         // debug clock for stepping
);

  // `include "imagine_interface.svh"
  `include "gemvtile.svh"


  // -- Module IOs
  input                        clk;
  input [CTRL_INSTR_WIDTH-1:0] instruction;
  input                        inputValid;
  output                       busy;

  // Debug probes
  input dbg_clk_enable;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)



  // PiCaSO controller: only the signals related to status are connected.
  // AK-NOTE: Unconnected IOs and related logic will be optimized away in synthesis.
  wire [CTRL_INSTR_WIDTH-1:0] ctrl_instruction;
  wire                        ctrl_inputValid;
  wire                        ctrl_busy;
  wire                        ctrl_nextInstr;


  (* keep_hierarchy = "yes" *)
  picaso_controller #(
      .DEBUG(DEBUG),
      .INSTRUCTION_WIDTH(CTRL_INSTR_WIDTH),
      .NET_LEVEL_WIDTH(NET_LEVEL_WIDTH),
      .OPERAND_WIDTH(PE_OPERAND_WIDTH),
      .PICASO_ID_WIDTH(ID_WIDTH),
      .TOKEN_WIDTH(CTRL_TOKEN_WIDTH),
      .PE_REG_WIDTH(PE_OPERAND_WIDTH),
      .MAX_PRECISION(MAX_PRECISION) )
    controller (
      .clk(clk),
      .instruction(ctrl_instruction),
      .token_in('0),
      .inputValid(ctrl_inputValid),
      .busy(ctrl_busy),
      .nextInstr(ctrl_nextInstr),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );



  // -- Local interconnect
  // inputs to the controller
  assign ctrl_instruction = instruction,
         ctrl_inputValid  = inputValid;

  // Top-level IO
  assign busy = !ctrl_nextInstr;    // if controller not ready for next instruction, we say it's busy.


  // -- 
  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule




// This is a submodule of IMAGine interface. This is not supposed to be Reusable.
// This module uses parts of the vecshift tile to mimic the controller state and generates
// signals needed for synchronization.
module vecshift_interface #(
  parameter DEBUG = 1,
  parameter REG_WIDTH = -1
) (
  clk,
  // control signals
  instruction,          // instruction for the tile controller
  inputValid,           // Single-bit input signal, 1: other input signals are valid, 0: other input signals not valid (this is needed to work with shift networks)
  busy,                 // signals if the submodule is busy

  // data IOs
  parallelIn,           // parallel input from bottom tile
  parallelOut,          // parallel output to the above tile
  statusIn,             // input status bits from the bottom tile
  statusOut,            // output status bits to the above tile
  endofvector,          // signals if this is the last element of the vector; will generate a pulse

  // Debug probes
  dbg_clk_enable        // debug clock for stepping
);


  `include "vecshift_tile.svh"


  // validate module parameters
  `AK_ASSERT2(REG_WIDTH > 0, REG_WIDTH_must_be_set)

  // remove scope prefix for short-hand
  localparam INSTR_WIDTH  = VECSHIFT_INSTR_WIDTH,
             CONFIG_WIDTH = VECSHIFT_CONFIG_WIDTH,
             STATUS_WIDTH = VECSHIFT_STATUS_WIDTH;


  // IO Ports
  input                     clk;
  input  [INSTR_WIDTH-1:0]  instruction;
  input                     inputValid;
  output logic              busy;
  input  [REG_WIDTH-1:0]    parallelIn;
  output [REG_WIDTH-1:0]    parallelOut;
  input  [STATUS_WIDTH-1:0] statusIn;
  output [STATUS_WIDTH-1:0] statusOut;
  output                    endofvector;

  // Debug probes
  input   dbg_clk_enable;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)

  // unpack the top-level status input
  wire statIn_isLast, statIn_isData;
  wire isLastElement;     // indicates if this data is the last valid element of the vector

  assign {statIn_isLast, statIn_isData} = statusIn;
  assign isLastElement = statIn_isLast && statIn_isData;    // this will always generate a pulse, even if isLast stays high beyond the last valid element.


  /*
  // -- Controller
  wire [INSTR_WIDTH-1:0]  ctrl_instruction;
  wire                    ctrl_inputValid;
  wire [CONFIG_WIDTH-1:0] ctrl_vecreg_confSig;   // control signal for dummy shift-register

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
  */


  /*
  // -- Dummy Shift register
  // AK-NOTE: We only want to know the current configuration of the vector shift registers
  wire [CONFIG_WIDTH-1:0] vecreg_confSig;   // control signal for dummy shift-register
  wire vecshift_reg_intConfig_t vecreg_curConfig;

  vecshift_reg #(
      .DEBUG(DEBUG),
      .REG_WIDTH(2),      // doesn't matter, we'll not be using the registers and thus will be optimized away by synthesis
      .ISLAST_REG(0) )
    vecreg (
      .clk(clk),
      .serialIn('0),
      .serialIn_valid('0),
      .parallelIn('0),
      // .parallelOut(),
      .confSig(vecreg_confSig),
      .statusIn('0),
      // .statusOut(),
      .curConfig(vecreg_curConfig),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)
  );
  */


  /*
  // -- endofvector status bit
  // AK-NOTE: eov_ff indicates, if last vector element has been seen since
  // parallel shifting was enabled.
  wire eovff_Q;
  wire eovff_clear;
  wire eovff_set;

  srFlop #(
      .DEBUG(DEBUG),
      .SET_PRIORITY(1) )     // give "clear" higher priority than "set" (necessary for the busy logic)
    eov_ff (
      .clk(clk),
      .set(eovff_set),
      .clear(eovff_clear),
      .outQ(eovff_Q),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
  );

  // set clear logic
  assign eovff_clear = !vecreg_curConfig.shiftParallelEn;   // continuously clear the eovff if parallel shifting not enabled. This has higher priority over set signal.
  assign eovff_set   = isLastElement;   // the last valid data sets eovff, if parallel shifting is enabled (lower priority on eovff.set).
  */


  // -- busy logic
  // AK-NOTE: Vector shift register column does not inherently generate busy
  // logic; it can be configured to be idle, shift-in serial input, or
  // shift-in/out parallel inputs. It is ALWAYS ready to accept a new
  // configuration. Thus, we need to define a busy condition for the top-level
  // interface separately.
  // We define the busy logic for the front-end interface as follows.
  // The shift register column is busy 
  //   - if parallel-shifting has been requested,
  //   - but the last element of the vector has not been written out to the
  //     FIFO-out interface yet.
  //
  // ** Following is the behavioral implementation. However, as the logic is
  //    too simple, we can write it using a simple boolean expression.
  // always@* begin
  //   busy = 1'b0;    // default value (to avoid generation of latch by mistake)
  //   if(vecreg_curConfig.shiftParallelEn) begin
  //     // stay busy until you write out the last vector
  //     if(eovff_Q) busy = 1'b0;    // eovff_Q == 1 means last vector has been written
  //     else busy = 1'b1;
  //   end else begin
  //     // parallel shiftin is disabled, so the shift registers are not busy
  //     busy = 1'b0;
  //   end
  // end
  //
  (* extract_enable = "yes", extract_reset = "yes" *)
  reg isPshiftReq = 0;    // tracks if parallel shifting was requested

  always@(posedge clk) begin
    if(instruction == VECSHIFT_PARALLEL_EN && inputValid) isPshiftReq <= 1'b1;    // if parallel-shifting instruction is issued, set isPshiftReq
    else if(isLastElement) isPshiftReq <= 1'b0;   // if last element arrived, clear isPshiftReq (the request was served)
    else isPshiftReq <= isPshiftReq;   // otherwise, hold the value
  end


  //assign busy = vecreg_curConfig.shiftParallelEn && !eovff_Q;
  assign busy = isPshiftReq;


  // ---- Local Interconnect ----
  // inputs of tile controller
  // assign ctrl_instruction = instruction,
  //        ctrl_inputValid  = inputValid;

  // inputs of the dummy vecreg
  // assign vecreg_confSig = ctrl_vecreg_confSig;

  // top-level outputs
  assign parallelOut = parallelIn,    // data signals are simply forwarded
         statusOut   = statusIn,      // without registering
         endofvector = isLastElement;


  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;   // connect the debug stepper clock

    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule
