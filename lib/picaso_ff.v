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
  Date  : Wed, Jul 19, 05:48 PM CST 2023

  Description: 
  The Compute block (Processing Block) for the bit-serial SPAR.

================================================================================*/


`timescale 1ns/100ps
`include "ak_macros.v"


module picaso_ff #(
  parameter DEBUG = 1,
  parameter NET_STREAM_WIDTH = 1,    // width of the East-to-West movement stream
  parameter MAX_NET_LEVEL    = 8,    // how many levels of the binary tree to support (PE-node count = 2**MAX_LEVEL)
  parameter ID_WIDTH         = 8,    // width of the row/colum IDs
  parameter CB_ROW_ID        = -1,   // row-ID of the compute-block (must initialize with a non-negative number of ID_WIDTH size)
  parameter CB_COL_ID        = -1,   // column-ID of the compute-block
  parameter PE_CNT           = 16,   // Number of Processing-Elements in each block
  parameter RF_DEPTH         = 1024  // Depth of the register-file (usually it's equal to register-width * register-count)
) (
  clk,

  netLevel,       // selects the current tree level
  netConfLoad,    // load network configuration
  netCaptureEn,   // enable network capture registers
 
  eastIn,         // input stream from east
  westOut,        // output stream to west

  aluConf,        // configuration for ALU
  aluConfLoad,    // load operation configurations
  aluEn,          // enable ALU for computation (holds the ALU state if aluEN=0)
  aluReset,       // reset ALU state
  aluMbitReset,   // resets previous multiplier-bit storage for booth's encoding
  aluMbitLoad,    // saves (loads) multiplier-bit for booth's encoding

  opmuxConfLoad,  // load operation configurations
  opmuxConf,      // configuration for opmux module
  opmuxEn,        // operand-mux output register clock enable

  extDataSave,    // save external data into BRAM (uses addrA)
  extDataIn,      // external data input port
  extDataOut,     // external data output port

  saveAluOut,     // save the output of ALU (uses addrB)
  addrA,          // address of operand A
  addrB,          // address of operand B

  selRow,        // currently selected row ID
  selCol,        // currently selected column ID
  selMode,       // current selection mode: row, column, both, encode
  selEn,         // set the clock-enable of the selection register (value is set based on row, col, and mode)
  selOp,         // 1: perform op if selected, 0: perform op irrespective of selRow/selCol. NOTE: Only specific operations can be performed selectively.
  selActive,     // if this block is currently selected (active selection)

  ptrLoad,       // load local pointer value (uses port-A address)
  ptrIncr,       // enable local pointer increment

  serialOut,         // serial output port
  serialOutValid,   // indicates if the serial output is valid

  // Debug probes
  dbg_clk_enable,     // debug clock for stepping

  dbg_rf_wea,
  dbg_rf_web,
  dbg_rf_dia,
  dbg_rf_dib,
  dbg_rf_doa,
  dbg_rf_dob,
  dbg_rf_addra,
  dbg_rf_addrb,

  dbg_opmux_opnX,
  dbg_opmux_opnY,

  dbg_alu_x_streams,
  dbg_alu_y_streams,
  dbg_alu_out_streams,

  dbg_net_localIn,
  dbg_net_captureOut
);


  // ---- Design assumptions
  `AK_ASSERT(NET_STREAM_WIDTH == 1)
  // Row and Column IDs must be non-negative and fit withing ID_WIDTH
  `AK_ASSERT(CB_ROW_ID >= 0)
  `AK_ASSERT(CB_COL_ID >= 0)
  `AK_ASSERT(CB_ROW_ID < (1<<ID_WIDTH))
  `AK_ASSERT(CB_COL_ID < (1<<ID_WIDTH))


  `include "clogb2_func.v"
  `include "boothR2_serial_alu.inc.v"
  `include "alu_serial_unit.inc.v"
  `include "opmux_ff.inc.v"
  `include "picaso_ff.inc.v"


  // This constant is used to conditionally make "untouched" internal debug probes
  localparam dbg_yn = DEBUG ? "yes" : "no";   // internal debug probes becomes "dont_touch" if DEBUG==True


  // Local parameter declarations for IO ports and submodules
  localparam REGFILE_RAM_WIDTH  = PE_CNT,
             REGFILE_RAM_DEPTH  = RF_DEPTH,
             REGFILE_ADDR_WIDTH = clogb2(REGFILE_RAM_DEPTH-1);

  localparam NET_LEVEL_WIDTH = clogb2(MAX_NET_LEVEL-1);   // compute the no. of bits needed to represent all levels
  localparam SEL_MODE_WIDTH  = PICASO_SEL_MODE_WIDTH;


  // IO ports
  input  wire  clk; 

  input  [NET_LEVEL_WIDTH-1:0]  netLevel;
  input                         netConfLoad;
  input                         netCaptureEn;

  input  [NET_STREAM_WIDTH-1:0] eastIn;
  output [NET_STREAM_WIDTH-1:0] westOut;

  input  [ALU_OP_WIDTH-1:0]     aluConf;
  input                         aluConfLoad;
  input                         aluEn;
  input                         aluReset;
  input                         aluMbitReset;
  input                         aluMbitLoad;

  input                         opmuxConfLoad;
  input  [OPMUX_CONF_WIDTH-1:0] opmuxConf;
  input                         opmuxEn;

  input                           extDataSave;
  input  [REGFILE_RAM_WIDTH-1:0]  extDataIn; 
  output [REGFILE_RAM_WIDTH-1:0]  extDataOut;

  input                           saveAluOut;
  input  [REGFILE_ADDR_WIDTH-1:0] addrA;    
  input  [REGFILE_ADDR_WIDTH-1:0] addrB;   

  input  [ID_WIDTH-1:0]       selRow;
  input  [ID_WIDTH-1:0]       selCol;
  input  [SEL_MODE_WIDTH-1:0] selMode;
  input                       selEn;
  input                       selOp;
  output                      selActive;

  input                       ptrLoad;
  input                       ptrIncr;

  output                      serialOut;
  output                      serialOutValid;


  // Debug probes
                            input                           dbg_clk_enable;
  (* mark_debug = dbg_yn *) output                          dbg_rf_wea, dbg_rf_web;
  (* mark_debug = dbg_yn *) output [REGFILE_RAM_WIDTH-1:0]  dbg_rf_dia, dbg_rf_dib;
  (* mark_debug = dbg_yn *) output [REGFILE_RAM_WIDTH-1:0]  dbg_rf_doa, dbg_rf_dob;
  (* mark_debug = dbg_yn *) output [REGFILE_ADDR_WIDTH-1:0] dbg_rf_addra, dbg_rf_addrb;
  (* mark_debug = dbg_yn *) output [REGFILE_RAM_WIDTH-1:0]  dbg_opmux_opnX, dbg_opmux_opnY;
  (* mark_debug = dbg_yn *) output [REGFILE_RAM_WIDTH-1:0]  dbg_alu_x_streams, dbg_alu_y_streams, dbg_alu_out_streams;
  (* mark_debug = dbg_yn *) output [NET_STREAM_WIDTH-1:0]   dbg_net_localIn, dbg_net_captureOut;




  // ---- Module Instantiation ----
  /* NOTE:   
  *   - Modules are instantiated independently
  *   - Each module has wires connected to them with a prefix same as their names
  *   - These wires will be connected together at a later section
  *   - This helps with easier management of the source file
  */


  // Register-File
  wire                             regfile_wea, regfile_web;
  wire  [REGFILE_ADDR_WIDTH-1:0]   regfile_addra, regfile_addrb;
  wire  [REGFILE_RAM_WIDTH-1 :0]   regfile_dia, regfile_dib;
  wire  [REGFILE_RAM_WIDTH-1 :0]   regfile_doa, regfile_dob;

  bram_wrfirst_ff #(
      .DEBUG(DEBUG),
      .RAM_WIDTH(REGFILE_RAM_WIDTH),
      .RAM_DEPTH(REGFILE_RAM_DEPTH)  )  
    regfile (
      .clk(clk),
      .wea(regfile_wea),
      .web(regfile_web),
      .addra(regfile_addra),
      .addrb(regfile_addrb),
      .dia(regfile_dia),
      .dib(regfile_dib),
      .doa(regfile_doa),
      .dob(regfile_dob)
    );


  // Operand-Multiplexer
  localparam OPMUX_OPN_WIDTH = REGFILE_RAM_WIDTH;

  wire  [OPMUX_OPN_WIDTH-1:0]   opMux_rf_portA;
  wire  [OPMUX_OPN_WIDTH-1:0]   opMux_rf_portB;
  wire  [NET_STREAM_WIDTH-1:0]  opMux_net_stream;
  wire  [OPMUX_CONF_WIDTH-1:0]  opMux_confSig;
  wire                          opMux_confLoad;
  wire                          opMux_ceOut;
  wire  [OPMUX_OPN_WIDTH-1:0]   opMux_opnX;
  wire  [OPMUX_OPN_WIDTH-1:0]   opMux_opnY;

  (* dont_touch = dbg_yn *) wire  [OPMUX_CONF_WIDTH-1:0]  dbg_opMux_conf_reg;
  (* dont_touch = dbg_yn *) wire  [OPMUX_OPN_WIDTH-1:0]   dbg_opMux_opnX_reg_in;
  (* dont_touch = dbg_yn *) wire  [OPMUX_OPN_WIDTH-1:0]   dbg_opMux_opnY_reg_in;

  opmux_ff #(
      .DEBUG(DEBUG),
      .RF_STREAM_WIDTH(REGFILE_RAM_WIDTH),
      .NET_STREAM_WIDTH(NET_STREAM_WIDTH) )
    opMux (
      .clk(clk),
      .rf_portA(opMux_rf_portA),
      .rf_portB(opMux_rf_portB),
      .net_stream(opMux_net_stream),
      .confSig(opMux_confSig),
      .confLoad(opMux_confLoad),
      .ceOut(opMux_ceOut),
      .opnX(opMux_opnX),
      .opnY(opMux_opnY),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable),
      .dbg_conf_reg(dbg_opMux_conf_reg),
      .dbg_opnX_reg_in(dbg_opMux_opnX_reg_in),
      .dbg_opnY_reg_in(dbg_opMux_opnY_reg_in)
    );


  // Bit-Serial ALU
  localparam ALU_STREAM_WIDTH = OPMUX_OPN_WIDTH;

  wire                         aluInst_reset;
  wire [ALU_STREAM_WIDTH-1:0]  aluInst_x_streams;
  wire [ALU_STREAM_WIDTH-1:0]  aluInst_y_streams;
  wire                         aluInst_ce_alu;
  wire [ALU_OP_WIDTH-1:0]      aluInst_opConfig;
  wire                         aluInst_opLoad;
  wire                         aluInst_resetMbit;
  wire                         aluInst_loadMbit;
  wire [ALU_STREAM_WIDTH-1:0]  aluInst_out_streams;

  (* dont_touch = dbg_yn *) wire [ALU_STREAM_WIDTH-1:0]  dbg_aluInst_out_reg;
  (* dont_touch = dbg_yn *) wire [ALU_STREAM_WIDTH-1:0]  dbg_aluInst_out_reg_in;


  alu_serial_ff #(
      .DEBUG(DEBUG),
      .STREAM_WIDTH(ALU_STREAM_WIDTH) )
    aluInst (
      .clk(clk),
      .reset(aluInst_reset),
      .x_streams(aluInst_x_streams),
      .y_streams(aluInst_y_streams),
      .ce_alu(aluInst_ce_alu),
      .opConfig(aluInst_opConfig),
      .opLoad(aluInst_opLoad),
      .resetMbit(aluInst_resetMbit),
      .loadMbit(aluInst_loadMbit),
      .out_streams(aluInst_out_streams),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable),
      .dbg_out_reg(dbg_aluInst_out_reg),
      .dbg_out_reg_in(dbg_aluInst_out_reg_in)
    );


  // Network module
  wire [NET_STREAM_WIDTH-1:0]  netnode_localIn;
  wire [NET_STREAM_WIDTH-1:0]  netnode_captureOut;
  wire [NET_STREAM_WIDTH-1:0]  netnode_eastIn;
  wire [NET_STREAM_WIDTH-1:0]  netnode_westOut;
  wire [NET_LEVEL_WIDTH-1:0]   netnode_level;
  wire                         netnode_confLoad;
  wire                         netnode_captureEn;
  wire                         netnode_isReceiver;

  (* dont_touch = dbg_yn *) wire [NET_LEVEL_WIDTH-1:0]   dbg_netnode_level_reg;
  (* dont_touch = dbg_yn *) wire [NET_STREAM_WIDTH-1:0]  dbg_netnode_capture_reg;
  (* dont_touch = dbg_yn *) wire                         dbg_netnode_txSelect;   // transmitter selects between localIn or eastIn (capture register)

  datanet_node #(
      .DEBUG(DEBUG),
      .EW_STREAM_WIDTH(NET_STREAM_WIDTH),
      .MAX_LEVEL(MAX_NET_LEVEL),
      .ID_WIDTH(ID_WIDTH),
      .ROW_ID(CB_ROW_ID),
      .COL_ID(CB_COL_ID) )
    netnode (
      .clk(clk),
      .localIn(netnode_localIn),
      .captureOut(netnode_captureOut),
      .eastIn(netnode_eastIn),
      .westOut(netnode_westOut),
      .level(netnode_level),
      .confLoad(netnode_confLoad),
      .captureEn(netnode_captureEn),
      .isReceiver(netnode_isReceiver),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable),
      .dbg_level_reg(dbg_netnode_level_reg),
      .dbg_capture_reg(dbg_netnode_capture_reg),
      .dbg_txSelect(dbg_netnode_txSelect)
    );


  // Block selector: directly connected to input ports (delegation)
  wire selection_state;   // read this signal to know current selection state

  picaso_selector #(
    .DEBUG(DEBUG),
    .ID_WIDTH(ID_WIDTH),
    .SEL_MODE_WIDTH(SEL_MODE_WIDTH),
    .ROW_ID(CB_ROW_ID),
    .COL_ID(CB_COL_ID) )
    selector (
      .clk(clk),
      .row(selRow),
      .col(selCol),
      .mode(selMode),
      .selEn(selEn),
      .state(selection_state),

      // debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  // Address pointer: up-counter as a localized address pointer
  wire [REGFILE_ADDR_WIDTH-1:0] pointer_loadVal;
  wire                          pointer_loadEn;
  wire                          pointer_countEn;
  wire [REGFILE_ADDR_WIDTH-1:0] pointer_countOut;

  up_counter #(
      .DEBUG(DEBUG),
      .VAL_WIDTH(REGFILE_ADDR_WIDTH) )    // pointer width is equal to BRAM address width
    pointer(
      .clk(clk),
      .loadVal(pointer_loadVal),
      .loadEn(pointer_loadEn),
      .countEn(pointer_countEn),
      .countOut(pointer_countOut),

      // Debug probes
      .dbg_clk_enable(dbg_clk_enable)
    );


  // Transmitter detection logic for array-level accumulation
  //   - This signal is needed to decide the inputs to the addrA port of the registerfile.
  //   - A block should transmit using the local-pointer, whenever the network is
  //     enabled (netCaptureEn) and it's not a receiver.
  //   - Transmissions from passthrough blocks will be ignored by the network.
  //   - Receivers will use the address from the top-level addrA port.
  wire doTransmit;
  assign doTransmit = netCaptureEn && (!netnode_isReceiver);


  // Serial output registers: The last bit written to the registerfile of PE-0
  // is written to the serial output registers.
  (* extract_enable = "yes" *)
  reg  serialData_reg  = 0,    // register to hold serial output
       serialValid_reg = 0;    // register to hold serialOutValid signal

  always@(posedge clk) begin
    serialData_reg  <= regfile_dib[0];    // PE-0 input data
    serialValid_reg <= regfile_web;       // PE-0 write-enable signal corresponds to the valid data written
  end



  // ---- Local Interconnect: Connecting Modules ----
  /* NOTE:
  *   - Connections are grouped by modules and top-level ports
  *   - In a connection-group, only input ports are connected
  *   - Output ports of one module are input to other modules, 
  *     or top-level output port
  */

  // Registerfile input port connections
  assign regfile_addra = doTransmit ? pointer_countOut : addrA;     // use local pointer in transmitter mode
  assign regfile_addrb = addrB;
  assign regfile_dia = extDataIn;
  assign regfile_dib = aluInst_out_streams;
  // Alu output is saved using port-B. Here is how the regfile_web is controlled,
  //   - if network capture operation is not performed, regfile_web is directly controlled by saveAluOut.
  //   - if network capture is enabled, transmitters don't write alu output.
  assign regfile_web = doTransmit ? 0 : saveAluOut;
  // External data uses port-A. Here is how the selection logic works for regfile_wea,
  //   - If selective operation not requested, regfile_wea is directly controlled by extDataSave.
  //   - if selective operation requested, regfile_wea will be set by extDataSave if the selection register is set.
  assign regfile_wea = (selOp == 0) ? extDataSave : extDataSave && selection_state;

  // opMux input port connections
  assign opMux_rf_portA = regfile_doa;    // registerfile to opmux streams
  assign opMux_rf_portB = regfile_dob;
  assign opMux_net_stream = netnode_captureOut;  // network node to opmux streams
  assign opMux_confSig = opmuxConf;              // top-level control signals
  assign opMux_confLoad = opmuxConfLoad;
  assign opMux_ceOut = opmuxEn;  

  // aluInst input port connections
  assign aluInst_reset = aluReset;
  assign aluInst_x_streams = opMux_opnX;    // opMux to alu streams
  assign aluInst_y_streams = opMux_opnY;
  assign aluInst_ce_alu = aluEn;
  assign aluInst_opConfig = aluConf;
  assign aluInst_opLoad = aluConfLoad;
  assign aluInst_resetMbit = aluMbitReset;
  assign aluInst_loadMbit = aluMbitLoad;

  // datanode input port connections
  assign netnode_localIn = regfile_doa[0 +: NET_STREAM_WIDTH];  // can stream out data using port-A, while saving alu outstream using port-B.
  assign netnode_eastIn = eastIn;
  assign netnode_level = netLevel;
  assign netnode_confLoad = netConfLoad;
  assign netnode_captureEn = netCaptureEn;

  // pointer input port connections
  assign pointer_loadVal = addrA;     // port-A address is directly connected to the pointer load-value
  assign pointer_loadEn  = ptrLoad;
  assign pointer_countEn = ptrIncr;

  // top-level output ports
  assign westOut = netnode_westOut;
  assign extDataOut = regfile_doa;     // external data uses port-A
  assign selActive = selection_state;  // output the selection state of this block
  assign serialOut = serialData_reg;
  assign serialOutValid = serialValid_reg;




  // connect debug probes
  generate
    if(DEBUG) begin
      assign dbg_rf_wea = regfile_wea;
      assign dbg_rf_web = regfile_web;
      assign dbg_rf_dia = regfile_dia;
      assign dbg_rf_dib = regfile_dib;
      assign dbg_rf_doa = regfile_doa;
      assign dbg_rf_dob = regfile_dob;
      assign dbg_rf_addra = addrA;
      assign dbg_rf_addrb = addrB;

      assign dbg_opmux_opnX = opMux_opnX;
      assign dbg_opmux_opnY = opMux_opnY;

      assign dbg_alu_x_streams = aluInst_x_streams;
      assign dbg_alu_y_streams = aluInst_y_streams;
      assign dbg_alu_out_streams = aluInst_out_streams;

      assign dbg_net_localIn = netnode_localIn;
      assign dbg_net_captureOut = netnode_captureOut;
    end else begin
      // nothing to do here
    end
  endgenerate


