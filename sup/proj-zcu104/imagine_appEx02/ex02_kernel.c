#include "imagine_prog.h"


static const uint32_t word_arr[] = {
    0x44000000,   // VV_SERIAL_EN
    // ---- MACRO: MV_MULT rd=60, multiplicand=20, multiplier=0; From macro call: MV_MULTFPX rd=22, multiplicand=20, multiplier=0; 
    0x20000000, 
    0x0C3C0500, 
    0x0C7C0500, 
    0x0CBC0500, 
    0x0CFC0500, 
    0x0D3C0500, 
    0x0D7C0500, 
    0x0DBC0500, 
    0x0DFC0500, 
    0x0E3C0500, 
    0x0E7C0500, 
    0x0EBC0500, 
    0x0EFC0500, 
    0x0F3C0500, 
    0x0F7C0500, 
    0x0FBC0500, 
    0x0FFC0500, 
    // ---- End of MACRO
    0x1C0805BC,   // MV_MOV_OFFSET offset=8, dest=22, src=60; From macro call: MV_MULTFPX rd=22, multiplicand=20, multiplier=0; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=23, rs=22; From macro call: MV_ALLACCUM rd=23, rs=22; 
    0x100105D6, 
    0x100205D7, 
    0x100305D7, 
    0x100405D7, 
    // ---- End of MACRO
    0x10400017,   // MV_ACCUM_ROW level=0, reg=23; From macro call: MV_ALLACCUM rd=23, rs=22; 
    0x10410017,   // MV_ACCUM_ROW level=1, reg=23; From macro call: MV_ALLACCUM rd=23, rs=22; 
    // ---- MACRO: MV_MULT rd=60, multiplicand=21, multiplier=4; From macro call: MV_MULTFPX rd=22, multiplicand=21, multiplier=4; 
    0x20000000, 
    0x0C3C0544, 
    0x0C7C0544, 
    0x0CBC0544, 
    0x0CFC0544, 
    0x0D3C0544, 
    0x0D7C0544, 
    0x0DBC0544, 
    0x0DFC0544, 
    0x0E3C0544, 
    0x0E7C0544, 
    0x0EBC0544, 
    0x0EFC0544, 
    0x0F3C0544, 
    0x0F7C0544, 
    0x0FBC0544, 
    0x0FFC0544, 
    // ---- End of MACRO
    0x1C0805BC,   // MV_MOV_OFFSET offset=8, dest=22, src=60; From macro call: MV_MULTFPX rd=22, multiplicand=21, multiplier=4; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=24, rs=22; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x10010616, 
    0x10020618, 
    0x10030618, 
    0x10040618, 
    // ---- End of MACRO
    0x10400018,   // MV_ACCUM_ROW level=0, reg=24; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x10410018,   // MV_ACCUM_ROW level=1, reg=24; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x141E0617,   // MV_ADD rd=30, rs1=23, rs2=24
    0x141E021E,   // MV_ADD rd=30, rs1=30, rs2=8
    // ---- MACRO: MV_SYNC
    0x00000000, 
    0x00000000, 
    // ---- End of MACRO
    0x48000000,   // VV_PARALLEL_EN
    // ---- MACRO: VV_SYNC
    0x40000000, 
    // ---- End of MACRO
    0x44000000,   // VV_SERIAL_EN
    // ---- MACRO: MV_MULT rd=60, multiplicand=20, multiplier=1; From macro call: MV_MULTFPX rd=22, multiplicand=20, multiplier=1; 
    0x20000000, 
    0x0C3C0501, 
    0x0C7C0501, 
    0x0CBC0501, 
    0x0CFC0501, 
    0x0D3C0501, 
    0x0D7C0501, 
    0x0DBC0501, 
    0x0DFC0501, 
    0x0E3C0501, 
    0x0E7C0501, 
    0x0EBC0501, 
    0x0EFC0501, 
    0x0F3C0501, 
    0x0F7C0501, 
    0x0FBC0501, 
    0x0FFC0501, 
    // ---- End of MACRO
    0x1C0805BC,   // MV_MOV_OFFSET offset=8, dest=22, src=60; From macro call: MV_MULTFPX rd=22, multiplicand=20, multiplier=1; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=23, rs=22; From macro call: MV_ALLACCUM rd=23, rs=22; 
    0x100105D6, 
    0x100205D7, 
    0x100305D7, 
    0x100405D7, 
    // ---- End of MACRO
    0x10400017,   // MV_ACCUM_ROW level=0, reg=23; From macro call: MV_ALLACCUM rd=23, rs=22; 
    0x10410017,   // MV_ACCUM_ROW level=1, reg=23; From macro call: MV_ALLACCUM rd=23, rs=22; 
    // ---- MACRO: MV_MULT rd=60, multiplicand=21, multiplier=5; From macro call: MV_MULTFPX rd=22, multiplicand=21, multiplier=5; 
    0x20000000, 
    0x0C3C0545, 
    0x0C7C0545, 
    0x0CBC0545, 
    0x0CFC0545, 
    0x0D3C0545, 
    0x0D7C0545, 
    0x0DBC0545, 
    0x0DFC0545, 
    0x0E3C0545, 
    0x0E7C0545, 
    0x0EBC0545, 
    0x0EFC0545, 
    0x0F3C0545, 
    0x0F7C0545, 
    0x0FBC0545, 
    0x0FFC0545, 
    // ---- End of MACRO
    0x1C0805BC,   // MV_MOV_OFFSET offset=8, dest=22, src=60; From macro call: MV_MULTFPX rd=22, multiplicand=21, multiplier=5; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=24, rs=22; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x10010616, 
    0x10020618, 
    0x10030618, 
    0x10040618, 
    // ---- End of MACRO
    0x10400018,   // MV_ACCUM_ROW level=0, reg=24; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x10410018,   // MV_ACCUM_ROW level=1, reg=24; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x141F0617,   // MV_ADD rd=31, rs1=23, rs2=24
    0x141F025F,   // MV_ADD rd=31, rs1=31, rs2=9
    // ---- MACRO: MV_SYNC
    0x00000000, 
    0x00000000, 
    // ---- End of MACRO
    0x48000000,   // VV_PARALLEL_EN
    // ---- MACRO: VV_SYNC
    0x40000000, 
    // ---- End of MACRO
    0x44000000,   // VV_SERIAL_EN
    // ---- MACRO: MV_MULT rd=60, multiplicand=20, multiplier=2; From macro call: MV_MULTFPX rd=22, multiplicand=20, multiplier=2; 
    0x20000000, 
    0x0C3C0502, 
    0x0C7C0502, 
    0x0CBC0502, 
    0x0CFC0502, 
    0x0D3C0502, 
    0x0D7C0502, 
    0x0DBC0502, 
    0x0DFC0502, 
    0x0E3C0502, 
    0x0E7C0502, 
    0x0EBC0502, 
    0x0EFC0502, 
    0x0F3C0502, 
    0x0F7C0502, 
    0x0FBC0502, 
    0x0FFC0502, 
    // ---- End of MACRO
    0x1C0805BC,   // MV_MOV_OFFSET offset=8, dest=22, src=60; From macro call: MV_MULTFPX rd=22, multiplicand=20, multiplier=2; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=23, rs=22; From macro call: MV_ALLACCUM rd=23, rs=22; 
    0x100105D6, 
    0x100205D7, 
    0x100305D7, 
    0x100405D7, 
    // ---- End of MACRO
    0x10400017,   // MV_ACCUM_ROW level=0, reg=23; From macro call: MV_ALLACCUM rd=23, rs=22; 
    0x10410017,   // MV_ACCUM_ROW level=1, reg=23; From macro call: MV_ALLACCUM rd=23, rs=22; 
    // ---- MACRO: MV_MULT rd=60, multiplicand=21, multiplier=6; From macro call: MV_MULTFPX rd=22, multiplicand=21, multiplier=6; 
    0x20000000, 
    0x0C3C0546, 
    0x0C7C0546, 
    0x0CBC0546, 
    0x0CFC0546, 
    0x0D3C0546, 
    0x0D7C0546, 
    0x0DBC0546, 
    0x0DFC0546, 
    0x0E3C0546, 
    0x0E7C0546, 
    0x0EBC0546, 
    0x0EFC0546, 
    0x0F3C0546, 
    0x0F7C0546, 
    0x0FBC0546, 
    0x0FFC0546, 
    // ---- End of MACRO
    0x1C0805BC,   // MV_MOV_OFFSET offset=8, dest=22, src=60; From macro call: MV_MULTFPX rd=22, multiplicand=21, multiplier=6; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=24, rs=22; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x10010616, 
    0x10020618, 
    0x10030618, 
    0x10040618, 
    // ---- End of MACRO
    0x10400018,   // MV_ACCUM_ROW level=0, reg=24; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x10410018,   // MV_ACCUM_ROW level=1, reg=24; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x14200617,   // MV_ADD rd=32, rs1=23, rs2=24
    0x142002A0,   // MV_ADD rd=32, rs1=32, rs2=10
    // ---- MACRO: MV_SYNC
    0x00000000, 
    0x00000000, 
    // ---- End of MACRO
    0x48000000,   // VV_PARALLEL_EN
    // ---- MACRO: VV_SYNC
    0x40000000, 
    // ---- End of MACRO
    0x44000000,   // VV_SERIAL_EN
    // ---- MACRO: MV_MULT rd=60, multiplicand=20, multiplier=3; From macro call: MV_MULTFPX rd=22, multiplicand=20, multiplier=3; 
    0x20000000, 
    0x0C3C0503, 
    0x0C7C0503, 
    0x0CBC0503, 
    0x0CFC0503, 
    0x0D3C0503, 
    0x0D7C0503, 
    0x0DBC0503, 
    0x0DFC0503, 
    0x0E3C0503, 
    0x0E7C0503, 
    0x0EBC0503, 
    0x0EFC0503, 
    0x0F3C0503, 
    0x0F7C0503, 
    0x0FBC0503, 
    0x0FFC0503, 
    // ---- End of MACRO
    0x1C0805BC,   // MV_MOV_OFFSET offset=8, dest=22, src=60; From macro call: MV_MULTFPX rd=22, multiplicand=20, multiplier=3; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=23, rs=22; From macro call: MV_ALLACCUM rd=23, rs=22; 
    0x100105D6, 
    0x100205D7, 
    0x100305D7, 
    0x100405D7, 
    // ---- End of MACRO
    0x10400017,   // MV_ACCUM_ROW level=0, reg=23; From macro call: MV_ALLACCUM rd=23, rs=22; 
    0x10410017,   // MV_ACCUM_ROW level=1, reg=23; From macro call: MV_ALLACCUM rd=23, rs=22; 
    // ---- MACRO: MV_MULT rd=60, multiplicand=21, multiplier=7; From macro call: MV_MULTFPX rd=22, multiplicand=21, multiplier=7; 
    0x20000000, 
    0x0C3C0547, 
    0x0C7C0547, 
    0x0CBC0547, 
    0x0CFC0547, 
    0x0D3C0547, 
    0x0D7C0547, 
    0x0DBC0547, 
    0x0DFC0547, 
    0x0E3C0547, 
    0x0E7C0547, 
    0x0EBC0547, 
    0x0EFC0547, 
    0x0F3C0547, 
    0x0F7C0547, 
    0x0FBC0547, 
    0x0FFC0547, 
    // ---- End of MACRO
    0x1C0805BC,   // MV_MOV_OFFSET offset=8, dest=22, src=60; From macro call: MV_MULTFPX rd=22, multiplicand=21, multiplier=7; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=24, rs=22; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x10010616, 
    0x10020618, 
    0x10030618, 
    0x10040618, 
    // ---- End of MACRO
    0x10400018,   // MV_ACCUM_ROW level=0, reg=24; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x10410018,   // MV_ACCUM_ROW level=1, reg=24; From macro call: MV_ALLACCUM rd=24, rs=22; 
    0x14210617,   // MV_ADD rd=33, rs1=23, rs2=24
    0x142102E1,   // MV_ADD rd=33, rs1=33, rs2=11
    // ---- MACRO: MV_SYNC
    0x00000000, 
    0x00000000, 
    // ---- End of MACRO
    0x48000000,   // VV_PARALLEL_EN
    // ---- MACRO: VV_SYNC
    0x40000000, 
    // ---- End of MACRO
};


IMAGine_Prog ex02_kernel = {
    word_arr,
    sizeof(word_arr)/sizeof(word_arr[0]),   // size
    8,    // fracWidth
    64,   // mvMaxRow
    64,   // mvMaxCol
    16,   // regWidth
    8,    // idWidth
    16,   // peCount
};
