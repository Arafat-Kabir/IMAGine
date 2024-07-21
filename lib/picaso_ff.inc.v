// Defines the parameters for the module picaso_ff ().
// Include it where this module is used to get the named constants.

// Selection modes for row/column ID based selection.
// Set upper-bit to 0 to use only SEL_COL and SEL_BOTH.
localparam PICASO_SEL_MODE_WIDTH = 2;
localparam [PICASO_SEL_MODE_WIDTH-1:0]
  // must-have selections
  PICASO_SEL_COL   = 0,          // select the entire column
  PICASO_SEL_BLOCK = 1,          // select a specific block using row-column IDs
  // might be used in future
  PICASO_SEL_ROW   = 2,          // select the entire row
  PICASO_SEL_ENC   = 3;          // use the encoding table
