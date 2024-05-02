#ifndef IMAGINE_DRIVER_H
#define IMAGINE_DRIVER_H


#include <stdbool.h>
#include <stdint.h>


/**** AK-NOTE: ****/
/* Change these constants based on your IP's parameters. */

// Hardware IP Parameters
#define IMAGINE_PEPERBLOCK 16
#define IMAGINE_PEREGWIDTH 16

/******************/


// Values for IMAGine_Dout.status
#define IMAGINE_DOUT_INVALID  0
#define IMAGINE_DOUT_VALID    1


// IMAGine output vector value type
typedef int16_t img_vecval_t;

// IMAGine data output structure
typedef struct {
	img_vecval_t data;
	uint8_t      attrib;
	uint8_t      status;
} IMAGine_Dout;



// IMAGine API functions
void img_pushInstruction(uint32_t instr);
bool img_isEOV();
int  img_test();
IMAGine_Dout img_popData();


// Low-level datatypes and API functions
typedef uint16_t  img_bramaddr_t;   // address type of BRAM rows
typedef uint16_t  img_bramrow_t;	// data type of each row of BRAM
typedef uint8_t   img_bramid_t;		// data type of BRAM ROW/COL IDs

int img_writeBramNZrows(const img_bramaddr_t base,
						const img_bramrow_t *bramRows,
						const int size);

int img_makePe2BramBlock(img_bramrow_t *outArr,
						 const img_vecval_t *peArr,
						 int size);


// IMAGine JIT Assembly instructions
int img_mv_selectAll();
int img_mv_selectCol(img_bramid_t colID);
int img_mv_CLRREG(int reg);
int img_mv_LOADVEC_ROW(const int reg,
					   const img_vecval_t *vector,
					   const int size);


#endif  // IMAGINE_DRIVER_H
