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


#define IMG_VECLEN 80	// IMAGine output vector buffer length


// References to the IMAGine programs and data
extern IMAGine_Prog ex01_loader;
extern IMAGine_Prog ex01_kernel;
extern int16_t ex01_testOut[];
extern int ex01_testOut_size;
extern int16_t ex01_testInp[];
extern int ex01_testInp_size;
const int regV = 2;		// input register for ex01_kernel


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
	img_pollEOVmsg();	// Wait for EOV interrupt

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
		img_printFloat(vecOutf[i]);
		print("\n");
	}
	print("INFO: Done\n");


	// test the output
	const char *matched = "false";
	for(int i=0; i < ex01_testOut_size; ++i) {
		if(vecOut[i] == ex01_testOut[i]) matched = "true";
		else matched = "false";
		xil_printf("index: %2d  data: %-6d  exp: %-6d  matched: %s\n",
					i, vecOut[i], ex01_testOut[i], matched);

	}
	return;
}


void runProg_ex01_kernelf() {
	img_pushProgram(&ex01_kernel);
	img_pollEOVmsg();

	// Retrieve output vector and test it agains the expected values
	print("INFO: Pulling out data from IMAGine FIFO-out\n");
	float vecOut[IMG_VECLEN];
	int outSize = img_popVectorf(vecOut, IMG_VECLEN, ex01_kernel.fracWidth);
	xil_printf("INFO: %d data popped from IMAGine\n", outSize);

	// check the output
	const char * matched;
	for(int i=0; i<outSize; ++i) {
		float exp = (ex01_testOut[i] * 1.0) / (1<<8);
		if(exp == vecOut[i]) matched = "true";
		else matched = "false";
		// formatted print
		xil_printf("index: %2d  data: ", i);
		img_printFloat(vecOut[i]);
		print("  exp: ");
		img_printFloat(exp);
		xil_printf("  matched: %s\n", matched);
	}
	return;
}


void ex01_tests() {
    runProg_ex01_loader();
    runProg_ex01_kernel();

    img_mv_CLRREG(regV);
    runProg_ex01_kernel();

    // Test for float2fpx()
    int convCount;
    float convFloatVec[IMG_VECLEN];
    //img_vecval_t convFxpVec[IMG_VECLEN];

	convCount = img_fxp2float(convFloatVec, ex01_testInp, ex01_testInp_size, ex01_kernel.fracWidth);
	xil_printf("INFO: %d data converted from fxp to float\n", convCount);

	// Test for img_loadVecf_row()
	int instCount = img_loadVectorf_row(regV, convFloatVec, ex01_testInp_size, ex01_kernel.fracWidth);
    xil_printf("INFO: %d instructions pushed by img_loadVecf_row()\n", instCount);
    runProg_ex01_kernel();

	// Test for img_mv_LOADVEC_ROW()
    instCount = img_mv_LOADVEC_ROW(regV, ex01_testInp, ex01_testInp_size);
    xil_printf("INFO: %d instructions pushed by img_mv_LOADVEC_ROW()\n", instCount);
    runProg_ex01_kernel();

    //runProg_ex01_kernelf();
}


/** Tests for ex02 **/
extern IMAGine_Prog ex02_loader;
extern IMAGine_Prog ex02_kernel;
extern int16_t ex02_testOut[];
extern int ex02_testOut_size;
extern int16_t ex02_testXt[];
extern int ex02_testXt_size;
extern int16_t ex02_testHp[];
extern int ex02_testHp_size;
const int regXt = 20;		// input register for ex02_kernel
const int regHp = 21;		// another input register for ex02_kernel

void runProg_ex02_loader() {
	// Push the instructions
	xil_printf("INFO: ex02_loader has %d instructions\n", ex02_loader.size);
	print("INFO: Pushing loader program\n");
	img_pushProgram(&ex02_loader);
	xil_printf("INFO: Finished pushing ex02_loader program\n");
}


void runProg_ex02_kernel() {
	// Push the instructions
	xil_printf("INFO: ex02_kernel has %d instructions\n", ex02_kernel.size);
	print("INFO: Pushing ex02-kernel program\n");
	img_pushProgram(&ex02_kernel);
	img_pollEOVmsg();	// Wait for EOV interrupt

	// Retrieve output vector and test it agains the expected values
	print("INFO: Pulling out data from IMAGine FIFO-out\n");
	img_vecval_t vecOut[IMG_VECLEN];
	int outSize = img_popVector(vecOut, IMG_VECLEN);
	xil_printf("INFO: %d data popped from IMAGine\n", outSize);

	// test the output
	const char *matched = "false";
	for(int i=0; i < ex02_testOut_size; ++i) {
		if(vecOut[i] == ex02_testOut[i]) matched = "true";
		else matched = "false";
		xil_printf("index: %2d  data: %-6d  exp: %-6d  matched: %s\n",
					i, vecOut[i], ex02_testOut[i], matched);

	}
	return;
}



void ex02_tests() {
	runProg_ex02_loader();
	runProg_ex02_kernel();
}



int main()
{
    init_platform();

    print("\n\nINFO: Start of new session.\n");
    img_test();

    //ex01_tests();
    ex02_tests();

    cleanup_platform();
    return 0;
}

