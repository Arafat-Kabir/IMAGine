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


// Given a float array, converts it to fixed-point array.
// @param [in]  pfxp       Fixed-point output buffer.
// @param [out] pfloat     Float array input.
// @param [in]  size       Number of values to convert.
// @param [in]  fracWidth  No. of fraction bits.
// @return  Number of data converted.
int img_float2fxp(img_vecval_t * pfxp,
				  const float * pfloat,
				  const int size,
				  const int fracWidth) {
	const int scaleFact = 1 << fracWidth;
	int count = 0;
	for(; count<size; ++count) {
		*pfxp++ = (*pfloat++) * scaleFact;
	}
	return count;
}


// Prints the floating point representation upto 5 decimal digits.
// This utility is used because xil_printf() does not support %f.
// @param val [in]  Floating point value to print
void img_printFloat(double val) {
	int whole = val;
	int frac  = (val-whole)*100000;	// 5 digits after decimal point
	xil_printf("%d.%05d", whole, frac);
}


// Polls IMAGine EOV signal
void img_pollEOV() {
	while(!img_isEOV());
}


// Polls IMAGine EOV signal and prints messages while waiting.
// This version is good for debugging. You'll know if you
// get stuck for a while while polling.
void img_pollEOVmsg() {
	print("WAIT: Polling IMAGine-EOV ");
	while(!img_isEOV()) print(". ");
	print("Done\n");
}


// Loads a row vector of floats into IMAGine GEMV register.
// @param reg    [in]  Destination register no.
// @param vector [in]  Pointer to the row vector to load into
//                     the register.
// @param size   [in]  Length of the vector.
// @return  Number instructions pushed, including the clearReg() writes.
//          -ve return value on error.
int img_mv_loadVecf_row(const int reg,
					    const float *vector,
					    const int size)
{
	int instCount = 0;
    return instCount;
}


