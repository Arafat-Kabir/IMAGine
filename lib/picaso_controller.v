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
  Date  : Wed, Aug 09, 05:08 PM CST 2023

  Description:
  This module provides an instruction word-based control interface to an array
  of PiCaSO blocks. For details, checkout doc/PiCaSO-Controller-Design.md

  Version: v1.0

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module picaso_controller #(
  parameter DEBUG = 1,
  parameter INSTRUCTION_WIDTH = -1,  // this is only used to cross-verify the instruction word width
  parameter NET_LEVEL_WIDTH = 3,     // width of net-level of PiCaSO's datanet-node
  parameter OPERAND_WIDTH = 16,      // width of bit-serial operands
  parameter PICASO_ID_WIDTH = 8,     // width of PiCaSO block row/column IDs
  parameter TOKEN_WIDTH = 2,         // width of sequencing tokens
  parameter PE_REG_WIDTH = 16,       // width of the PE registers
  parameter MAX_PRECISION = 16       // largest precision to support
) (
  clk,
  instruction,           // instruction word
  token_in,              // input token for sequencing streaming instructions (needed to work with shift network)
  inputValid,            // Single-bit input signal, 1: other input signals are valid, 0: other input signals not valid (this is needed to work with shift networks)
  token_out,             // output token for sequencing streaming output
  busy,                  // Single-bit output signal, 1: the controller is busy executing last instruction
  nextInstr,             // Requesting next instruction (used in the front-end interface)

  // PiCaSO control signals
  picaso_netLevel,       // selects the current tree level
  picaso_netConfLoad,    // load network configuration
  picaso_netCaptureEn,   // enable network capture registers
 
  picaso_aluConf,        // configuration for ALU
  picaso_aluConfLoad,    // load operation configurations
  picaso_aluEn,          // enable ALU for computation (holds the ALU state if aluEN=0)
  picaso_aluReset,       // reset ALU state
  picaso_aluMbitReset,   // resets previous multiplier-bit storage for booth's encoding
  picaso_aluMbitLoad,    // saves (loads) multiplier-bit for booth's encoding

  picaso_opmuxConfLoad,  // load operation configurations
  picaso_opmuxConf,      // configuration for opmux module
  picaso_opmuxEn,        // operand-mux output register clock enable

  picaso_extDataSave,    // save external data into BRAM (uses addrA)
  picaso_extDataIn,      // external data input port of PiCaSO

  picaso_saveAluOut,     // save the output of ALU (uses addrB)
  picaso_addrA,          // address of operand A
  picaso_addrB,          // address of operand B

  picaso_selRow,         // currently selected row ID
  picaso_selCol,         // currently selected column ID
  picaso_selMode,        // selection mode
  picaso_selEn,          // selection reg clock enable
  picaso_selOp,          // activate selection-based operations

  picaso_ptrLoad,        // load local pointer value (uses port-A address)
  picaso_ptrIncr,        // enable local pointer increment

  // Debug probes
  dbg_clk_enable         // debug clock for stepping
);


  `include "opmux_ff.inc.v"
  `include "boothR2_serial_alu.inc.v"
  `include "alu_serial_unit.inc.v"
  `include "picaso_controller.inc.v"
  `include "picaso_algorithm_fsm.inc.v"
  `include "picaso_ff.inc.v"
  `include "picaso_instruction_decoder.inc.v"
  `include "clogb2_func.v"

  // Check if module parameters are consistent with include file parameters
  `AK_ASSERT(INSTRUCTION_WIDTH == PICASO_INSTR_WORD_WIDTH)
  `AK_ASSERT(PICASO_ID_WIDTH == PICASO_INSTR_ID_WIDTH)


  //localparam INSTR_WIDTH = PICASO_INSTR_WORD_WIDTH;

  // remove scope prefix for short-hand
  localparam OPCODE_WIDTH = PICASO_INSTR_OPCODE_WIDTH,
             FN_WIDTH = PICASO_INSTR_FN_WIDTH,
             ADDR_WIDTH = PICASO_INSTR_ADDR_WIDTH,
             DATA_WIDTH = PICASO_INSTR_DATA_WIDTH,
             OFFSET_WIDTH = PICASO_INSTR_OFFSET_WIDTH,
             REG_BASE_WIDTH = PICASO_INSTR_REG_BASE_WIDTH,
             INSTR_PARAM_WIDTH = PICASO_INSTR_PARAM_WIDTH,
             SCODE_WIDTH = PICASO_INSTR_SCODE_WIDTH;


  // IO ports
  input                           clk; 
  input  [INSTRUCTION_WIDTH-1:0]  instruction;
  input  [TOKEN_WIDTH-1:0]        token_in;
  input                           inputValid;
  output [TOKEN_WIDTH-1:0]        token_out;
  output                          busy;
  output                          nextInstr;

  output [NET_LEVEL_WIDTH-1:0]    picaso_netLevel;
  output                          picaso_netConfLoad;
  output                          picaso_netCaptureEn;

  output [ALU_OP_WIDTH-1:0]       picaso_aluConf;
  output                          picaso_aluConfLoad;
  output                          picaso_aluEn;
  output                          picaso_aluReset;
  output                          picaso_aluMbitReset;
  output                          picaso_aluMbitLoad;

  output                          picaso_opmuxConfLoad;
  output [OPMUX_CONF_WIDTH-1:0]   picaso_opmuxConf;
  output                          picaso_opmuxEn;

  output                          picaso_extDataSave;
  output [DATA_WIDTH-1:0]         picaso_extDataIn;

  output                          picaso_saveAluOut;
  output [ADDR_WIDTH-1:0]         picaso_addrA;
  output [ADDR_WIDTH-1:0]         picaso_addrB;

  output [PICASO_ID_WIDTH-1:0]       picaso_selRow;
  output [PICASO_ID_WIDTH-1:0]       picaso_selCol;
  output [PICASO_SEL_MODE_WIDTH-1:0] picaso_selMode;
  output                             picaso_selEn;
  output                             picaso_selOp;

  output                             picaso_ptrLoad;
  output                             picaso_ptrIncr;

  // Debug probes
  input   dbg_clk_enable;


  // internal signals
  wire local_ce;    // for module-level clock-enable (isn't passed to submodules)


  // ---- instruction storage
  (* extract_enable = "yes" *)
  reg  [INSTRUCTION_WIDTH-1:0]  instruction_reg = PICASO_NOP;    // to hold the instruction word (initially set to NOP)

  // instruction_reg behavior
  always @(posedge clk) begin
    if(local_ce) begin
      if(inputValid) instruction_reg <= instruction;    // record the instruction word when inputValid signal is set
      else instruction_reg <= instruction_reg;          // otherwise, hold the value
    end else begin
      instruction_reg <= instruction_reg;   // hold the state
    end
  end


  // ---- precision storage register
  localparam PRECISION_REG_WIDTH = clogb2(MAX_PRECISION),
             DEFAULT_PRECISION = 16;        // used to test modules without precision control support
             

  (* extract_enable = "yes" *)
  reg  [PRECISION_REG_WIDTH-1:0] precision_reg = DEFAULT_PRECISION;   // holds the precision for arithmetic operations (runtime configurable)
  wire [PRECISION_REG_WIDTH-1:0] precision_val;     // use this signal to specify precision value to load
  wire                           precision_load;    // use this signal to load precision value

  // instruction_reg behavior
  always @(posedge clk) begin
    if(local_ce && precision_load) begin
      if(precision_load) precision_reg <= precision_val;    // load the precision value if requested
    end else begin
      precision_reg <= precision_reg;    // hold the state
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

  
  // ---- instruction decoder module to separate instruction word fields (fld)
  wire [OPCODE_WIDTH-1:0]         fld_opcode;
  wire [ADDR_WIDTH-1:0]           fld_addr;
  wire [DATA_WIDTH-1:0]           fld_data;
  wire [REG_BASE_WIDTH-1:0]       fld_rd, fld_rs1, fld_rs2;
  wire [PICASO_ID_WIDTH-1:0]      fld_rowID, fld_colID;
  wire [FN_WIDTH-1:0]             fld_fncode;
  wire [SCODE_WIDTH-1:0]          fld_sCode;
  wire [OFFSET_WIDTH-1:0]         fld_offset;
  wire [INSTR_PARAM_WIDTH-1:0]    fld_param;

  wire [ALGORITHM_SEL_WIDTH-1:0]  pre_algoselCode;         // pre-decoded algorithm selection code
  wire [PICASO_INSTR_TYPE_CODE_WIDTH-1:0] pre_instrType;   // pre-decoded instruction type code
  wire [ADDR_WIDTH-1:0]  pre_rs1_base;
  wire [ADDR_WIDTH-1:0]  pre_rs2_base;
  wire [ADDR_WIDTH-1:0]  pre_rd_base;
  wire [ADDR_WIDTH-1:0]  pre_rd_with_offset;
  wire [ADDR_WIDTH-1:0]  pre_rs1_with_offset;
  wire [ADDR_WIDTH-1:0]  pre_rs2_with_offset;
  wire [ADDR_WIDTH-1:0]  pre_rs1_with_param;
  wire [ADDR_WIDTH-1:0]  pre_rs2_with_param;
  wire [ADDR_WIDTH-1:0]  pre_rd_with_param;

  picaso_instruction_decoder #(
      .DEBUG(DEBUG),
      .WORD_WIDTH(INSTRUCTION_WIDTH),
      .PE_REG_WIDTH(PE_REG_WIDTH))
    instr_decoder (
      .clk(clk),
      .instruction_word(instruction_reg),
      .opcode(fld_opcode),
      .addr(fld_addr),
      .data(fld_data),
      .offset(fld_offset),
      .rs1(fld_rs1),
      .rs2(fld_rs2),
      .rd(fld_rd),
      .rowID(fld_rowID),
      .colID(fld_colID),
      .fn(fld_fncode),
      .sCode(fld_sCode),
      .param(fld_param),
      // pre-decoded signals
      .algoselCode(pre_algoselCode),
      .instrType(pre_instrType),
      .rs1_base(pre_rs1_base),
      .rs2_base(pre_rs2_base),
      .rd_base(pre_rd_base),
      .rd_with_offset(pre_rd_with_offset),
      .rs1_with_offset(pre_rs1_with_offset),
      .rs2_with_offset(pre_rs2_with_offset),
      .rs1_with_param(pre_rs1_with_param),
      .rs2_with_param(pre_rs2_with_param),
      .rd_with_param(pre_rd_with_param)
    );


  // ---- Pipeline stage at the level of the instruction decoder (stage A in FCCM-2024 draft05)
  // pipelined signals
  (* extract_enable = "yes" *)
  reg inputValid_pipe = 0;

  // pipeline
  always @(posedge clk) begin
    if(local_ce) begin
      // record new values
      inputValid_pipe <= inputValid;
    end else begin
      // hold the state
      inputValid_pipe <= inputValid_pipe;
    end
  end


  // ---- front-end instruction fetch-decode FSM
  wire                           instr_fsm_instrValid;
  wire                           instr_fsm_algoDone;
  wire [ALGORITHM_SEL_WIDTH-1:0] instr_fsm_algoselCode;
  wire [PICASO_INSTR_TYPE_CODE_WIDTH-1:0] instr_fsm_instrType;

  wire                           instr_fsm_selCtrlSet;
  wire [ALGORITHM_SEL_WIDTH-1:0] instr_fsm_selAlgo;
  wire                           instr_fsm_enAlgo;
  wire                           instr_fsm_saveAlgoParam;
  wire                           instr_fsm_clearInstr;
  wire                           instr_fsm_busy;

  picaso_instruction_fsm #(
      .DEBUG(DEBUG),
      .OPCODE_WIDTH(OPCODE_WIDTH),
      .FN_WIDTH(FN_WIDTH) )
    instr_fsm (
      .clk(clk),
      .instrValid(instr_fsm_instrValid),
      .algoDone(instr_fsm_algoDone),
      .algoselCode(instr_fsm_algoselCode),
      .instrType(instr_fsm_instrType),
      
      .selCtrlSet(instr_fsm_selCtrlSet),
      .selAlgo(instr_fsm_selAlgo),
      .enAlgo(instr_fsm_enAlgo),
      .saveAlgoParam(instr_fsm_saveAlgoParam),
      .clearInstr(instr_fsm_clearInstr),
      .busy(instr_fsm_busy),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)   // pass the debug stepper clock
    );


  // ---- front-end instruction flow control signal
  wire getNextInstr;

  _picaso_controller_getNextInstr #(
      .INSTR_TYPE_WIDTH(PICASO_INSTR_TYPE_CODE_WIDTH))
    getNextInstr_logic (
      .instr_fsm_busy(instr_fsm_busy),
      .inputValid_pipe(inputValid_pipe),
      .instr_valid(instr_valid),
      .instrType(pre_instrType),
      .getNextInstr(getNextInstr)
    );


  // ---- single-cycle instruction driver
  wire [OPCODE_WIDTH-1:0]      singcycle_opcode;
  wire [ADDR_WIDTH-1:0]        singcycle_addr;
  wire [DATA_WIDTH-1:0]        singcycle_data;
  wire [REG_BASE_WIDTH-1:0]    singcycle_rd;
  wire [REG_BASE_WIDTH-1:0]    singcycle_rs1;
  wire [REG_BASE_WIDTH-1:0]    singcycle_rs2;
  wire [PICASO_ID_WIDTH-1:0]   singcycle_rowID; 
  wire [PICASO_ID_WIDTH-1:0]   singcycle_colID;
  wire [FN_WIDTH-1:0]          singcycle_fncode;
  wire [SCODE_WIDTH-1:0]       singcycle_sCode;
  wire [OFFSET_WIDTH-1:0]      singcycle_offset;
  wire [INSTR_PARAM_WIDTH-1:0] singcycle_param;

  wire [NET_LEVEL_WIDTH-1:0]   singcycle_netLevel;
  wire                         singcycle_netConfLoad;
  wire                         singcycle_netCaptureEn;

  wire [ALU_OP_WIDTH-1:0]      singcycle_aluConf;
  wire                         singcycle_aluConfLoad;
  wire                         singcycle_aluEn;
  wire                         singcycle_aluReset;
  wire                         singcycle_aluMbitReset;
  wire                         singcycle_aluMbitLoad;

  wire                         singcycle_opmuxConfLoad;
  wire [OPMUX_CONF_WIDTH-1:0]  singcycle_opmuxConf;
  wire                         singcycle_opmuxEn;

  wire                         singcycle_extDataSave;
  wire [DATA_WIDTH-1:0]        singcycle_extDataIn;

  wire                         singcycle_saveAluOut;
  wire [ADDR_WIDTH-1:0]        singcycle_addrA;
  wire [ADDR_WIDTH-1:0]        singcycle_addrB;
  wire                         singcycle_ptrLoad;
  wire                         singcycle_ptrIncr;

  wire [PICASO_ID_WIDTH-1:0]       singcycle_selRow;
  wire [PICASO_ID_WIDTH-1:0]       singcycle_selCol;
  wire [PICASO_SEL_MODE_WIDTH-1:0] singcycle_selMode;
  wire                             singcycle_selEn;
  wire                             singcycle_selOp;

  picaso_singlecycle_driver #(
      .DEBUG(DEBUG),
      .OPCODE_WIDTH(OPCODE_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .REG_BASE_WIDTH(REG_BASE_WIDTH),
      .PICASO_ID_WIDTH(PICASO_ID_WIDTH),
      .FN_WIDTH(FN_WIDTH),
      .OFFSET_WIDTH(OFFSET_WIDTH),
      .INSTR_PARAM_WIDTH(INSTR_PARAM_WIDTH),
      .NET_LEVEL_WIDTH(NET_LEVEL_WIDTH) )
    singlecycle_driver (
      .opcode(singcycle_opcode),
      .addr(singcycle_addr),
      .data(singcycle_data),
      .rd(singcycle_rd), 
      .rs1(singcycle_rs1),
      .rs2(singcycle_rs2), 
      .rowID(singcycle_rowID), 
      .colID(singcycle_colID),
      .fncode(singcycle_fncode),
      .sCode(singcycle_sCode),
      .offset(singcycle_offset),
      .param(singcycle_param),

      .sigNetLevel(singcycle_netLevel),
      .sigNetConfLoad(singcycle_netConfLoad),
      .sigNetCaptureEn(singcycle_netCaptureEn),
      .sigAluConf(singcycle_aluConf),
      .sigAluConfLoad(singcycle_aluConfLoad),
      .sigAluEn(singcycle_aluEn),
      .sigAluReset(singcycle_aluReset),
      .sigAluMbitReset(singcycle_aluMbitReset),
      .sigAluMbitLoad(singcycle_aluMbitLoad),
      .sigOpmuxConfLoad(singcycle_opmuxConfLoad),
      .sigOpmuxConf(singcycle_opmuxConf),
      .sigOpmuxEn(singcycle_opmuxEn),
      .sigExtDataSave(singcycle_extDataSave),
      .sigExtDataIn(singcycle_extDataIn),
      .sigSaveAluOut(singcycle_saveAluOut),
      .sigAddrA(singcycle_addrA),
      .sigAddrB(singcycle_addrB),
      .sigPtrLoad(singcycle_ptrLoad),
      .sigPtrIncr(singcycle_ptrIncr),
      .sigSelRow(singcycle_selRow),
      .sigSelCol(singcycle_selCol),
      .sigSelMode(singcycle_selMode),
      .sigSelEn(singcycle_selEn),
      .sigSelOp(singcycle_selOp)
    );


  // ---- multi-cycle instruction driver
  wire                           multcycle_enTransition;
  wire [ALGORITHM_SEL_WIDTH-1:0] multcycle_selAlgo;
  wire                           multcycle_loadInit;
  wire [PRECISION_REG_WIDTH-1:0] multcycle_precision;
  wire                           multcycle_algoDone;

  wire [OPCODE_WIDTH-1:0]        multcycle_opcode;
  wire [ADDR_WIDTH-1:0]          multcycle_addr;
  wire [DATA_WIDTH-1:0]          multcycle_data;
  wire [REG_BASE_WIDTH-1:0]      multcycle_rd;
  wire [REG_BASE_WIDTH-1:0]      multcycle_rs1;
  wire [REG_BASE_WIDTH-1:0]      multcycle_rs2;
  wire [PICASO_ID_WIDTH-1:0]     multcycle_rowID; 
  wire [PICASO_ID_WIDTH-1:0]     multcycle_colID;
  wire [FN_WIDTH-1:0]            multcycle_fncode;
  wire [OFFSET_WIDTH-1:0]        multcycle_offset;
  wire [INSTR_PARAM_WIDTH-1:0]   multcycle_param;

  wire [ADDR_WIDTH-1:0]          multcycle_rs1_base;
  wire [ADDR_WIDTH-1:0]          multcycle_rs2_base;
  wire [ADDR_WIDTH-1:0]          multcycle_rd_base;
  wire [ADDR_WIDTH-1:0]          multcycle_rd_with_offset;
  wire [ADDR_WIDTH-1:0]          multcycle_rs1_with_offset;
  wire [ADDR_WIDTH-1:0]          multcycle_rs2_with_offset;
  wire [ADDR_WIDTH-1:0]          multcycle_rs1_with_param;
  wire [ADDR_WIDTH-1:0]          multcycle_rs2_with_param;
  wire [ADDR_WIDTH-1:0]          multcycle_rd_with_param;

  wire [NET_LEVEL_WIDTH-1:0]     multcycle_netLevel;
  wire                           multcycle_netConfLoad;
  wire                           multcycle_netCaptureEn;

  wire [ALU_OP_WIDTH-1:0]        multcycle_aluConf;
  wire                           multcycle_aluConfLoad;
  wire                           multcycle_aluEn;
  wire                           multcycle_aluReset;
  wire                           multcycle_aluMbitReset;
  wire                           multcycle_aluMbitLoad;

  wire                           multcycle_opmuxConfLoad;
  wire [OPMUX_CONF_WIDTH-1:0]    multcycle_opmuxConf;
  wire                           multcycle_opmuxEn;

  wire                           multcycle_extDataSave;
  wire [DATA_WIDTH-1:0]          multcycle_extDataIn;

  wire                           multcycle_saveAluOut;
  wire [ADDR_WIDTH-1:0]          multcycle_addrA;
  wire [ADDR_WIDTH-1:0]          multcycle_addrB;
  wire                           multcycle_ptrLoad;
  wire                           multcycle_ptrIncr;

  wire [PICASO_ID_WIDTH-1:0]       multcycle_selRow;
  wire [PICASO_ID_WIDTH-1:0]       multcycle_selCol;
  wire [PICASO_SEL_MODE_WIDTH-1:0] multcycle_selMode;
  wire                             multcycle_selEn;
  wire                             multcycle_selOp;

  picaso_multicycle_driver #(
      .DEBUG(DEBUG),
      .OPCODE_WIDTH(OPCODE_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .REG_BASE_WIDTH(REG_BASE_WIDTH),
      .PICASO_ID_WIDTH(PICASO_ID_WIDTH),
      .FN_WIDTH(FN_WIDTH),
      .OFFSET_WIDTH(OFFSET_WIDTH),
      .INSTR_PARAM_WIDTH(INSTR_PARAM_WIDTH),
      .NET_LEVEL_WIDTH(NET_LEVEL_WIDTH),
      .PE_REG_WIDTH(PE_REG_WIDTH),
      .PRECISION_WIDTH(PRECISION_REG_WIDTH) )
    multicycle_driver (
      .clk(clk),
      .enTransition(multcycle_enTransition),
      .selAlgo(multcycle_selAlgo),
      .loadInit(multcycle_loadInit),
      .precision(multcycle_precision),
      .algoDone(multcycle_algoDone),

      .opcode(multcycle_opcode),
      .addr(multcycle_addr),
      .data(multcycle_data),
      .rd(multcycle_rd), 
      .rs1(multcycle_rs1),
      .rs2(multcycle_rs2), 
      .rowID(multcycle_rowID), 
      .colID(multcycle_colID),
      .fncode(multcycle_fncode),
      .offset(multcycle_offset),
      .param(multcycle_param),

      .rs1_base(multcycle_rs1_base),
      .rs2_base(multcycle_rs2_base),
      .rd_base(multcycle_rd_base),
      .rd_with_offset(multcycle_rd_with_offset),
      .rs1_with_offset(multcycle_rs1_with_offset),
      .rs2_with_offset(multcycle_rs2_with_offset),
      .rs1_with_param(multcycle_rs1_with_param),
      .rs2_with_param(multcycle_rs2_with_param),
      .rd_with_param(multcycle_rd_with_param),

      .sigNetLevel(multcycle_netLevel),
      .sigNetConfLoad(multcycle_netConfLoad),
      .sigNetCaptureEn(multcycle_netCaptureEn),
      .sigAluConf(multcycle_aluConf),
      .sigAluConfLoad(multcycle_aluConfLoad),
      .sigAluEn(multcycle_aluEn),
      .sigAluReset(multcycle_aluReset),
      .sigAluMbitReset(multcycle_aluMbitReset),
      .sigAluMbitLoad(multcycle_aluMbitLoad),
      .sigOpmuxConfLoad(multcycle_opmuxConfLoad),
      .sigOpmuxConf(multcycle_opmuxConf),
      .sigOpmuxEn(multcycle_opmuxEn),
      .sigExtDataSave(multcycle_extDataSave),
      .sigExtDataIn(multcycle_extDataIn),
      .sigSaveAluOut(multcycle_saveAluOut),
      .sigAddrA(multcycle_addrA),
      .sigAddrB(multcycle_addrB),
      .sigPtrLoad(multcycle_ptrLoad),
      .sigPtrIncr(multcycle_ptrIncr),
      .sigSelRow(multcycle_selRow),
      .sigSelCol(multcycle_selCol),
      .sigSelMode(multcycle_selMode),
      .sigSelEn(multcycle_selEn),
      .sigSelOp(multcycle_selOp),

      .dbg_clk_enable(dbg_clk_enable)
    );




  // ---- instantiating output muxed register and directly connecting signals
  _picaso_controller_outmux #(
      .DEBUG(DEBUG),
      .NET_LEVEL_WIDTH(NET_LEVEL_WIDTH),
      .ALU_OP_WIDTH(ALU_OP_WIDTH),
      .OPMUX_CONF_WIDTH(OPMUX_CONF_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH),
      .PICASO_ID_WIDTH(PICASO_ID_WIDTH),
      .PICASO_SEL_MODE_WIDTH(PICASO_SEL_MODE_WIDTH))
    outmux (
      .clk(clk),
      .local_ce(local_ce),
      .select(instr_fsm_selCtrlSet),

      .sing_netLevel(singcycle_netLevel),
      .mult_netLevel(multcycle_netLevel),
      .out_netLevel(picaso_netLevel),

      .sing_netConfLoad(singcycle_netConfLoad),
      .mult_netConfLoad(multcycle_netConfLoad),
      .out_netConfLoad(picaso_netConfLoad),

      .sing_netCaptureEn(singcycle_netCaptureEn),
      .mult_netCaptureEn(multcycle_netCaptureEn),
      .out_netCaptureEn(picaso_netCaptureEn),

      .sing_aluConf(singcycle_aluConf),
      .mult_aluConf(multcycle_aluConf),
      .out_aluConf(picaso_aluConf),

      .sing_aluConfLoad(singcycle_aluConfLoad),
      .mult_aluConfLoad(multcycle_aluConfLoad),
      .out_aluConfLoad(picaso_aluConfLoad),

      .sing_aluEn(singcycle_aluEn),
      .mult_aluEn(multcycle_aluEn),
      .out_aluEn(picaso_aluEn),

      .sing_aluReset(singcycle_aluReset),
      .mult_aluReset(multcycle_aluReset),
      .out_aluReset(picaso_aluReset),

      .sing_aluMbitReset(singcycle_aluMbitReset),
      .mult_aluMbitReset(multcycle_aluMbitReset),
      .out_aluMbitReset(picaso_aluMbitReset),

      .sing_aluMbitLoad(singcycle_aluMbitLoad),
      .mult_aluMbitLoad(multcycle_aluMbitLoad),
      .out_aluMbitLoad(picaso_aluMbitLoad),

      .sing_opmuxConfLoad(singcycle_opmuxConfLoad),
      .mult_opmuxConfLoad(multcycle_opmuxConfLoad),
      .out_opmuxConfLoad(picaso_opmuxConfLoad),

      .sing_opmuxConf(singcycle_opmuxConf),
      .mult_opmuxConf(multcycle_opmuxConf),
      .out_opmuxConf(picaso_opmuxConf),

      .sing_opmuxEn(singcycle_opmuxEn),
      .mult_opmuxEn(multcycle_opmuxEn),
      .out_opmuxEn(picaso_opmuxEn),

      .sing_extDataSave(singcycle_extDataSave),
      .mult_extDataSave(multcycle_extDataSave),
      .out_extDataSave(picaso_extDataSave),

      .sing_extDataIn(singcycle_extDataIn),
      .mult_extDataIn(multcycle_extDataIn),
      .out_extDataIn(picaso_extDataIn),

      .sing_saveAluOut(singcycle_saveAluOut),
      .mult_saveAluOut(multcycle_saveAluOut),
      .out_saveAluOut(picaso_saveAluOut),

      .sing_addrA(singcycle_addrA),
      .mult_addrA(multcycle_addrA),
      .out_addrA(picaso_addrA),

      .sing_addrB(singcycle_addrB),
      .mult_addrB(multcycle_addrB),
      .out_addrB(picaso_addrB),

      .sing_selRow(singcycle_selRow),
      .mult_selRow(multcycle_selRow),
      .out_selRow(picaso_selRow),

      .sing_selCol(singcycle_selCol),
      .mult_selCol(multcycle_selCol),
      .out_selCol(picaso_selCol),

      .sing_selMode(singcycle_selMode),
      .mult_selMode(multcycle_selMode),
      .out_selMode(picaso_selMode),

      .sing_selEn(singcycle_selEn),
      .mult_selEn(multcycle_selEn),
      .out_selEn(picaso_selEn),

      .sing_selOp(singcycle_selOp),
      .mult_selOp(multcycle_selOp),
      .out_selOp(picaso_selOp),

      .sing_ptrLoad(singcycle_ptrLoad),
      .mult_ptrLoad(multcycle_ptrLoad),
      .out_ptrLoad(picaso_ptrLoad),

      .sing_ptrIncr(singcycle_ptrIncr),
      .mult_ptrIncr(multcycle_ptrIncr),
      .out_ptrIncr(picaso_ptrIncr)
    );



  // ---- Local Interconnect: Connecting Signals and Modules ----
  /* NOTE:
  *   - All ports of instantiated modules are connected to a wire defined near the instantiation code
  *   - The names of module-specific signals has the format: <instance_name>_<portName>
  *   - Only some obvious connections are made at the instantiation, e.g: clk, dbg_clk_enable, etc.
  *   - Connections between those instances are made in this section.
  *   - Connections are grouped by module inputs, i.e. l_values of the assign
  *     statements belong to the same instance.
  *   - This approach separates the instantiation and interconnection and keeps
  *     most of the signals near  where they are used.
  */

  //  inputs of instr_valid_ff
  assign instr_valid_ff_set   = inputValid_pipe;
  assign instr_valid_ff_clear = instr_fsm_clearInstr;

  // inputs of instr_fsm
  assign instr_fsm_instrValid = instr_valid;
  assign instr_fsm_algoDone = multcycle_algoDone;
  assign instr_fsm_algoselCode = pre_algoselCode;
  assign instr_fsm_instrType = pre_instrType;

  // inputs of single-cycle driver connects to the outputs of the instruction decoder
  assign singcycle_opcode = fld_opcode,
         singcycle_addr = fld_addr,
         singcycle_data = fld_data,
         singcycle_rd = fld_rd, 
         singcycle_rs1 = fld_rs1, 
         singcycle_rs2 = fld_rs2, 
         singcycle_rowID = fld_rowID, 
         singcycle_colID = fld_colID,
         singcycle_fncode = fld_fncode,
         singcycle_sCode = fld_sCode,
         singcycle_offset = fld_offset,
         singcycle_param = fld_param;

  // inputs of multi-cycle driver
  // instruction fields
  assign multcycle_opcode = fld_opcode,
         multcycle_addr = fld_addr,
         multcycle_data = fld_data,
         multcycle_rd = fld_rd, 
         multcycle_rs1 = fld_rs1, 
         multcycle_rs2 = fld_rs2, 
         multcycle_rowID = fld_rowID, 
         multcycle_colID = fld_colID,
         multcycle_fncode = fld_fncode,
         multcycle_offset = fld_offset,
         multcycle_param = fld_param;
  // pre-decoded signals
  assign multcycle_rs1_base = pre_rs1_base,
         multcycle_rs2_base = pre_rs2_base,
         multcycle_rd_base = pre_rd_base,
         multcycle_rd_with_offset = pre_rd_with_offset,
         multcycle_rs1_with_offset = pre_rs1_with_offset,
         multcycle_rs2_with_offset = pre_rs2_with_offset,
         multcycle_rs1_with_param = pre_rs1_with_param,
         multcycle_rs2_with_param = pre_rs2_with_param,
         multcycle_rd_with_param = pre_rd_with_param;
  // control signals from instruction-fsm
  assign multcycle_enTransition = instr_fsm_enAlgo,
         multcycle_selAlgo      = instr_fsm_selAlgo,
         multcycle_loadInit     = instr_fsm_saveAlgoParam;
  assign multcycle_precision    = precision_reg;

  // module outputs
  assign busy = instr_fsm_busy,
         nextInstr = getNextInstr;


  // ---- connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1;   // there is no top-level clock enable control
    end
  endgenerate


