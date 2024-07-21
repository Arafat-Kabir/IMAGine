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
  Date   : Thu, Aug 24, 02:32 PM CST 2023
  Version: v1.0

  Description:
  This a wrapper module for running several independent FSMs that only share
  start and/or end common states.  Any one of them can be selected based on
  a selection code. Each FSM is modeled as a combinatorial block and they share
  all sequential elements like state-register, counter, or any other memory
  elements. This design approach makes adding/removing/changing each
  algorithm-FSM more manageable by separating concerns. Moreover, it maximizes
  resource sharing by sharing memory elements and state codes among algorithm
  FSMs. 
  The state codes are defined by the signal decoder, which interprets those
  state-codes.  The signal decoder is the only element that ties this
  controller to a particular device/module implementation.  If the control
  signals of picaso changes, you only need to change the signal decoder and
  your existing algorithm FSMs should work.

  Here is the high-level architecture of this module: 
  (NOTE: This is only conceptual, may not 100% match with the implementation)

                            control signals
                                | | | |
                          .----------------.
                          | signal decoder |
                          '----------------'
                                   ^
                                   | control-code
          ------------------------------------------------  [outside this module]
                                   | current state
                                   |
                            .------------.
          clock enable -->  | state regs |
                            '------------'
                              ^       |
                   next state |       | current state
                              |       v
                         .-------------------.
    Algorithm Select --> | transition tables |
                         | (Algorithms)      |
                         '-------------------'
                              ^       |
                 counter done |       | counter load
                              |       v
                          .-----------------.
                          | loop-counter(s) |
                          '-----------------'

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"



