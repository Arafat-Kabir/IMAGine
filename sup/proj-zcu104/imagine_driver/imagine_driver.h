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
void img_test();
IMAGine_Dout img_popData();


#endif  // IMAGINE_DRIVER_H