endmodule



// Auxiliary module used to generate instruction request.
// This is a combinatorial block
module _picaso_controller_getNextInstr #(
  parameter INSTR_TYPE_WIDTH = -1
) (
  instr_fsm_busy,
  inputValid_pipe,
  instr_valid,
  instrType,
  getNextInstr
);


  `include "picaso_instruction_decoder.inc.v"

  `AK_ASSERT(INSTR_TYPE_WIDTH > 0)

  // Module IO
  input                          instr_fsm_busy;
  input                          inputValid_pipe;
  input                          instr_valid;
  input  [INSTR_TYPE_WIDTH-1:0]  instrType;
  output reg                     getNextInstr = 1;  // initially, we want instruction


  always@* begin
    getNextInstr = 1'b0;     // default value
    if(!instr_fsm_busy) begin
      // current instr_valid level instruction will be consumed on next posedge
      if(!inputValid_pipe && !instr_valid)     getNextInstr = 1'b1;   // instruction pipeline empty
      else if(inputValid_pipe && !instr_valid) getNextInstr = 1'b1;   // inputValid_pipe instruction will be consumed by the time the newer instruction arrives as instr_valid-level registers
      else if(!inputValid_pipe && instr_valid) getNextInstr = 1'b1;   // current instruction will definitely be consumed
      else if(inputValid_pipe && instr_valid) begin
        if(instrType == INSTR_TYPE_SINGLE_CYCLE) getNextInstr = 1'b1;   // I know that instr_fsm will be ready to consume the instruction at inputValid_pipe level
      end
    end else begin
      // instr_fsm is busy, we need to be careful with our request
      if(!inputValid_pipe && !instr_valid) getNextInstr = 1'b1;  // there is nothing in the pipeline, and we can save 1 instruction
    end
  end


