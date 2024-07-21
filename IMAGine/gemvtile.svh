// Defines the parameters and datatypes for the mvtile_array module.
// This is not supposed to be reusable. This should be implemented as a package
// in the future. Include this file within a module.


`include "clogb2_func.v"
`include "boothR2_serial_alu.inc.v"
`include "alu_serial_unit.inc.v"
`include "opmux_ff.inc.v"
`include "picaso_instruction_decoder.inc.v"
`include "picaso_ff.inc.v"


// -- Parameter declarations
localparam PE_REG_WIDTH = 16,
           MAX_PRECISION = 16;

localparam  NET_STREAM_WIDTH = 1,
            MAX_NET_LEVEL    = 3,
            ID_WIDTH         = PICASO_INSTR_ID_WIDTH,
            PE_CNT           = PICASO_INSTR_DATA_WIDTH,
            RF_DEPTH         = 1024;

localparam  REGFILE_RAM_WIDTH  = PE_CNT,
            REGFILE_RAM_DEPTH  = RF_DEPTH,
            REGFILE_ADDR_WIDTH = clogb2(REGFILE_RAM_DEPTH-1);

localparam  NET_LEVEL_WIDTH = clogb2(MAX_NET_LEVEL),   // compute the no. of bits needed to represent all levels
            REG_BASE_WIDTH = PICASO_INSTR_REG_BASE_WIDTH,
            INSTR_ID_WIDTH = PICASO_INSTR_ID_WIDTH,
            SEL_MODE_WIDTH = PICASO_SEL_MODE_WIDTH;

localparam CTRL_TOKEN_WIDTH = 3,
           CTRL_INSTR_WIDTH = PICASO_INSTR_WORD_WIDTH;
localparam PE_OPERAND_WIDTH = 16;


// Structure of all control signals
typedef struct packed {
  logic [NET_LEVEL_WIDTH-1:0]        netLevel;
  logic                              netConfLoad;
  logic                              netCaptureEn;
  logic [ALU_OP_WIDTH-1:0]           aluConf;
  logic                              aluConfLoad;
  logic                              aluEn;
  logic                              aluReset;
  logic                              aluMbitReset;
  logic                              aluMbitLoad;
  logic                              opmuxConfLoad;
  logic [OPMUX_CONF_WIDTH-1:0]       opmuxConf;
  logic                              opmuxEn;
  logic                              extDataSave;
  logic [REGFILE_RAM_WIDTH-1:0]      extDataIn;
  logic                              saveAluOut;
  logic [REGFILE_ADDR_WIDTH-1:0]     addrA;
  logic [REGFILE_ADDR_WIDTH-1:0]     addrB;
  logic [ID_WIDTH-1:0]               selRow;
  logic [ID_WIDTH-1:0]               selCol;
  logic [PICASO_SEL_MODE_WIDTH-1:0]  selMode;
  logic                              selEn;
  logic                              selOp;
  logic                              ptrLoad;
  logic                              ptrIncr;
} ctrlsigs_t;
