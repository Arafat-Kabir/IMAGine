// Defines the parameters for the module alu_serial_unit ().
// Include it where this module is used to get the named constants.

localparam ALU_OP_WIDTH = 3;   // width of opConfig, 1-bit wider than the boothR2_serial_alu op-code


// opcodes for boothR2_serial_alu needs to be included before the ALU_UNIT
// opcodes can be defined. Following is a check to ensure that is the case. It
// does not make an effort to automatically include it to avoid other problems.
generate
  if(BOOTHR2_ADD);
  if(BOOTHR2_SUB);
  if(BOOTHR2_CPX);
  if(BOOTHR2_CPY);
endgenerate


// configuration codes for alu_serial_unit
localparam [ALU_OP_WIDTH-1:0]
  ALU_UNIT_ADD   = {1'b0, BOOTHR2_ADD},
  ALU_UNIT_SUB   = {1'b0, BOOTHR2_SUB},
  ALU_UNIT_CPX   = {1'b0, BOOTHR2_CPX},
  ALU_UNIT_CPY   = {1'b0, BOOTHR2_CPY},
  ALU_UNIT_BOOTH = {1'b1, BOOTHR2_ADD};   // only the MSB matters, other bits are don't care
