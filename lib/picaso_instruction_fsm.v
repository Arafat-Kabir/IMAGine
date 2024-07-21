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
  Date  : Tue, Aug 22, 04:40 PM CST 2023

  Description:
  This module implements the frontend FSM of picaso_controller module. It is needed
  to efficiently handle 2 types of instructions: single-cycle instruction and
  multi-cycle algorithms.  It can stream multiple single-cycle instructions
  without incurring extra cycle (1 cycle per instruction).  It can stream
  multiple multi-cycles algorithms with only 1 extra cycle per instruction.

  High-level description of the FSM: (NOTE: May not 100% match with the actual implementation)
  - Initial state: READY (state code should be 0)
  - <READY> state functions
    - check if instruction valid
      - if valid: check if it is a single-cycle or a multi-cycle instruction
        - if single-cycle
          - Send decoded signals to picaso control signal register
          - Stay in READY state
          - Request "clear" on instruction register
        - if multi-cycle
          - Save algorithm parameters
          - Select correct algorithm FSM (load selection reg)
          - Enable algorithm FSM
          - Select algorithm signals for picaso control
          - Request "clear" on instruction register
          - Transition to BUSY state
      - if not valid
          - Stay in READY state
          - Select algorithm signal set, which should correspond to NOP in INIT state
  - <BUSY> state functions
    - check if algorithm FSM "done" signal is asserted
      - if yes: transition to READY state
      - if no : stay in BUSY state

  Version: v1.0

