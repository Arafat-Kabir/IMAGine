#include <stdint.h>

typedef struct {
    const uint32_t * const instruction;
    const int size;
    // target IMAGine configuration of the program
    const int fracWidth;
    const int mvMaxRow;
    const int mvMaxCol;
    const int regWidth;
    const int idWidth;
    const int peCount;
} IMAGine_Prog;
