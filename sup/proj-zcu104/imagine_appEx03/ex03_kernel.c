#include "imagine_prog.h"


static const uint32_t word_arr[] = {
    0x44000000,   // VV_SERIAL_EN
    // ---- MACRO: MV_MULT rd=60, multiplicand=2, multiplier=0; From macro call: MV_MULTFPX rd=5, multiplicand=2, multiplier=0; 
    0x20000000, 
    0x0C3C0080, 
    0x0C7C0080, 
    0x0CBC0080, 
    0x0CFC0080, 
    0x0D3C0080, 
    0x0D7C0080, 
    0x0DBC0080, 
    0x0DFC0080, 
    0x0E3C0080, 
    0x0E7C0080, 
    0x0EBC0080, 
    0x0EFC0080, 
    0x0F3C0080, 
    0x0F7C0080, 
    0x0FBC0080, 
    0x0FFC0080, 
    // ---- End of MACRO
    0x1C08017C,   // MV_MOV_OFFSET offset=8, dest=5, src=60; From macro call: MV_MULTFPX rd=5, multiplicand=2, multiplier=0; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=6, rs=5; From macro call: MV_ALLACCUM rd=6, rs=5; 
    0x10010185, 
    0x10020186, 
    0x10030186, 
    0x10040186, 
    // ---- End of MACRO
    0x10400006,   // MV_ACCUM_ROW level=0, reg=6; From macro call: MV_ALLACCUM rd=6, rs=5; 
    0x10410006,   // MV_ACCUM_ROW level=1, reg=6; From macro call: MV_ALLACCUM rd=6, rs=5; 
    0x140A0046,   // MV_ADD rd=10, rs1=6, rs2=1
    // ---- MACRO: MV_SYNC
    0x00000000, 
    0x00000000, 
    // ---- End of MACRO
    0x48000000,   // VV_PARALLEL_EN
};


IMAGine_Prog ex03_kernel = {
    word_arr,
    sizeof(word_arr)/sizeof(word_arr[0]),   // size
    8,    // fracWidth
    64,   // mvMaxRow
    64,   // mvMaxCol
    16,   // regWidth
    8,    // idWidth
    16,   // peCount
};