================================================================================*/
`timescale 1ns/100ps



module picaso_instruction_fsm #(
  parameter DEBUG = 1,
  parameter OPCODE_WIDTH = -1,
  parameter FN_WIDTH = -1
) (
  clk,              // clock
  instrValid,       // instruction register status signal
  algoDone,         // signal coming from algorithm FSM signaling transition back to INIT state
  algoselCode,      // pre-decoded algorithm selection code input
  instrType,        // pre-decoded instruction type code input

  selCtrlSet,       // selects between algorithm vs directly decoded signals for the picaso control signals
  selAlgo,          // selects the algorithm FSM
  enAlgo,           // enables algorithm FSM
  saveAlgoParam,    // saves parameters for algorithm FSM
  clearInstr,       // requests "clear" for the instruction register
  busy,             // FSM is in busy state

  // Debug probes
  dbg_clk_enable
);


  `include "picaso_controller.inc.v"
  `include "picaso_instruction_decoder.inc.v"
  `include "picaso_algorithm_fsm.inc.v"

  `AK_ASSERT2(OPCODE_WIDTH > 0, OPCODE_WIDTH_not_set)
  `AK_ASSERT2(FN_WIDTH > 0, FN_WIDTH_not_set)

  // IO Ports
  input                            clk;
  input                            instrValid;
  input                            algoDone;
  input  [ALGORITHM_SEL_WIDTH-1:0] algoselCode;
  input  [PICASO_INSTR_TYPE_CODE_WIDTH-1:0] instrType;

  // set as reg for behavioral modeling
  output reg                           selCtrlSet;
  output reg [ALGORITHM_SEL_WIDTH-1:0] selAlgo;
  output reg                           enAlgo;
  output reg                           saveAlgoParam;
  output reg                           clearInstr;
  output reg                           busy;

  // Debug probes
  input  dbg_clk_enable;


  // internal signals
  wire local_ce;    // module-level clock enable, needed for debugging support




  // -- Algorithm selection register
  (* extract_enable = "yes" *)
  reg  [ALGORITHM_SEL_WIDTH-1:0] algosel_reg = 0;
  reg                            algosel_load;    // load enable of algosel_reg

  always@(posedge clk) begin
    if(local_ce && algosel_load)
      algosel_reg <= algoselCode;     // load selection code if requested
    else
      algosel_reg <= algosel_reg;     // otherwise, hold the value
  end




  // ---- State Machine ----
  localparam READY = 0, BUSY = 1;     // state-codes, READY is the initial state (0)
  localparam STATE_CODE_WIDTH = 1;

  (* extract_enable = "yes" *)
  reg [STATE_CODE_WIDTH-1:0] state_reg = READY;   // does not have enable or reset. Still specifying extract_enable.
  reg [STATE_CODE_WIDTH-1:0] next_state;

  always@(posedge clk) begin
    if(local_ce)
      state_reg <= next_state;
    else
      state_reg <= state_reg;
  end


  // state transition table: 
  //   computes the next state based on current state and some input signals,
  //   should generate a single combo block. Returns the next state.
  always@* begin
    // read the Description at the top to understand the transition conditions
    (* full_case, parallel_case *)
    case(state_reg)   // state_reg = current state
      READY: begin
        if(instrValid && instrType == INSTR_TYPE_MULTI_CYCLE)
          next_state = BUSY;
        else
          next_state = READY;
      end

      BUSY: begin
        if(algoDone) next_state = READY;
        else         next_state = BUSY;
      end

      default: $display("EROR: This state should not exist, %b", state_reg);
    endcase
  end


  // ---- output signal logic: Based on the current state and other
  // module-level signals, determines the control signals.
  // read the Description at the top to understand the signal assignments.
  always @* begin
    // start with sensible default values (common denominator of all state assignments)
    selCtrlSet = PICASO_CTRL_SEL_DECODE_SIGNALS;   // should be NOP at initialization
    enAlgo = 0;             // disable algorithm FSM
    selAlgo = algosel_reg;  // this is the default selection
    algosel_load = 0;       // don't load algorithm selection register
    saveAlgoParam = 0;      // don't change parameter registers
    clearInstr = 0;         // don't request "clear"
    busy = 0;               // not in BUSY state

    // state-based assignment
    case(state_reg)     // state_reg = current state
      READY: begin
        // AK-NOTE: Following assignment of selAlgo is an optimization. DON'T MOVE without complete understanding and testing!
        //   - Use input algoselCode in the READY state and save it in algosel_reg to be used in BUSY state.
        //   - algosel_reg will be updated on next posedge, but FSM needs to change state for the selected algorithm at the same edge as well.
        //   - The selAlgo output does not matter for SINGLE_CYCLE_TYPE instructions, it'll simply be ignored.
        selAlgo = algoselCode;

        if(instrValid) begin
          if (instrType == INSTR_TYPE_SINGLE_CYCLE) begin
            selCtrlSet = PICASO_CTRL_SEL_DECODE_SIGNALS;
            clearInstr = 1;    // request clear after consuming this instruction
            // Rest of the signals have the default values defined above
          end else begin
            algosel_load = 1;        // load selected algorithm in the algosel_reg
            saveAlgoParam = 1;
            enAlgo = 1;
            selCtrlSet = PICASO_CTRL_SEL_ALGO_SIGNALS;
            clearInstr = 1;    // request clear after consuming this instruction
            // Rest of the signals have the default values defined above
          end


        end else begin
          // instruction not valid
          selCtrlSet = PICASO_CTRL_SEL_ALGO_SIGNALS;   // Algorithm FSM should be in INIT (=NOP) state when this FSM is in READY state
          // Rest of the signals have the default values defined above
        end
      end

      BUSY: begin
        selCtrlSet = PICASO_CTRL_SEL_ALGO_SIGNALS;   // should be INIT (=NOP) if in READY state
        enAlgo = 1;              // keep algorithm FSM enabled
        selAlgo = algosel_reg;   // algosel_reg has the selected algorithm in BUSY state
        busy = 1;                // in BUSY state
        // Rest of the signals have the default values defined above
      end

      default: $display("EROR: This state should not exist, %b", state_reg);
    endcase
  end




  // Connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;    // no top-level clock enable
    end
  endgenerate
endmodule
