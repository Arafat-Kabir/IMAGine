#include "imagine_driver.h"
#include "imagine_prog.h"
#include "imagine_util.h"
#include "xil_printf.h"


// Given an IMAGine_Prog reference, pushes all instructions
// into FIFO-in. Returns an error code.
// @param [in] prog  The program to push into FIFO-in
// @return  Error code. 0 means success.
int img_pushProgram(const IMAGine_Prog *prog) {
	// Push the instructions using the driver API
	for(int i=0; i<prog->size; ++i) {
		img_pushInstruction(prog->instruction[i]);
	}
	return 0;
}


// Pops the output vector from the FIFO-out into buff.
// @param [out] buff  Output buffer.
// @param [int] size  Max size of the output buffer.
//                    At max these many data will be popped.
// @return  Number of data popped from FIFO-out.
int img_popVector(img_vecval_t * const buff, const int size) {
	IMAGine_Dout dout;
	int buffIndex = 0;
	while(buffIndex<size) {
		dout = img_popData();
		if(dout.status == IMAGINE_DOUT_VALID) {
			buff[buffIndex++] = dout.data;
		} else {
			break;
		}
	}
	// buffIndex = no. of data read
	return buffIndex;
}


// Same as img_popVector, except converts the output into
// floating point based on the fixed-point precision of the program.
// @param [out] buff       Output buffer.
// @param [in]  size       Max size of the output buffer.
//                         At max these many data will be popped.
// @param [in]  fracWidth  No. of fraction bits.
// @return  Number of data popped from FIFO-out.
int img_popVectorf(float * const buff, const int size, const int fracWidth) {
	const int scaleFact = 1 << fracWidth;
	IMAGine_Dout dout;
	int buffIndex = 0;
	while(buffIndex<size) {
		dout = img_popData();
		if(dout.status == IMAGINE_DOUT_VALID) {
			float data = dout.data;
			buff[buffIndex++] = data/scaleFact;
		} else {
			break;
		}
	}
	// buffIndex = no. of data read
	return buffIndex;
}


// Given a fixed point array, converts it to floating point.
// @param [out] pfloat     Output buffer.
// @param [in]  pfxp       Fixed-point input array
// @param [in]  size       Number of values to convert.
// @param [in]  fracWidth  No. of fraction bits.
// @return  Number of data converted.
int img_fxp2float(float * pfloat,
				  const img_vecval_t * pfxp,
				  const int size,
				  const int fracWidth) {
	const int scaleFact = 1 << fracWidth;
	int count = 0;
	for(; count<size; ++count) {
		*pfloat++ = (1.0 * *pfxp++) / scaleFact;
	}
	return count;
}


// Prints the floating point representation upto 5 decimal digits
void img_print_float(double val) {
	int whole = val;
	int frac  = (val-whole)*100000;	// 5 digits after decimal point
	xil_printf("%d.%05d", whole, frac);
}
