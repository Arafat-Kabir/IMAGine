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
  Date   : Fri, Aug 25, 04:59 PM CST 2023
  Version: v1.0

  Description:
  This module defines the state codes for the algorithm FSM and then decodes
  those state codes into picaso control signals. This is a purely
  combinatorial block. Signal codes are defined in the include file for this
  module.

================================================================================*/
`timescale 1ns/100ps
`include "ak_macros.v"


module picaso_algorithm_decoder #(
  parameter DEBUG = 1,
  parameter ADDR_WIDTH = -1,       // width of PiCaSO port address
  parameter DATA_WIDTH = -1,       // width of PiCaSO data ports
  parameter NET_LEVEL_WIDTH = -1,  // width of net-level of PiCaSO's datanet-node
  parameter PICASO_ID_WIDTH = -1   // width of PiCaSO block row/column IDs
) ( 
  signalCode,            // signal code (state-code) to be decoded 

  // PiCaSO control signals
  picaso_netLevel,       // selects the current tree level
  picaso_netConfLoad,    // load network configuration
  picaso_netCaptureEn,   // enable network capture registers
  sel_netLevel_param,    // selects netLevel from top-level parameter instead of picaso_netLevel port of this module
 
  picaso_aluConf,        // configuration for ALU
  picaso_aluConfLoad,    // load operation configurations
  picaso_aluEn,          // enable ALU for computation (holds the ALU state if aluEN=0)
  picaso_aluReset,       // reset ALU state
  picaso_aluMbitReset,   // resets previous multiplier-bit storage for booth's encoding
  picaso_aluMbitLoad,    // saves (loads) multiplier-bit for booth's encoding
  sel_aluConf_param,     // selects alu-config from top-level parameter instead of picaso_aluConf

  picaso_opmuxConfLoad,  // load operation configurations
  picaso_opmuxConf,      // configuration for opmux module
  picaso_opmuxEn,        // operand-mux output register clock enable
  sel_opmuxConf_param,   // selects opmux config from top-level parameter instead of picaso_opmuxConf

  picaso_extDataSave,    // save external data into BRAM (uses addrA)

  picaso_saveAluOut,     // save the output of ALU (uses addrB)
  picaso_ptrLoad,        // loads PiCaSO local pointer value (uses addrA)
  sel_portA_ptr,         // selects the pointer for port-A
  sel_portB_ptr,         // selects the pointer for port-B
  inc_ptrA0,             // increment port-A0 pointer
  inc_ptrB0,             // increment port-B0 pointer
  inc_ptrA1,             // increment port-A1 pointer
  inc_ptrB1              // increment port-B1 pointer

  // Debug probes
);


  `AK_ASSERT(ADDR_WIDTH>0)
  `AK_ASSERT(DATA_WIDTH>0)
  `AK_ASSERT(NET_LEVEL_WIDTH>0)
  `AK_ASSERT(PICASO_ID_WIDTH>0)

  `include "picaso_algorithm_decoder.inc.v"
  `include "boothR2_serial_alu.inc.v"
  `include "alu_serial_unit.inc.v"
  `include "opmux_ff.inc.v"
  `include "picaso_ff.inc.v"

  localparam CODE_WIDTH = PICASO_ALGO_CODE_WIDTH;     // short-hand alias


  // IO Ports
  input [CODE_WIDTH-1:0] signalCode;

  // these are not real registers, they are declared reg for behavioral modeling. 
  output reg [NET_LEVEL_WIDTH-1:0]    picaso_netLevel;
  output reg                          picaso_netConfLoad;
  output reg                          picaso_netCaptureEn;
  output reg                          sel_netLevel_param;

  output reg [ALU_OP_WIDTH-1:0]       picaso_aluConf;
  output reg                          picaso_aluConfLoad;
  output reg                          picaso_aluEn;
  output reg                          picaso_aluReset;
  output reg                          picaso_aluMbitReset;
  output reg                          picaso_aluMbitLoad;
  output reg                          sel_aluConf_param;

  output reg                          picaso_opmuxConfLoad;
  output reg [OPMUX_CONF_WIDTH-1:0]   picaso_opmuxConf;
  output reg                          picaso_opmuxEn;
  output reg                          sel_opmuxConf_param;

  output reg                          picaso_extDataSave;
  output reg                          picaso_saveAluOut;
  output reg                          picaso_ptrLoad;

  output reg      sel_portA_ptr;    // selct between 2 pointers, A0, A1
  output reg      sel_portB_ptr;    // selct between 2 pointers, B0, B1
  output reg      inc_ptrA0;
  output reg      inc_ptrA1;
  output reg      inc_ptrB0;
  output reg      inc_ptrB1;


  // ---- Task definitions for composing decoder
  task all_nop;
    begin
      picaso_netLevel = 0;
      picaso_netConfLoad = 0;   // NOP
      picaso_netCaptureEn = 0;  // NOP
      sel_netLevel_param = 0;

      picaso_aluConf = 0;
      picaso_aluConfLoad = 0;   // NOP
      picaso_aluEn = 0;         // NOP
      picaso_aluReset = 0;      // NOP
      picaso_aluMbitReset = 0;  // NOP
      picaso_aluMbitLoad = 0;   // NOP
      sel_aluConf_param = 0;

      picaso_opmuxConfLoad = 0; // NOP
      picaso_opmuxConf = 0;
      picaso_opmuxEn = 0;       // NOP
      sel_opmuxConf_param = 0;

      picaso_extDataSave = 0;   // NOP
      picaso_saveAluOut = 0;    // NOP
      picaso_ptrLoad = 0;       // NOP

      sel_portA_ptr = 0;
      sel_portB_ptr = 0;
      inc_ptrA0 = 0;     // NOP   
      inc_ptrA1 = 0;     // NOP
      inc_ptrB0 = 0;     // NOP
      inc_ptrB1 = 0;     // NOP
    end
  endtask


  // sets alu reset signal
  task alu_reset;
    picaso_aluReset = 1;
  endtask


  // enables alu for computation
  task alu_enable;
   picaso_aluEn = 1;
  endtask


  // loads alu configuration from top-level parameter register
  task alu_loadConf_param;
    begin
      picaso_aluConfLoad = 1;
      sel_aluConf_param  = 1;
      picaso_aluMbitLoad = 1;   // loads the prevMbit register, whether that'll be used depends on the instruction
    end
  endtask


  // loads opmux configuration from top-level parameter register
  task opmux_loadConf_param;
    begin
      picaso_opmuxConfLoad = 1;
      sel_opmuxConf_param = 1;    // load from top-level parameter register
    end
  endtask


  // loads opmux configuration A_OP_B
  task opmux_loadConf_AopB;
    begin
      picaso_opmuxConf = OPMUX_A_OP_B;
      picaso_opmuxConfLoad = 1;
      sel_opmuxConf_param = 0;    // load from signal decoder (this module)
    end
  endtask


  // reads both ports of the bram and increments the pointers, uses A0 and B0.
  // also, keeps opmux enabled.
  task bram_read_inc;
    begin
      sel_portA_ptr = 0;
      sel_portB_ptr = 0;
      inc_ptrA0 = 1;
      inc_ptrB0 = 1;
      picaso_opmuxEn = 1;
    end
  endtask


  // This task provides and abstraction for reading multiplier bit(s).
  // The implementation may change based on how the multiplier bits are used.
  // Here the assumption is that ptrA1 points to the multiplier bit that needs to be read.
  task bram_multRead;
    begin
      sel_portA_ptr = 1;
      picaso_opmuxEn = 1;
    end
  endtask


  // writes the alu output to BRAM and increments the pointer, uses B1.
  // also, keeps opmux enabled.
  task bram_aluWrite_inc;
    begin
      sel_portB_ptr = 1;
      picaso_saveAluOut = 1;
      picaso_opmuxEn = 1;
      inc_ptrB1 = 1;
    end
  endtask


  // reads from BRAM using ptr-A0, then increments.
  // writes the alu output to BRAM and increments the pointer, uses B1.
  // also, keeps opmux enabled.
  task bram_aluStreamWrite_inc;
    begin
      sel_portA_ptr = 0;
      sel_portB_ptr = 1;
      picaso_saveAluOut = 1;
      picaso_opmuxEn = 1;
      inc_ptrA0 = 1;
      inc_ptrB1 = 1;
    end
  endtask


  // loads the network-level from the top-level parameter register
  task net_loadLevel;
    begin
      picaso_netConfLoad = 1;
      sel_netLevel_param = 1;
    end
  endtask


  // loads picaso local pointer with ptr-A1 value
  task ptr_loadVal;
    begin
      sel_portA_ptr = 1;
      picaso_ptrLoad = 1;
    end
  endtask




  // Signal decoding table
  always@* begin
    // start with reasonable default value: (NOP)
    all_nop;
    picaso_opmuxConf = OPMUX_A_OP_0;    // This must be the default opmuxConf for NOP

    (* full_case = "yes", parallel_case = "yes" *)
    case(signalCode)
      // ALU-OP algorithm signals
      PICASO_ALGO_aluRst_opmxLoadParam_bRead: begin
        alu_reset;
        opmux_loadConf_param;
        bram_read_inc;
      end

      PICASO_ALGO_aluLoadParam_bRead: begin
        alu_loadConf_param;
        bram_read_inc;
      end

      PICASO_ALGO_aluEn_bRead: begin
        alu_enable;
        bram_read_inc;
      end

      PICASO_ALGO_bWrite: begin
        alu_enable;
        bram_aluWrite_inc;
      end

      PICASO_ALGO_aluDis_bWrite   : bram_aluWrite_inc;
      PICASO_ALGO_aluDis_bWrite_1 : bram_aluWrite_inc;
      PICASO_ALGO_bRead_0         : bram_read_inc;
      PICASO_ALGO_bRead_1         : bram_read_inc;

      // UPDATEPP algorithm signals (some states will be reused from above in the transition table)
      PICASO_ALGO_aluRst_opmxAopB_multRead: begin
        alu_reset;
        opmux_loadConf_AopB;
        bram_multRead;
      end

      PICASO_ALGO_opmxLoadParam_bRead: begin
        opmux_loadConf_param;
        bram_read_inc;
      end

      // Stream algorithm signals (some states will be reused from above in the transition table)
      PICASO_ALGO_bStreamWrite: begin
        alu_enable;
        bram_aluStreamWrite_inc;
      end

      // ACCUM-ROW algorithm signals (some states will be reused from above in the transition table)
      PICASO_ALGO_accumRow_setup: begin
        net_loadLevel;
        ptr_loadVal;
      end

      PICASO_ALGO_accumRow_headstart: begin
        // network capture register is enabled by variable manager.
        // picaso local pointer-increment is enabled by variable manager.
        //; // no other signal needs to be asserted here, transition table takes care of the rest.
      end

      // default to NOP
      PICASO_ALGO_NOP: ;    // initial values are NOP
      default: ;            // initial values are NOP
    endcase
  end


  // Following block is for simulation only
  initial begin
    all_nop;    // this is correct at time 0 because the initial state should correspond to NOP
    picaso_opmuxConf = OPMUX_A_OP_0;    // This must be the default opmuxConf for NOP
  end


endmodule

