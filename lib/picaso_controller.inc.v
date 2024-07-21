// Defines the parameters for the module picaso_controller ().
// Include it where this module is used to get the named constants.


// selection code for output register input mux
localparam [0:0] PICASO_CTRL_SEL_DECODE_SIGNALS = 0,    // selects control signals from decoder block
                 PICASO_CTRL_SEL_ALGO_SIGNALS = 1;      // selects control signals from algorithm FSM

// The width can change based on the number of op-codes
localparam PICASO_CTRL_OPCODE_WIDTH = 4,
           PICASO_CTRL_FN_WIDTH = 2;

