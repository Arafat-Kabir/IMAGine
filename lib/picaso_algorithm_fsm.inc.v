// Defines the parameters for the module picaso_algorithm_fsm ().
// Include it where this module is used to get the named constants.


localparam ALGORITHM_SEL_WIDTH = 2;

// algorithm selection codes
localparam ALGORITHM_ALUOP = 0,    //  ALGORITHM_ACCUMBLK is the same as ALGORITHM_ALUOP
           ALGORITHM_UPDATEPP = 1,
           ALGORITHM_ACCUMROW = 2,
           ALGORITHM_STREAM = 3;

// counter1 selection codes
localparam ALGORITHM_CTR1_SEL_WIDTH = 2;

localparam [ALGORITHM_CTR1_SEL_WIDTH-1:0] 
  ALGORITHM_CTR1_SEL_2SHR = 0,    // counter1 load value becomes (precision >> 2)
  ALGORITHM_CTR1_SEL_FULL = 1,    // counter1 load value becomes "precision" (full value)
  ALGORITHM_CTR1_SEL_ACCUM_HEADSTART = 2;    // counter1 load value is set to head-start cycle count for ACCUM-ROW
