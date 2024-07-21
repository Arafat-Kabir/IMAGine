// defines the parameters of vecshift_tile module

localparam VECSHIFT_CONFIG_WIDTH = 2;
localparam VECSHIFT_STATUS_WIDTH = 2;
localparam VECSHIFT_INSTR_WIDTH  = VECSHIFT_CONFIG_WIDTH;   // for this implementation, the instruction has one-one mapping with the configuration

// vecshift_tile configuration codes
localparam [VECSHIFT_CONFIG_WIDTH-1:0]
  VECSHIFT_IDLE        = 0,   // don't change anything (rest mode value)
  VECSHIFT_SERIAL_EN   = 1,   // enable serial-shift mode
  VECSHIFT_PARALLEL_EN = 2,   // enable parallel-shift mode
  VECSHIFT_DISABLE     = 3;   // disable shifting


// vecshift_reg internal configuration output port
typedef struct packed {
  logic shiftSerialEn;
  logic shiftParallelEn;
  logic _dummy;   // to avoid a bug in xvlog
} vecshift_reg_intConfig_t;
