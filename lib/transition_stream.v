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

  Author : MD Arafat Kabir
  Email  : arafat.sun@gmail.com
  Date   : Mon, Oct 09, 03:46 PM CST 2023
  Version: v1.0

  Description:
  This module describes the transition table for streamed read/write
  instructions (MOV). It is a purely combinatorial module.

  The transition table describes the following FSM. Checkout the transition
  table comments with the code for details of what each state does.


                     .---------------.    .--------------.
       .------.      | aluRst        |    | aluLoadParam |
  ---->| INIT |----->| opmxLoadParam |--->| bRead        |---.
       '------'      | bRead         |    '--------------'   |
           ^         '---------------'                       |
           |                                                 |
           |                             .-------.           v
           |         .--------------.    | aluEn |     .---------.
           '---------| bStreamWrite |<---| bRead |<----| bRead_0 |
     count1_done     '--------------'    '-------'     '---------'
                        ^        v
                        |        |
                        '---<----'
                      precision-value
                         (count1)

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"



module transition_stream #(
  parameter DEBUG = 1,
  parameter STATE_CODE_WIDTH = -1,
  parameter COUNT0_VAL_WIDTH = -1
) (
  cur_state,      // current state input
  next_state,     // next state output
  algo_done,      // signals that this is the last state, next state will be INIT

  count0_val,      // value to load into counter
  count0_load,     // enable signal to load
  count0_en,       // enable counting
  count0_done,     // counter expired

  count1_valSelect, // selects counter1 load value
  count1_load,      // enable signal to load
  count1_en,        // enable counting
  count1_done       // counter expired
);

  `include "picaso_algorithm_decoder.inc.v"
  `include "picaso_algorithm_fsm.inc.v"

  `AK_ASSERT(STATE_CODE_WIDTH == PICASO_ALGO_CODE_WIDTH)
  //`AK_TOP_WARN("Add state diagram for transition_stream AFTER testing")    // simulation-time warning (uncomment this if implementation is changed)

  localparam [STATE_CODE_WIDTH-1:0] INIT_STATE = PICASO_ALGO_NOP;   // all state-machines starts at PICASO_ALGO_NOP state


  // IO Ports
  input      [STATE_CODE_WIDTH-1:0] cur_state;
  output reg [STATE_CODE_WIDTH-1:0] next_state;
  output reg                        algo_done;

  output reg [COUNT0_VAL_WIDTH-1:0]  count0_val;
  output reg                         count0_load;
  output reg                         count0_en;
  input                              count0_done;

  output reg [ALGORITHM_CTR1_SEL_WIDTH-1:0] count1_valSelect;
  output reg                                count1_load;
  output reg                                count1_en;
  input                                     count1_done;


  // -- Task to set default values for the output ports to values equivalent of NOP
  localparam COMMON_CNT0_VAL = 2;     // it is a common value for counter0
  task all_nop;
    begin
      algo_done = 0;        // NOP
      count0_load = 0;      // NOP
      count0_en = 0;        // NOP
      count1_load = 0;      // NOP
      count1_en = 0;        // NOP
      count1_valSelect = 0;
      count0_val = COMMON_CNT0_VAL;  // overlap with common cases reduces logic utilization
    end
  endtask



  // state transition table:
  //   - It computes the next state based on current state and counter states.
  //   - It also generates the counter control signals
  always@* begin
    all_nop;     // start with NOP 
    (* full_case, parallel_case *)
    case(cur_state)
      INIT_STATE: begin
        // Load the counter1 to "precision" for iterations
        // Move to a state that
        //   - resets alu
        //   - loads the opmux config decoded from instruction
        //   - reads BRAM and increments the pointers
        count1_valSelect = ALGORITHM_CTR1_SEL_FULL;
        count1_load = 1'b1;
        next_state =  PICASO_ALGO_aluRst_opmxLoadParam_bRead;
      end

      PICASO_ALGO_aluRst_opmxLoadParam_bRead: begin
        // Move to a state that
        //   - loads alu config decoded from instruction
        //   - reads BRAM and increments the pointers
        next_state = PICASO_ALGO_aluLoadParam_bRead;
      end

      PICASO_ALGO_aluLoadParam_bRead: begin
        // Move to a state that
        //   - simply reads from BRAM and increments the pointers
        next_state = PICASO_ALGO_bRead_0;
      end
      
      PICASO_ALGO_bRead_0: begin
        // Move to a state that
        //   - reads from BRAM and increments the pointers
        //   - enables ALU for computation
        next_state = PICASO_ALGO_aluEn_bRead;
      end

      PICASO_ALGO_aluEn_bRead: begin
        // Decrement the iteration coutner (counter1), doing so here makes it possible to use val0 as the counter-done signal.
        // Move to a state that
        //   - keeps ALU enabled
        //   - reads from BRAM, and increment read pointer
        //   - writes the ALU output to BRAM and increments the pointers
        count1_en = 1'b1;
        next_state = PICASO_ALGO_bStreamWrite;
      end

      PICASO_ALGO_bStreamWrite: begin
        // Decrement the iteration counter (counter1).
        // Check if counter1 expired. 
        // if no:
        //   - stay in this state
        // if yes: 
        //   - assert done signal
        //   - go back to initial state and 
        count1_en = 1'b1;
        if(!count1_done) begin
          next_state = PICASO_ALGO_bStreamWrite;
        end else begin
          algo_done = 1;
          next_state = INIT_STATE;
        end
      end
      
      default: next_state = INIT_STATE;    // NOP and go back to initial state
    endcase
  end


endmodule
