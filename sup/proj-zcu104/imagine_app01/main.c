/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "imagine_driver.h"
#include "imagine_prog.h"
#include "imagine_util.h"


#define IMG_VECLEN 80	// IMAGine output vector length


// References to the IMAGine programs and data
extern IMAGine_Prog ex01_loader;
extern IMAGine_Prog ex01_kernel;
extern int16_t ex01_testarr[];
extern int ex01_testarr_size;


void runProg_ex01_loader() {
	// Push the instructions
	xil_printf("INFO: ex01_loader has %d instructions\n", ex01_loader.size);
	print("INFO: Pushing loader program\n");
	img_pushProgram(&ex01_loader);
	xil_printf("INFO: Finished pushing ex01_loader program\n");
}


void runProg_ex01_kernel() {
	// Push the instructions
	xil_printf("INFO: ex01_kernel has %d instructions\n", ex01_kernel.size);
	print("INFO: Pushing ex01-kernel program\n");
	img_pushProgram(&ex01_kernel);

	// Wait for EOV interrupt (polling)
	while(!img_isEOV()) print("INFO: Waiting for IMAGine EOV interrupt ...\n");
	print("INFO: IMAGine EOV interrupt set\n");

	// Retrieve output vector and test it agains the expected values
	print("INFO: Pulling out data from IMAGine FIFO-out\n");
	img_vecval_t vecOut[IMG_VECLEN];
	int outSize = img_popVector(vecOut, IMG_VECLEN);
	xil_printf("INFO: %d data popped from IMAGine\n", outSize);

	// convert to floating point values
	print("INFO: Printing floating point representation\n");
	float vecOutf[IMG_VECLEN];
	img_fxp2float(vecOutf, vecOut, outSize, ex01_kernel.fracWidth);
	for(int i=0; i<outSize; ++i) {
		xil_printf("fxp: %d  float: ", vecOut[i]);
		img_print_float(vecOutf[i]);
		print("\n");
	}
	print("INFO: Done\n");


	// test the output
	const char *matched = "false";
	for(int i=0; i < ex01_testarr_size; ++i) {
		if(vecOut[i] == ex01_testarr[i]) matched = "true";
		else matched = "false";
		xil_printf("index: %2d  data: %-6d  exp: %-6d  matched: %s\n",
					i, vecOut[i], ex01_testarr[i], matched);

	}
	return;
}


void runProg_ex01_kernelf() {
	img_pushProgram(&ex01_kernel);
	while(!img_isEOV()) print("INFO: Waiting for IMAGine EOV interrupt ...\n");
	print("INFO: IMAGine EOV interrupt set\n");

	// Retrieve output vector and test it agains the expected values
	print("INFO: Pulling out data from IMAGine FIFO-out\n");
	float vecOut[IMG_VECLEN];
	int outSize = img_popVectorf(vecOut, IMG_VECLEN, ex01_kernel.fracWidth);
	xil_printf("INFO: %d data popped from IMAGine\n", outSize);

	// check the output
	const char * matched;
	for(int i=0; i<outSize; ++i) {
		float exp = (ex01_testarr[i] * 1.0) / (1<<8);
		if(exp == vecOut[i]) matched = "true";
		else matched = "false";
		// formatted print
		xil_printf("index: %2d  data: ", i);
		img_print_float(vecOut[i]);
		print("  exp: ");
		img_print_float(exp);
		xil_printf("  matched: %s\n", matched);

	}
	return;
}



int main()
{
    init_platform();

    runProg_ex01_loader();
    runProg_ex01_kernel();
    runProg_ex01_kernelf();
    
    cleanup_platform();
    return 0;
}