endmodule



// Implements the picaso block selection logic.
// Acts as a register.
module picaso_selector #(
  parameter DEBUG = 1,
  parameter ID_WIDTH = 8,         // width of the row/colum IDs
  parameter SEL_MODE_WIDTH = -1,  // width of selection mode (mode input port)
  parameter ROW_ID = -1,          // row-ID of the parent block
  parameter COL_ID = -1           // column-ID of the prent block
) (
  clk, 
  row,     // selection row ID
  col,     // selection column ID
  mode,    // selection mode: row, column, block, encode
  selEn,   // set the clock-enable of the selection register (value is set based on row, col, and mode)
  state,   // current selection state

  // Debug probes
  dbg_clk_enable     // debug clock for stepping
);

  `include "picaso_ff.inc.v"

  `AK_ASSERT(ROW_ID >= 0)
  `AK_ASSERT(COL_ID >= 0)
  `AK_ASSERT(SEL_MODE_WIDTH >= 0)

  // IO ports
  input  wire  clk; 

  input  [ID_WIDTH-1:0]       row;
  input  [ID_WIDTH-1:0]       col;
  input  [SEL_MODE_WIDTH-1:0] mode;
  input                       selEn;
  output                      state;

  // Debug probes
  input dbg_clk_enable;

  // internal wires
  wire local_ce;    // for debugging


  // Selection Register
  (* extract_enable = "yes" *)
  reg  selected_reg = 1;    // register to hold selection state (selected by default)
  wire selected_inp;        // input to the register

  // selection register behavior
  always@(posedge clk) begin
    if(local_ce & selEn) selected_reg <= selected_inp;    // save the decoded selection if selEN set (local_ce for debug support)
    else selected_reg <= selected_reg;    // otherwise, hold the old state
  end


  // block selection decoder: set the selection based on selection row, col, and mode
  function automatic fn_select_block;
    input [ID_WIDTH-1:0] _row, _col;
    input [1:0] _mode;

    begin
      fn_select_block = 0;    // initial value
      (* full_case, parallel_case *)
      case (_mode)
        PICASO_SEL_COL  : fn_select_block = (_col == COL_ID);      // selects entire column
        PICASO_SEL_BLOCK: fn_select_block = (_col == COL_ID) && (_row == ROW_ID); // selects a specific block
        PICASO_SEL_ROW  : fn_select_block = (_row == ROW_ID);      // selects entire row
        PICASO_SEL_ENC  : begin
          // AK-NOTE: For the time being, only encoding supported is select-all
          //          irrespective of the encoding to save logic utiliztion. 
          //          However, this should correspond to encoding = 0.
          fn_select_block = 1'b1;   // selects all blocks
        end
        default: $display("EROR: invalid _mode: %b (%s:%0d)  %0t", _mode, `__FILE__, `__LINE__, $time);
      endcase
    end
  endfunction

  assign selected_inp = fn_select_block(row, col, mode);   // input to selection register is the decoder output 
  assign state = selected_reg;    // connect state register to the output port


  // connect debug probes
  generate
    if(DEBUG) begin
      assign local_ce = dbg_clk_enable;
    end else begin
      assign local_ce = 1'b1;   // local debug clock is always enabled if not in DEBUG mode
    end
  endgenerate


endmodule
