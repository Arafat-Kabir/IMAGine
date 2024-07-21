// Defines the control codes for the module picaso_ALGO_decoder ().
// Include it where this module is used to get the named constants.


localparam PICASO_ALGO_CODE_WIDTH = 4;


// control codes 0-0: All control codes must be unique
localparam [PICASO_ALGO_CODE_WIDTH-1:0]
  PICASO_ALGO_NOP = 0;        // must be defined as 0

// control codes FSMs: Long and descriptive names
localparam [PICASO_ALGO_CODE_WIDTH-1:0]
  // following control codes are defind for ALUOP FSM
  PICASO_ALGO_aluRst_opmxLoadParam_bRead = 1,  
  PICASO_ALGO_aluLoadParam_bRead         = 2,
  PICASO_ALGO_bRead_0                    = 3,
  PICASO_ALGO_aluEn_bRead                = 4,
  PICASO_ALGO_bWrite                     = 5,
  PICASO_ALGO_aluDis_bWrite              = 6,
  PICASO_ALGO_bRead_1                    = 7,
  // following control codes are defind for UPDATEPP FSM
  PICASO_ALGO_aluRst_opmxAopB_multRead   = 8,
  PICASO_ALGO_opmxLoadParam_bRead        = 9,     // AK-NOTE: Check the footnote [1]
  PICASO_ALGO_aluDis_bWrite_1            = 10,
  // following control codes are defined for STREAM FSM
  PICASO_ALGO_bStreamWrite               = 11,
  // following control codes are defined for ACCUM-ROW FSM
  PICASO_ALGO_accumRow_setup             = 12,
  PICASO_ALGO_accumRow_headstart         = 13;



/**** Footnotes ****
* [1] The UPDATEPP FSM states were changed as follows, which was later modified
*     inorder to fix a multiplication bug. So, all states may not make sense.
*     This note is an attempt to explain the changes and the left-over code.
*
*     Original States:                            Changed States:
*       1. PICASO_ALGO_aluRst_opmxAop0_multRead  ->    PICASO_ALGO_aluRst_opmxAopB_multRead
*       2. PICASO_ALGO_opmxLoadParam_bRead       *     PICASO_ALGO_opmxLoadParam_bRead
*       3. PICASO_ALGO_aluDis_bWrite_1                 PICASO_ALGO_aluDis_bWrite_1
*
*     - The state-1 (opmxAop0) was changed to stream both A and B operands
*       (opmxAopB). This was not essential for Booth's radix-2 algorithm, but was
*       changed to accomodate radix-4 algorithm in future. I did it here because,
*       I am working on it right now and everything is fresh in my mind,
*       which saves the context switch overhead later.
*
*     - The state-2 should have also been changed to something like bRead_0. This state
*       was originally designed to load A_op_B opmux configuration from the parameter
*       register, after state-1 set it to A_op_0. Now, as state-1 loads A_op_B, a dedicated
*       state for loading from the parameter register is not essential. However, I kept it
*       unmodified to minimize changes and leaving room for future adjustment, in case
*       I need to use two different configurations in the UPDATEPP FSM.
*/