endmodule




// Auxiliary module used for output muxing between single-cycle and multi-cycle drivers
module _picaso_controller_outmux #(
  parameter DEBUG = 1,
  parameter NET_LEVEL_WIDTH = -1,
  parameter ALU_OP_WIDTH = -1,
  parameter OPMUX_CONF_WIDTH = -1,
  parameter DATA_WIDTH = -1,
  parameter ADDR_WIDTH = -1,
  parameter PICASO_ID_WIDTH = -1,
  parameter PICASO_SEL_MODE_WIDTH = -1
) (
  clk,
  local_ce,     // for debugging only
  select,       // 0: single-cycle, 1: multi-cycle

  // single-cycle inputs
  sing_addrA,
  sing_addrB,
  sing_aluConf,
  sing_aluConfLoad,
  sing_aluEn,
  sing_aluReset,
  sing_aluMbitReset,
  sing_aluMbitLoad,
  sing_extDataIn,
  sing_extDataSave,
  sing_netCaptureEn,
  sing_netConfLoad,
  sing_netLevel,
  sing_opmuxConf,
  sing_opmuxConfLoad,
  sing_opmuxEn,
  sing_saveAluOut,
  sing_selRow,
  sing_selCol,
  sing_selEn,
  sing_selMode,
  sing_selOp,
  sing_ptrLoad,
  sing_ptrIncr,

  // multi-cycle inputs
  mult_addrA,
  mult_addrB,
  mult_aluConf,
  mult_aluConfLoad,
  mult_aluEn,
  mult_aluReset,
  mult_aluMbitReset,
  mult_aluMbitLoad,
  mult_extDataIn,
  mult_extDataSave,
  mult_netCaptureEn,
  mult_netConfLoad,
  mult_netLevel,
  mult_opmuxConf,
  mult_opmuxConfLoad,
  mult_opmuxEn,
  mult_saveAluOut,
  mult_selCol,
  mult_selEn,
  mult_selMode,
  mult_selOp,
  mult_selRow,
  mult_ptrLoad,
  mult_ptrIncr,

  // output control signals
  out_addrA,
  out_addrB,
  out_aluConf,
  out_aluConfLoad,
  out_aluEn,
  out_aluReset,
  out_aluMbitReset,
  out_aluMbitLoad,
  out_extDataIn,
  out_extDataSave,
  out_netCaptureEn,
  out_netConfLoad,
  out_netLevel,
  out_opmuxConf,
  out_opmuxConfLoad,
  out_opmuxEn,
  out_saveAluOut,
  out_selCol,
  out_selEn,
  out_selMode,
  out_selOp,
  out_selRow,
  out_ptrLoad,
  out_ptrIncr
);

  `include "picaso_controller.inc.v"

  // IO ports: output regs are initialized to 0 at FPGA reset
  input clk, local_ce;
  input select;

  input  wire [NET_LEVEL_WIDTH-1:0]       sing_netLevel;
  input  wire [NET_LEVEL_WIDTH-1:0]       mult_netLevel;
  output reg  [NET_LEVEL_WIDTH-1:0]       out_netLevel = 0;

  input wire                              sing_netConfLoad;
  input wire                              mult_netConfLoad;
  output reg                              out_netConfLoad = 0;

  input wire                              sing_netCaptureEn;
  input wire                              mult_netCaptureEn;
  output reg                              out_netCaptureEn = 0;

  input wire [ALU_OP_WIDTH-1:0]           sing_aluConf;
  input wire [ALU_OP_WIDTH-1:0]           mult_aluConf;
  output reg [ALU_OP_WIDTH-1:0]           out_aluConf = 0;

  input wire                              sing_aluConfLoad;
  input wire                              mult_aluConfLoad;
  output reg                              out_aluConfLoad = 0;

  input wire                              sing_aluEn;
  input wire                              mult_aluEn;
  output reg                              out_aluEn = 0;

  input wire                              sing_aluReset;
  input wire                              mult_aluReset;
  output reg                              out_aluReset = 0;

  input wire                              sing_aluMbitReset;
  input wire                              mult_aluMbitReset;
  output reg                              out_aluMbitReset = 0;

  input wire                              sing_aluMbitLoad;
  input wire                              mult_aluMbitLoad;
  output reg                              out_aluMbitLoad = 0;

  input wire                              sing_opmuxConfLoad;
  input wire                              mult_opmuxConfLoad;
  output reg                              out_opmuxConfLoad = 0;

  input wire [OPMUX_CONF_WIDTH-1:0]       sing_opmuxConf;
  input wire [OPMUX_CONF_WIDTH-1:0]       mult_opmuxConf;
  output reg [OPMUX_CONF_WIDTH-1:0]       out_opmuxConf = 0;

  input wire                              sing_opmuxEn;
  input wire                              mult_opmuxEn;
  output reg                              out_opmuxEn = 0;

  input wire                              sing_extDataSave;
  input wire                              mult_extDataSave;
  output reg                              out_extDataSave = 0;

  input wire [DATA_WIDTH-1:0]             sing_extDataIn;
  input wire [DATA_WIDTH-1:0]             mult_extDataIn;
  output reg [DATA_WIDTH-1:0]             out_extDataIn = 0;

  input wire                              sing_saveAluOut;
  input wire                              mult_saveAluOut;
  output reg                              out_saveAluOut = 0;

  input wire [ADDR_WIDTH-1:0]             sing_addrA;
  input wire [ADDR_WIDTH-1:0]             mult_addrA;
  output reg [ADDR_WIDTH-1:0]             out_addrA = 0;

  input wire [ADDR_WIDTH-1:0]             sing_addrB;
  input wire [ADDR_WIDTH-1:0]             mult_addrB;
  output reg [ADDR_WIDTH-1:0]             out_addrB = 0;

  input wire [PICASO_ID_WIDTH-1:0]        sing_selRow;
  input wire [PICASO_ID_WIDTH-1:0]        mult_selRow;
  output reg [PICASO_ID_WIDTH-1:0]        out_selRow = 0;

  input wire [PICASO_ID_WIDTH-1:0]        sing_selCol;
  input wire [PICASO_ID_WIDTH-1:0]        mult_selCol;
  output reg [PICASO_ID_WIDTH-1:0]        out_selCol = 0;

  input wire [PICASO_SEL_MODE_WIDTH-1:0]  sing_selMode;
  input wire [PICASO_SEL_MODE_WIDTH-1:0]  mult_selMode;
  output reg [PICASO_SEL_MODE_WIDTH-1:0]  out_selMode = 0;

  input wire                              sing_selEn;
  input wire                              mult_selEn;
  output reg                              out_selEn = 0;

  input wire                              sing_selOp;
  input wire                              mult_selOp;
  output reg                              out_selOp = 0;

  input wire                              sing_ptrLoad;
  input wire                              mult_ptrLoad;
  output reg                              out_ptrLoad = 0;

  input wire                              sing_ptrIncr;
  input wire                              mult_ptrIncr;
  output reg                              out_ptrIncr = 0;

  // muxing and output register logic
  always@(posedge clk) begin
    if(local_ce) begin       // local_ce for debugging
      if(select == PICASO_CTRL_SEL_DECODE_SIGNALS) begin
        // select single-cycle signals
        out_netLevel <= sing_netLevel;
        out_netConfLoad <= sing_netConfLoad;
        out_netCaptureEn <= sing_netCaptureEn;
        out_aluConf <= sing_aluConf;
        out_aluConfLoad <= sing_aluConfLoad;
        out_aluEn <= sing_aluEn;
        out_aluReset <= sing_aluReset;
        out_aluMbitReset <= sing_aluMbitReset;
        out_aluMbitLoad <= sing_aluMbitLoad;
        out_opmuxConfLoad <= sing_opmuxConfLoad;
        out_opmuxConf <= sing_opmuxConf;
        out_opmuxEn <= sing_opmuxEn;
        out_extDataSave <= sing_extDataSave;
        out_extDataIn <= sing_extDataIn;
        out_saveAluOut <= sing_saveAluOut;
        out_addrA <= sing_addrA;
        out_addrB <= sing_addrB;
        out_selRow <= sing_selRow;
        out_selCol <= sing_selCol;
        out_selMode <= sing_selMode;
        out_selEn <= sing_selEn;
        out_selOp <= sing_selOp;
        out_ptrLoad <= sing_ptrLoad;
        out_ptrIncr <= sing_ptrIncr;

      end else begin
        // select multi-cycle signals
        out_netLevel <= mult_netLevel;
        out_netConfLoad <= mult_netConfLoad;
        out_netCaptureEn <= mult_netCaptureEn;
        out_aluConf <= mult_aluConf;
        out_aluConfLoad <= mult_aluConfLoad;
        out_aluEn <= mult_aluEn;
        out_aluReset <= mult_aluReset;
        out_aluMbitReset <= mult_aluMbitReset;
        out_aluMbitLoad <= mult_aluMbitLoad;
        out_opmuxConfLoad <= mult_opmuxConfLoad;
        out_opmuxConf <= mult_opmuxConf;
        out_opmuxEn <= mult_opmuxEn;
        out_extDataSave <= mult_extDataSave;
        out_extDataIn <= mult_extDataIn;
        out_saveAluOut <= mult_saveAluOut;
        out_addrA <= mult_addrA;
        out_addrB <= mult_addrB;
        out_selRow <= mult_selRow;
        out_selCol <= mult_selCol;
        out_selMode <= mult_selMode;
        out_selEn <= mult_selEn;
        out_selOp <= mult_selOp;
        out_ptrLoad <= mult_ptrLoad;
        out_ptrIncr <= mult_ptrIncr;
      end
    end
  end


endmodule

