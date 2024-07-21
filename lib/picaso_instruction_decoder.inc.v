// instruction decoder is the implementation of the instruction format. So,
// this module decides the value of these parameters. Other modules are
// responsible to adhere to these values.
localparam PICASO_INSTR_OPCODE_WIDTH = 4,     // width of the OpCode field
           PICASO_INSTR_FN_WIDTH = 2,         // width of the Fn field (part of ADDR)
           PICASO_INSTR_ADDR_WIDTH = 10,      // width of the ADDR field
           PICASO_INSTR_DATA_WIDTH = 16,      // width of the DATA field
           PICASO_INSTR_OFFSET_WIDTH = 4,     // width of the offset field (needed for UPDATE-PP instruction)
           PICASO_INSTR_REG_BASE_WIDTH = 6,   // width of the register base addresses
           PICASO_INSTR_PARAM_WIDTH = 4,      // width of param field, used as net-level, opmux-Conf, alu-Conf, etc.
           PICASO_INSTR_ID_WIDTH = 8,         // width of PiCaSO block row/column IDs
           PICASO_INSTR_SCODE_WIDTH = 3;      // width of the S_CODE field


/* PiCaSO controller instruction word is made of 3 segments: [SEG2] [SEG1] [SEG0]
*  The segments are used as follows,
*    SEG0:  DATA, {RS2, RS1}, {xx, R}, {ROW-ID, COL-ID}
*    SEG1:  ADDR, {OFFSET, RD}, {FN, RD}, {FN, xx}, {FN, PARAM}
*    SEG2:  OPCODE
*/
`include "ak_macros.v"

// ensuring correct with for SEG0
`define SEG0_WIDTH  PICASO_INSTR_DATA_WIDTH                 // ensures DATA can fit in SEG0
`AK_ASSERT(`SEG0_WIDTH >= (2*PICASO_INSTR_REG_BASE_WIDTH))   // ensures {RS2, RS1}, {xx, R} can fit in SEG0
`AK_ASSERT(`SEG0_WIDTH >= (2*PICASO_INSTR_ID_WIDTH))         // ensures {ROW-ID, COL-ID} can fit in SEG0

// determining the width of SEG1
`define OFF_RD_WIDTH   (PICASO_INSTR_OFFSET_WIDTH + PICASO_INSTR_REG_BASE_WIDTH)
`define FN_RD_WIDTH    (PICASO_INSTR_FN_WIDTH + PICASO_INSTR_REG_BASE_WIDTH)
`define FN_PARAM_WIDTH (PICASO_INSTR_FN_WIDTH + PICASO_INSTR_PARAM_WIDTH)

// SEG1 should be the max of all above fields and ADDR width
`define MAX0        `AK_MAX(PICASO_INSTR_ADDR_WIDTH, `OFF_RD_WIDTH)  
`define MAX1        `AK_MAX(`MAX0, `FN_RD_WIDTH)
`define MAX2        `AK_MAX(`MAX1, `FN_PARAM_WIDTH)
`define SEG1_WIDTH  `MAX2

// SEG2 is simply the opcode width
`define SEG2_WIDTH PICASO_INSTR_OPCODE_WIDTH

// save the macros into local parameters
localparam PICASO_INSTR_SEG0_WIDTH = `SEG0_WIDTH,
           PICASO_INSTR_SEG1_WIDTH = `SEG1_WIDTH,
           PICASO_INSTR_SEG2_WIDTH = `SEG2_WIDTH;

localparam PICASO_INSTR_WORD_WIDTH = PICASO_INSTR_SEG2_WIDTH 
                                     + PICASO_INSTR_SEG1_WIDTH 
                                     + PICASO_INSTR_SEG0_WIDTH;      // width of the instruction word

// remove temporary macros
`undef SEG0_WIDTH
`undef OFF_RD_WIDTH
`undef FN_RD_WIDTH
`undef FN_PARAM_WIDTH
`undef MAX0
`undef MAX1
`undef MAX2
`undef SEG1_WIDTH
`undef SEG2_WIDTH


// codes for the "opcode" fields of the instruction register
localparam [PICASO_INSTR_OPCODE_WIDTH-1:0]
  // must-have operations
  PICASO_NOP      = 0,
  PICASO_WRITE    = 1,
  PICASO_READ     = 2,
  //PICASO_MULT   = 3,    // will be implemented using UPDATEPP
  PICASO_UPDATEPP = 3,
  PICASO_ACCUM    = 4,      // functions: ACCUM_BLK, ACCUM_ROW
  PICASO_ALUOP    = 5,      // functions: ALU_ADD, ALU_SUB, ALU_CPX, ALU_CPY
  PICASO_SELECT   = 6,      // functions: selection modes, maps directly to picaso_ff.selMode
  PICASO_MOV      = 7,      // functions: offset-mov, ... (will be added as needed)
  PICASO_SUPEROP  = 8;      // TODO: Change the opcode to PICASO_SELECT, and move SELECT under SUPEROP


// codes for the "fn" field of the instruction register
localparam [PICASO_INSTR_FN_WIDTH-1:0]
  // Functions of PICASO_ACCUM
  PICASO_FN_ACCUM_BLK = 0,
  PICASO_FN_ACCUM_ROW = 1,
  // Functions of PICASO_ALUOP (following  numbers match the encoding from boothR2_serial_alu.inc.v)
  PICASO_FN_ALU_ADD = 0,
  PICASO_FN_ALU_CPX = 1,
  PICASO_FN_ALU_CPY = 2,
  PICASO_FN_ALU_SUB = 3,
  // Functions of PICASO_MOV
  PICASO_FN_MOV_OFFSET = 0;    // performs the offset-mov after UPDATEPP


// codes for the S_CODE field of the SUPER_OP instruction
localparam [PICASO_INSTR_SEG0_WIDTH-1:0]
  PICASO_SCODE_CLRMBIT = 0;    // clears the prevMbit registers in ALU


// Type codes of instructions
localparam PICASO_INSTR_TYPE_CODE_WIDTH = 1;

localparam [PICASO_INSTR_TYPE_CODE_WIDTH-1:0]
  INSTR_TYPE_SINGLE_CYCLE = 0,
  INSTR_TYPE_MULTI_CYCLE = 1;
