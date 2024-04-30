#include "imagine_prog.h"


static const uint32_t word_arr[] = {
    0x44000000,   // VV_SERIAL_EN
    // ---- MACRO: MV_MULT rd=60, multiplicand=2, multiplier=0; From macro call: MV_MULTFPX rd=3, multiplicand=2, multiplier=0; 
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
    0x1C0800FC,   // MV_MOV_OFFSET offset=8, dest=3, src=60; From macro call: MV_MULTFPX rd=3, multiplicand=2, multiplier=0; 
    // ---- MACRO: MV_BLOCK_ACCUM rd=4, rs=3; From macro call: MV_ALLACCUM rd=4, rs=3; 
    0x10010103, 
    0x10020104, 
    0x10030104, 
    0x10040104, 
    // ---- End of MACRO
    0x10400004,   // MV_ACCUM_ROW level=0, reg=4; From macro call: MV_ALLACCUM rd=4, rs=3; 
    0x10410004,   // MV_ACCUM_ROW level=1, reg=4; From macro call: MV_ALLACCUM rd=4, rs=3; 
    0x14050044,   // MV_ADD rd=5, rs1=4, rs2=1
    // ---- MACRO: MV_SYNC
    0x00000000, 
    0x00000000, 
    // ---- End of MACRO
    0x48000000,   // VV_PARALLEL_EN
};


IMAGine_Prog ex01_kernel = {
    word_arr,
    sizeof(word_arr)/sizeof(word_arr[0]),   // size
    8,    // fracWidth
    64,   // mvMaxRow
    64,   // mvMaxCol
    16,   // regWidth
    8,    // idWidth
    16,   // peCount
};


// Expected output for test inputs
int16_t ex01_testarr[] = {
  3200,
  4654,
  3364,
  3903,
  3051,
  3923,
  4428,
  3679,
  3999,
  4095,
  2742,
  3771,
  3084,
  4201,
  4365,
  3455,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
};


int ex01_testarr_size = sizeof(ex01_testarr)/sizeof(ex01_testarr[0]);

