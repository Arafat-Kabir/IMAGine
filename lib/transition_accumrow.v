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
  Date   : Fri, Oct 13, 11:18 AM CST 2023
  Version: v1.0

  Description:
  This module describes the transition table for ACCUM-ROW instruction. It is
  a purely combinatorial module.

  The transition table describes the following FSM. Checkout the transition
  table comments with the code for details of what each state does.


         Load headstart      Capture En
         count in count1     Inc Ptr En
                .                .
                |  .----------.  |  .-----------.    .---------------.
       .------. |  | accumRow |  |  | accumRow  |    | aluRst        |
  ---->| INIT |--->| setup    |---->| headstart |--->| opmxLoadParam |-------.
       '------'    '----------'     '-----------'    | bRead         |       |
           ^                          ^      |       '---------------'       |
           |                          '--<---'                               |
           |                       headstart-value                           |
           |                          (count1)                               |
           | count1_done                                                     |
           |                                                                 v
           |                             .-------.                   .--------------.
           |         .--------------.    | aluEn |    .---------.    | aluLoadParam |
           '----.----| bStreamWrite |<---| bRead |<---| bRead_0 |<---| bRead        |
                |    '--------------'    '-------'    '---------'    '--------------'
                |       ^        v
       Capture !En      |        |
       Inc Ptr !En      '---<----'
                      precision-value
                         (count1)

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"



module transition_accumrow #(
  parameter DEBUG = 1,
  parameter SEL_WIDTH = -1,
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
  count1_done,      // counter expired

  setNetCaptureEn,   // sets the netCaptureEn flip-flop
  clrNetCaptureEn,   // clears the netCaptureEn flip-flop
  setPicasoPtrIncr,  // sets the picasoPtrIncr flip-flop
  clrPicasoPtrIncr   // clears the picasoPtrIncr flip-flop
);

  `include "picaso_algorithm_decoder.inc.v"
  `include "picaso_algorithm_fsm.inc.v"

  `AK_ASSERT(STATE_CODE_WIDTH>0)
  //`AK_TOP_WARN("Add state diagram for transition_accumrow AFTER testing")    // simulation-time warning (uncomment this if implementation is changed)

  localparam [STATE_CODE_WIDTH-1:0] INIT_STATE = PICASO_ALGO_NOP;   // all state-machines starts at PICASO_ALGO_NOP state

  // IO Ports
  input      [STATE_CODE_WIDTH-1:0] cur_state;
  output reg [STATE_CODE_WIDTH-1:0] next_state;
  output reg                        algo_done;

  output reg [COUNT0_VAL_WIDTH-1:0] count0_val;
  output reg                        count0_load;
  output reg                        count0_en;
  input                             count0_done;

  output reg [ALGORITHM_CTR1_SEL_WIDTH-1:0] count1_valSelect;
  output reg                                count1_load;
  output reg                                count1_en;
  input                                     count1_done;

  output reg      setNetCaptureEn;
  output reg      clrNetCaptureEn;
  output reg      setPicasoPtrIncr;
  output reg      clrPicasoPtrIncr;


  // -- Task to set default values for the output ports to values equivalent of NOP
  localparam COMMON_CNT0_VAL = 2;     // it is a common value for counter0
  task all_nop;
    begin
      algo_done = 0;         // NOP
      count0_load = 0;       // NOP
      count0_en = 0;         // NOP
      count1_load = 0;       // NOP
      count1_en = 0;         // NOP
      count1_valSelect = 0;
      setNetCaptureEn  = 0;  // NOP
      clrNetCaptureEn  = 0;  // NOP
      setPicasoPtrIncr = 0;  // NOP
      clrPicasoPtrIncr = 0;  // NOP
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
        // Load the counter1 with "head-start" count for filling up the network
        // nodes with transmitter stream.
        // Move to a state that
        //   - sets up network configuration (loads the level value)
        //   - loads the transmitter start address in local pointers of picaso blocks
        count1_valSelect = ALGORITHM_CTR1_SEL_ACCUM_HEADSTART;
        count1_load = 1'b1;
        next_state =  PICASO_ALGO_accumRow_setup;
      end

      PICASO_ALGO_accumRow_setup: begin
        // Enable network capture register.
        // Set picaso local pointer-increment signal.
        // Move to a state that 
        //   - fills up the network nodes with tranmitter stream for head-start cycles.
        //   - keeps network capture enabled (set by the accum-row-setup state)
        //   - keeps picaso local pointer-increment enabled
        setNetCaptureEn = 1'b1;
        setPicasoPtrIncr = 1'b1;
        next_state =  PICASO_ALGO_accumRow_headstart;
      end

      PICASO_ALGO_accumRow_headstart: begin
        // Decrement head-start counter (counter1).
        // Check if counter1 expired.
        // if no: 
        //   - stay in this state
        // if yes:
        //   - Move to next state
        // The next state
        //   - resets alu
        //   - loads the opmux config decoded from instruction param field
        //   - reads BRAM and increments the pointers
        count1_en = 1'b1;
        if(!count1_done) begin
          next_state = PICASO_ALGO_accumRow_headstart;
        end else begin
          next_state =  PICASO_ALGO_aluRst_opmxLoadParam_bRead;
        end
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
        // Load counter1 with "precision" value for iterations.
        // Move to a state that
        //   - reads from BRAM and increments the pointers
        //   - enables ALU for computation
        count1_valSelect = ALGORITHM_CTR1_SEL_FULL;   // selects the precision (full) value
        count1_load = 1'b1;
        next_state = PICASO_ALGO_aluEn_bRead;
      end

      PICASO_ALGO_aluEn_bRead: begin
        // Decrement the iteration coutner (counter1), doing so here makes it possible to use val0 as the counter-done signal.
        // Move to a state that
        //   - apply the alu-op to the network stream and BRAM read-stream
        //     for the "precision" number of cycles
        //   - keeps ALU enabled
        //   - reads from BRAM, and increment read pointer
        //   - writes the ALU output to BRAM and increments the write pointer
        count1_en = 1'b1;
        next_state = PICASO_ALGO_bStreamWrite;
      end

      PICASO_ALGO_bStreamWrite: begin
        // Decrement the iteration counter (counter1).
        // Check if counter1 expired. 
        // if no:
        //   - stay in this state
        // if yes: 
        //   - disable network capture register
        //   - clear picaso local pointer-increment signal
        //   - assert done signal
        //   - go back to initial state and 
        count1_en = 1'b1;
        if(!count1_done) begin
          next_state = PICASO_ALGO_bStreamWrite;
        end else begin
          clrNetCaptureEn = 1'b1;
          clrPicasoPtrIncr = 1'b1;
          algo_done = 1;
          next_state = INIT_STATE;
        end
      end
      
      default: next_state = INIT_STATE;    // NOP and go back to initial state
    endcase
  end

endmodule