module picaso_algorithm_fsm #(
  parameter DEBUG = 1,
  parameter PRECISION_WIDTH = -1,
  parameter INSTR_PARAM_WIDTH = -1,
  parameter NET_LEVEL_WIDTH = -1
) (
  clk,                // clock
  precision,          // current precision value
  param,              // param field of the instruction word
  enTransition,       // enables state transitions
  selAlgo,            // selects a particular algorithm
  ctrlCode,           // control-code for the signal decoder
  algoDone,           // signals the end of algorithm (transition back to initial state)
  // special signals for over-the network accumulation algorithm
  setNetCaptureEn,   // sets the netCaptureEn flip-flop
  clrNetCaptureEn,   // clears the netCaptureEn flip-flop
  setPicasoPtrIncr,  // sets the picasoPtrIncr flip-flop
  clrPicasoPtrIncr,  // clears the picasoPtrIncr flip-flop

  // Debug probes
  dbg_clk_enable
);

  `include "picaso_algorithm_fsm.inc.v"
  `include "picaso_algorithm_decoder.inc.v"

  `AK_ASSERT2(PRECISION_WIDTH > 0, PRECISION_WIDTH_not_set)
  `AK_ASSERT2(NET_LEVEL_WIDTH > 0, NET_LEVEL_WIDTH_not_set)
  `AK_ASSERT2(INSTR_PARAM_WIDTH >= 0, INSTR_PARAM_WIDTH_not_set)

  
  // IO Ports
  input                                 clk;
  input  [PRECISION_WIDTH-1:0]          precision;
  input  [INSTR_PARAM_WIDTH-1:0]        param;
  input                                 enTransition;
  input  [ALGORITHM_SEL_WIDTH-1:0]      selAlgo;
  output [PICASO_ALGO_CODE_WIDTH-1:0]   ctrlCode;
  output                                algoDone;

  output   setNetCaptureEn;
  output   clrNetCaptureEn;
  output   setPicasoPtrIncr;
  output   clrPicasoPtrIncr;

  // Debug probes
  input   dbg_clk_enable;


  // internal signals
  wire local_ce;    // module-level clock enable, needed for debugging support


  // ---- State Machine ----
  localparam STATE_CODE_WIDTH = PICASO_ALGO_CODE_WIDTH;   // signal-codes are directly used as state codes to avoid extra mapping logic

  (* extract_enable = "yes" *)
  reg  [STATE_CODE_WIDTH-1:0] state_reg = PICASO_ALGO_NOP;   // initialize with NOP to avoid changing picaso state
  wire [STATE_CODE_WIDTH-1:0] next_state;

  always@(posedge clk) begin
    if(enTransition && local_ce)      // change state only if enTransition is enabled (local_ce is for debugging)
      state_reg <= next_state;
    else
      state_reg <= state_reg;
  end

  assign ctrlCode = state_reg;      // state codes are the control codes


  // ---- Transition table
  localparam COUNT0_VAL_WIDTH = 3,
             COUNT1_VAL_WIDTH = `AK_MAX(PRECISION_WIDTH, 4);  // Counter-1 needs to support upto given precision value and head-start count for ACCUM-ROW.
                                                              // 4-bits can handle head-start of upto 16 (load-val=15), which implies 32 blocks, and so 32x16 = 512 columns, and so 512x512 = 262K 2D array (Alveo U55 can support upto 64K array)
  wire [COUNT0_VAL_WIDTH-1:0] tran_tables_count0_val;
  wire                        tran_tables_count0_load;
  wire                        tran_tables_count0_en;
  wire                        tran_tables_count0_done;

  wire [ALGORITHM_CTR1_SEL_WIDTH-1:0] tran_tables_count1_valSelect;
  wire                                tran_tables_count1_load;
  wire                                tran_tables_count1_en;
  wire                                tran_tables_count1_done;

  wire      tran_tables_setNetCaptureEn;
  wire      tran_tables_clrNetCaptureEn;
  wire      tran_tables_setPicasoPtrIncr;
  wire      tran_tables_clrPicasoPtrIncr;

  _algorithm_fsm_transition_tables #(
      .DEBUG(DEBUG),
      .SEL_WIDTH(ALGORITHM_SEL_WIDTH),
      .STATE_CODE_WIDTH(STATE_CODE_WIDTH),
      .COUNT0_VAL_WIDTH(COUNT0_VAL_WIDTH) )
    tran_tables (
      .selAlgo(selAlgo),
      .cur_state(state_reg),
      .next_state(next_state),
      .algo_done(algoDone),

      .count0_val(tran_tables_count0_val),
      .count0_load(tran_tables_count0_load),
      .count0_en(tran_tables_count0_en),
      .count0_done(tran_tables_count0_done),

      .count1_valSelect(tran_tables_count1_valSelect),
      .count1_load(tran_tables_count1_load),
      .count1_en(tran_tables_count1_en),
      .count1_done(tran_tables_count1_done),

      .setNetCaptureEn(tran_tables_setNetCaptureEn),
      .clrNetCaptureEn(tran_tables_clrNetCaptureEn),
      .setPicasoPtrIncr(tran_tables_setPicasoPtrIncr),
      .clrPicasoPtrIncr(tran_tables_clrPicasoPtrIncr)
    );


  // -- loop counter0: mainly used for staying in a particular state for multiple cycles
  wire [COUNT0_VAL_WIDTH-1:0] counter0_val;
  wire                        counter0_load;
  wire                        counter0_en;
  wire                        counter0_done;

  loop_counter #(
      .DEBUG(DEBUG),
      .VAL_WIDTH(COUNT0_VAL_WIDTH))  
    counter0(
      .clk(clk),
      .loadVal(counter0_val),
      .loadEn(counter0_load),
      .countEn(counter0_en),
      .val0(counter0_done),       // use the val0 to signal "counter expired"

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  // loop counter1: mainly used for running multiple iterations based on precision value
  wire                                counter1_load;      // use this signal to load counter value
  wire                                counter1_en;        // use this signal to enable countdown
  wire                                counter1_done;      // use these signal to check counter states
  wire [COUNT1_VAL_WIDTH-1:0]         counter1_val;       // this signal should only be connected to conter1 value manager module
  wire [ALGORITHM_CTR1_SEL_WIDTH-1:0] counter1_valSelect; // use this signal to select what value to load into counter1 (based on precision)

  loop_counter #(
      .DEBUG(DEBUG),
      .VAL_WIDTH(COUNT1_VAL_WIDTH))  
    counter1(
      .clk(clk),
      .loadVal(counter1_val),
      .loadEn(counter1_load),
      .countEn(counter1_en),
      .val0(counter1_done),

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  // counter1 load value manager
  _counter1_val_manager #(
      .DEBUG(DEBUG),
      .PRECISION_WIDTH(PRECISION_WIDTH),
      .INSTR_PARAM_WIDTH(INSTR_PARAM_WIDTH),
      .NET_LEVEL_WIDTH(NET_LEVEL_WIDTH),
      .VAL_WIDTH(COUNT1_VAL_WIDTH) )
    counter1_valman(
      .precision(precision),
      .param(param),
      .select(counter1_valSelect),
      .loadVal(counter1_val)       // directly connect the output of valman to counter1 input
    );


  // ---- connect the counters to the transition tables
  assign counter0_val  = tran_tables_count0_val,
         counter0_load = tran_tables_count0_load,
         counter0_en   = tran_tables_count0_en;
  assign tran_tables_count0_done = counter0_done;

  assign counter1_valSelect = tran_tables_count1_valSelect,
         counter1_load      = tran_tables_count1_load,
         counter1_en        = tran_tables_count1_en;
  assign tran_tables_count1_done = counter1_done;

  // connect transition table outputs to top-level ports
  assign setNetCaptureEn = tran_tables_setNetCaptureEn,
         clrNetCaptureEn = tran_tables_clrNetCaptureEn,
         setPicasoPtrIncr = tran_tables_setPicasoPtrIncr,
         clrPicasoPtrIncr = tran_tables_clrPicasoPtrIncr;


  // ---- Connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;    // no top-level clock enable
    end
  endgenerate


