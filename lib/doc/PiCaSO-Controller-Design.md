**PiCaSO Controller V1.0**
==========================

The PiCaSO controller provides a processor-like interface to PiCaSO. It
can be used to control a single block or an array of blocks.

**Controller Interface**
------------------------

The controller takes an instruction word. The instruction width is not
fixed; it changes depending on the implementation. However, it has the
following general structure.


    ┌────────┐ ┌──────┐ ┌────────────┐
    │ OpCode │ │ ADDR │ │    DATA    │
    └────────┘ └──────┘ └────────────┘

    ┌────────┐ ┌──────┐ ┌────────────┐
    │ OpCode │ │  RD  │ │ {RS2, RS1} │
    └────────┘ └──────┘ └────────────┘

    ┌────────┐ ┌──────┐ ┌────────────┐
    │ OpCode │ │  xx  │ │     R      │
    └────────┘ └──────┘ └────────────┘


-   **OpCode:** 3 - 6 bits

-   **ADDR:** Corresponds to the address of the BRAM block, typically
    10-12 bits.

-   **Data:** Corresponds to the width of the BRAM port, typically
    16-bits.

-   **RD:** Destination register base address. Width \<= 8-bits, can
    support up to 256 registers.

-   **RS1, RS2:** Base address of source registers. Width \<= 8-bits.

-   **R:** Base address of a register that is the source and/or
    destination of the operation. Width \<= 8-bits.

-   If **Data** width is 16-bits, register base address can be 8-bits.
    Thus, RS1 and RS2 can fit into the 16-bits of the **Data** bits of
    the instruction word. If the **Data** width is smaller, so shall be
    the register base address widths. That is okay, because we typically
    will have 8--16-bit registers which requires 6-7 bits for base
    address.

-   Usually, the **ADDR** for BRAMs will be \>= 8-bits. So, **RD** can
    easily fit into the **ADDR** bits of the instruction word.

**Supported Instructions**\
This list will be changing as per the need's basis. However, for the
draft of V1.0, the following instructions are selected.

-   **NOP X, X**\
    Does nothing.

-   **RESET X, X**\
    Resets all registers withing it's control domain.

-   **WRITE ADDR, DATA**\
    Writes the DATA into the ADDR of the BRAM.

-   **READ ADDR, X**\
    Reads from the ADDR of the BRAM.

-   **ALU\_OP RD, RS1, RS2**\
    Configures the ALU for the ALU\_OP operation then executes the
    operation. The result is stored into RD. The result is calculated as
    RD = RS1 OP RS2. That is if ALU\_OP is SUB then, RD = RS1 -- RS2.
    The ALU\_OP bit-pattern does not have to match the actual opcode of
    the ALU, use a decoder LUT. If it matches somehow, that's a bonus.
    ALU\_OP is not fixed; it depends on the supported operations of the
    PiCaSO ALU.

-   **Zero-Out R**\
    Clears the register content making it 0.

-   **MOV RD, RS**\
    Moves (copies) contents of RS to RD.

-   **MULT RD, RS1, RS2**\
    Performs multiplication between RS1 and RS2, using RS1 as the
    multiplicand and RS2 as the multiplier. The result is stored into
    RD.\
    This instruction fires up an FSM to perform fixed-point
    multiplication using repeated ADD (may or may not use Booth's
    algorithm). It uses some registers (preferably with the highest base
    addresses) as scratchpads to store intermediate result, which is 2x
    wider than the N-bit source operands. It then copies back the N-bit
    result to RD.\
    The entire process should not take more than 2N + 2N^2^ cycles
    (Atiyeh's Booth's Radix-2). The cycle-count can be reduced by not
    saving the lower half of the fractional bits and not computing the
    upper half of the integer bits. It can set some status flags
    specifying if there was overflow. For the first version, let's keep
    things simple: save all the fractional bits, don't compute the upper
    half of the integer, don't set any status flags.

-   **Accum-Block R**\
    Accumulates the specified register (R) of all PEs within a PE-Block
    (PiCaSO) towards PE-0 (0-th column of BRAM). In the process, it
    modifies the contents of the registers. At the end, only the
    register of PE-0 is valid. The content of register R of the other
    PEs in the block are undefined. They may or may not contain
    meaningful intermediate results.\
    This instruction fires up an FSM that performs the accumulation by
    repeated ADD and changing the configuration of OpMux to different
    folds (A-FOLD-x).

-   **Accum-Row Max-Level, R**\
    Accumulates the specified register along the entire row of the PE
    block. **Note that**, it accumulates register R of only PE-0 of each
    PE-Block (PiCaSO) along the row. In the process, the contents of R
    in PE-0 of all blocks are modified. At the end, the R of only PE-0
    of Block-0 (COL\_ID=0) is valid. Contents of R of PE-0 of other
    blocks are undefined.\
    Max-Level specifies the maximum level of the "conceptual
    binary-tree" to be used during accumulation. Max-Level (if 0: 2 PE
    Blocks are accumulated), (if 1: 4 PE Blocks are accumulated), (if 2:
    8 PE Blocks are accumulated), etc.\
    This instruction fires up an FSM to perform the accumulation. It is
    achieved by repeatedly changing the "Level" of the network-node then
    streaming data out of port-A of register-file and adding network
    stream with the port-B stream of the register-file. The "Level"
    starts at 0 then goes up to Max-Level.
