// Defines the parameters for the module opmux_ff().
// Include it where this module is used to get the named constants.
localparam OPMUX_CONF_WIDTH = 3;
       
localparam OPMUX_A_OP_B   = 3'd0,       // X[i] = A[i], Y[i] = B[i]
           OPMUX_A_FOLD_1 = 3'd1,       // X[i] = A[i], Y[lower-half] = A[upper-half],     Y[remain] = 0
           OPMUX_A_FOLD_2 = 3'd2,       // X[i] = A[i], Y[lower-quarter] = A[2nd-quarter], Y[remain] = 0
           OPMUX_A_FOLD_3 = 3'd3,       // X[i] = A[i], Y[lq/2] = A[lq/2u],                Y[remain] = 0
           OPMUX_A_FOLD_4 = 3'd4,       // X[i] = A[i], Y[lq/4] = A[lq/4u],                Y[remain] = 0
           OPMUX_A_OP_NET = 3'd5,       // X[i] = A[i], Y[lower-bits] = net,               Y[upper-bits] = 0
           OPMUX_0_OP_B   = 3'd6,       // X[i] = 0   , Y[i] = B[i]
           OPMUX_A_OP_0   = 3'd7;       // X[i] = A[i], Y[i] = 0