endmodule


// Auxiliary module to manage counter1 load value, simplify elaborate view.
// The transition tables can load only predefined values into counter1 based
// on the precision value. This restriction helps to reduce the size of this
// circuit.
module _counter1_val_manager #(
  parameter DEBUG = 1,
  parameter PRECISION_WIDTH = -1,
  parameter INSTR_PARAM_WIDTH = -1,
  parameter NET_LEVEL_WIDTH = -1,
  parameter VAL_WIDTH = -1
) (
  precision,    // current precision
  param,        // param field of the instruction word
  select,       // use this to select which value to load
  loadVal       // value to be loaded into the counter
);

  `include "picaso_algorithm_fsm.inc.v"

  `AK_ASSERT2(PRECISION_WIDTH > 0, PRECISION_WIDTH_not_set)
  `AK_ASSERT2(INSTR_PARAM_WIDTH >= 0, INSTR_PARAM_WIDTH_not_set)
  `AK_ASSERT2(NET_LEVEL_WIDTH > 0, NET_LEVEL_WIDTH_not_set)
  `AK_ASSERT2(VAL_WIDTH > 0, VAL_WIDTH_not_set)


  // IO ports
  input  [PRECISION_WIDTH-1:0]          precision;
  input  [INSTR_PARAM_WIDTH-1:0]        param;
  input  [ALGORITHM_CTR1_SEL_WIDTH-1:0] select;
  output reg [VAL_WIDTH-1:0]            loadVal;    // defined reg for behavioral modeling


  // selections: this is a combinatorial block
  always@* begin
    loadVal = precision >> 2;   // default value
    (* full_case, parallel_case *)
    case(select)
      // specified cases are valid selections
      ALGORITHM_CTR1_SEL_2SHR: loadVal = precision >> 2;  
      ALGORITHM_CTR1_SEL_FULL: loadVal = precision;

      ALGORITHM_CTR1_SEL_ACCUM_HEADSTART: begin: HeadStart_compute
        // This counter value is used to give the transmitter blocks a head-start.
        //   - The transmitters fills up the network with the network stream to be added at the receiver.
        //   - The head-start needed depends on the net-level and is equal to 2^level.
        //   - However, as the val0 of counter1 is used as counter-expired signal, (2^level) - 1 is loaded.
        // if (NET_LEVEL_WIDTH <= 5) Following implementation should generate (VAL_WIDTH/2) LUTs.
        //   - For VAL_WIDTH = 4, it should generate two LUT6 in 2xLUT5 mode (synthesis-verified)
        //   - This can support head-start of upto 16 (32 blocks = 512 columns = 262K 2D Array)
        reg [NET_LEVEL_WIDTH-1:0] _netLevel;
        _netLevel = param[NET_LEVEL_WIDTH-1:0];
        loadVal = (1 << _netLevel) - 1;
      end

      // default hit is invalid: simulation-time warning
      default: $display("WARN: unsupported select for counter1_val_manager only, select: b%0b (%s:%0d)  %0t", select, `__FILE__, `__LINE__, $time);
    endcase
  end


endmodule



// Auxiliary module to wrap all algorithm transition tables and multiplex
// them. This also serves as the template for all such algorithm transition
// tables. It is purely a combinatorial block.
module _algorithm_fsm_transition_tables #(
  parameter DEBUG = 1,
  parameter SEL_WIDTH = -1,
  parameter STATE_CODE_WIDTH = -1,
  parameter COUNT0_VAL_WIDTH = -1
) (
  selAlgo,        // selects one of the algorithms

  cur_state,      // current state input
  next_state,     // next state output
  algo_done,      // signals that this is the last state, next state will be INIT

  count0_val,       // value to load into counter
  count0_load,      // enable signal to load
  count0_en,        // enable counting
  count0_done,      // counter expired

  count1_valSelect, // selects counter1 load-value
  count1_load,      // enable signal to load
  count1_en,        // enable counting
  count1_done,      // counter expired

  // special signals for over-the network accumulation algorithm
  setNetCaptureEn,   // sets the netCaptureEn flip-flop
  clrNetCaptureEn,   // clears the netCaptureEn flip-flop
  setPicasoPtrIncr,  // sets the picasoPtrIncr flip-flop
  clrPicasoPtrIncr   // clears the picasoPtrIncr flip-flop
);


  `include "picaso_algorithm_fsm.inc.v"

  `AK_ASSERT2(SEL_WIDTH>0, SEL_WIDTH_not_set)
  `AK_ASSERT2(STATE_CODE_WIDTH>0, STATE_CODE_WIDTH_not_set)
  `AK_ASSERT2(COUNT0_VAL_WIDTH>0, COUNT0_VAL_WIDTH_not_set)



  // IO Ports: reg variables are assigned using behavioral code
  input  wire [SEL_WIDTH-1:0] selAlgo;

  input  wire [STATE_CODE_WIDTH-1:0] cur_state;
  output reg  [STATE_CODE_WIDTH-1:0] next_state;
  output reg                         algo_done;

  output reg  [COUNT0_VAL_WIDTH-1:0] count0_val;
  output reg                         count0_load;
  output reg                         count0_en;
  input  wire                        count0_done;

  output reg  [ALGORITHM_CTR1_SEL_WIDTH-1:0] count1_valSelect;
  output reg                                 count1_load;
  output reg                                 count1_en;
  input  wire                                count1_done;

  output reg      setNetCaptureEn;
  output reg      clrNetCaptureEn;
  output reg      setPicasoPtrIncr;
  output reg      clrPicasoPtrIncr;


  // ---- Instantiate transition tables
  // -- ALU-OP transitions
  wire [STATE_CODE_WIDTH-1:0] aluop_cur_state;
  wire [STATE_CODE_WIDTH-1:0] aluop_next_state;
  wire                        aluop_algo_done;

  wire [COUNT0_VAL_WIDTH-1:0] aluop_count0_val;
  wire                        aluop_count0_load;
  wire                        aluop_count0_en;
  wire                        aluop_count0_done;

  wire [ALGORITHM_CTR1_SEL_WIDTH-1:0] aluop_count1_valSelect;
  wire                                aluop_count1_load;
  wire                                aluop_count1_en;
  wire                                aluop_count1_done;


  transition_aluop #(
      .DEBUG(DEBUG),
      .STATE_CODE_WIDTH(STATE_CODE_WIDTH),
      .COUNT0_VAL_WIDTH(COUNT0_VAL_WIDTH) )
    aluop_table(
      .cur_state(aluop_cur_state),
      .next_state(aluop_next_state),
      .algo_done(aluop_algo_done),

      .count0_val(aluop_count0_val),
      .count0_load(aluop_count0_load),
      .count0_en(aluop_count0_en),
      .count0_done(aluop_count0_done),

      .count1_valSelect(aluop_count1_valSelect),
      .count1_load(aluop_count1_load),
      .count1_en(aluop_count1_en),
      .count1_done(aluop_count1_done)
    );


  // -- UPDATEPP transitions
  wire [STATE_CODE_WIDTH-1:0] updatepp_cur_state;
  wire [STATE_CODE_WIDTH-1:0] updatepp_next_state;
  wire                        updatepp_algo_done;

  wire [COUNT0_VAL_WIDTH-1:0] updatepp_count0_val;
  wire                        updatepp_count0_load;
  wire                        updatepp_count0_en;
  wire                        updatepp_count0_done;

  wire [ALGORITHM_CTR1_SEL_WIDTH-1:0] updatepp_count1_valSelect;
  wire                                updatepp_count1_load;
  wire                                updatepp_count1_en;
  wire                                updatepp_count1_done;


  transition_updatepp #(
      .DEBUG(DEBUG),
      .STATE_CODE_WIDTH(STATE_CODE_WIDTH),
      .COUNT0_VAL_WIDTH(COUNT0_VAL_WIDTH) )
    updatepp_table(
      .cur_state(updatepp_cur_state),
      .next_state(updatepp_next_state),
      .algo_done(updatepp_algo_done),

      .count0_val(updatepp_count0_val),
      .count0_load(updatepp_count0_load),
      .count0_en(updatepp_count0_en),
      .count0_done(updatepp_count0_done),

      .count1_valSelect(updatepp_count1_valSelect),
      .count1_load(updatepp_count1_load),
      .count1_en(updatepp_count1_en),
      .count1_done(updatepp_count1_done)
    );


  // -- Stream transitions
  wire [STATE_CODE_WIDTH-1:0] stream_cur_state;
  wire [STATE_CODE_WIDTH-1:0] stream_next_state;
  wire                        stream_algo_done;

  wire [COUNT0_VAL_WIDTH-1:0] stream_count0_val;
  wire                        stream_count0_load;
  wire                        stream_count0_en;
  wire                        stream_count0_done;

  wire [ALGORITHM_CTR1_SEL_WIDTH-1:0] stream_count1_valSelect;
  wire                                stream_count1_load;
  wire                                stream_count1_en;
  wire                                stream_count1_done;


  transition_stream #(
      .DEBUG(DEBUG),
      .STATE_CODE_WIDTH(STATE_CODE_WIDTH),
      .COUNT0_VAL_WIDTH(COUNT0_VAL_WIDTH) )
    stream_table(
      .cur_state(stream_cur_state),
      .next_state(stream_next_state),
      .algo_done(stream_algo_done),

      .count0_val(stream_count0_val),
      .count0_load(stream_count0_load),
      .count0_en(stream_count0_en),
      .count0_done(stream_count0_done),

      .count1_valSelect(stream_count1_valSelect),
      .count1_load(stream_count1_load),
      .count1_en(stream_count1_en),
      .count1_done(stream_count1_done)
    );


  // -- ACCUM-ROW transitions
  wire [STATE_CODE_WIDTH-1:0] accumrow_cur_state;
  wire [STATE_CODE_WIDTH-1:0] accumrow_next_state;
  wire                        accumrow_algo_done;

  wire [COUNT0_VAL_WIDTH-1:0]  accumrow_count0_val;
  wire                         accumrow_count0_load;
  wire                         accumrow_count0_en;
  wire                         accumrow_count0_done;

  wire [ALGORITHM_CTR1_SEL_WIDTH-1:0] accumrow_count1_valSelect;
  wire                                accumrow_count1_load;
  wire                                accumrow_count1_en;
  wire                                accumrow_count1_done;
  wire                                accumrow_setNetCaptureEn;
  wire                                accumrow_clrNetCaptureEn;
  wire                                accumrow_setPicasoPtrIncr;
  wire                                accumrow_clrPicasoPtrIncr;


  transition_accumrow #(
      .DEBUG(DEBUG),
      .STATE_CODE_WIDTH(STATE_CODE_WIDTH),
      .COUNT0_VAL_WIDTH(COUNT0_VAL_WIDTH) )
    accumrow_table(
      .cur_state(accumrow_cur_state),
      .next_state(accumrow_next_state),
      .algo_done(accumrow_algo_done),

      .count0_val(accumrow_count0_val),
      .count0_load(accumrow_count0_load),
      .count0_en(accumrow_count0_en),
      .count0_done(accumrow_count0_done),

      .count1_valSelect(accumrow_count1_valSelect),
      .count1_load(accumrow_count1_load),
      .count1_en(accumrow_count1_en),
      .count1_done(accumrow_count1_done),

      .setNetCaptureEn(accumrow_setNetCaptureEn),
      .clrNetCaptureEn(accumrow_clrNetCaptureEn),
      .setPicasoPtrIncr(accumrow_setPicasoPtrIncr),
      .clrPicasoPtrIncr(accumrow_clrPicasoPtrIncr)
    );


  // ---- connect common inputs
  assign aluop_cur_state = cur_state,
         accumrow_cur_state = cur_state,
         updatepp_cur_state = cur_state,
         stream_cur_state = cur_state;

  assign aluop_count0_done = count0_done,
         accumrow_count0_done = count0_done,
         updatepp_count0_done = count0_done,
         stream_count0_done = count0_done;

  assign aluop_count1_done = count1_done,
         accumrow_count1_done = count1_done,
         updatepp_count1_done = count1_done,
         stream_count1_done = count1_done;


  // ---- multiplex between above tables
  always@* begin
    // start with NOP
    next_state  = 0; 
    algo_done   = 0; 
    count0_val  = 0; 
    count0_load = 0; 
    count0_en   = 0; 
    count1_load = 0; 
    count1_en   = 0; 
    count1_valSelect = 0;
    setNetCaptureEn  = 0;
    clrNetCaptureEn  = 0;
    setPicasoPtrIncr = 0;
    clrPicasoPtrIncr = 0;

    // select between transition tables based on selAlgo
    (* full_case, parallel_case *)
    case(selAlgo)

      ALGORITHM_ALUOP: begin
        next_state  = aluop_next_state;
        algo_done   = aluop_algo_done;
        count0_val  = aluop_count0_val;
        count0_load = aluop_count0_load;
        count0_en   = aluop_count0_en;
        count1_load = aluop_count1_load;
        count1_en   = aluop_count1_en;
        count1_valSelect = aluop_count1_valSelect;
      end

      ALGORITHM_UPDATEPP : begin
        next_state  = updatepp_next_state;
        algo_done   = updatepp_algo_done;
        count0_val  = updatepp_count0_val;
        count0_load = updatepp_count0_load;
        count0_en   = updatepp_count0_en;
        count1_load = updatepp_count1_load;
        count1_en   = updatepp_count1_en;
        count1_valSelect = updatepp_count1_valSelect;
      end

      ALGORITHM_STREAM : begin
        next_state  = stream_next_state;
        algo_done   = stream_algo_done;
        count0_val  = stream_count0_val;
        count0_load = stream_count0_load;
        count0_en   = stream_count0_en;
        count1_load = stream_count1_load;
        count1_en   = stream_count1_en;
        count1_valSelect = stream_count1_valSelect;
      end

      ALGORITHM_ACCUMROW: begin
        next_state  = accumrow_next_state;
        algo_done   = accumrow_algo_done;
        count0_val  = accumrow_count0_val;
        count0_load = accumrow_count0_load;
        count0_en   = accumrow_count0_en;
        count1_load = accumrow_count1_load;
        count1_en   = accumrow_count1_en;
        count1_valSelect = accumrow_count1_valSelect;
        // connect special signals for over-the network accumulation algorithm
        setNetCaptureEn = accumrow_setNetCaptureEn;
        clrNetCaptureEn = accumrow_clrNetCaptureEn;
        setPicasoPtrIncr = accumrow_setPicasoPtrIncr;
        clrPicasoPtrIncr = accumrow_clrPicasoPtrIncr;
      end

      default: $display("EROR: This algorithm selection code not valid, selAlgo = %b (%0t)", selAlgo, $time);
    endcase
  end


endmodule
