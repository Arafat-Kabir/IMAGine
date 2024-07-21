// Defines the parameters for the module boothR2_serial_alu ().
// Include it where this module is used to get the named constants.

localparam BOOTHR2_OP_WIDTH = 2;    // width of the op-codes

// Named op-codes for fullAddSub function.
// Using this encoding, user can turn off SUB and CPY by making upper bit 0. 
localparam BOOTHR2_ADD = 2'b00,
           BOOTHR2_CPX = 2'b01,
           BOOTHR2_SUB = 2'b11,   
           BOOTHR2_CPY = 2'b10;

