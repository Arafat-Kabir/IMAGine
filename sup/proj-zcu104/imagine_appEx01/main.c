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
#include "imagine_util.h"
#include "imagine_prog.h"
#include <stdlib.h>


// Constant declarations
#define VECBUF_SIZE  300	// IMAGine output vector buffer length
#define INPVEC_SIZE  32		// Length of the input vector to the model
#define OUTVEC_SIZE  16		// Length of the output vector from the model
const int regV=2;			// Input register for the ex01_kernel




// Loads the model parameters
void load_ex01_params() {
	// Push the parameter loader program
	extern IMAGine_Prog ex01_loader;	// defined in ex01_loader.c
	xil_printf("INFO: ex01_loader has %d instructions\n", ex01_loader.size);
	print("INFO: Pushing loader program\n");
	img_pushProgram(&ex01_loader);
	xil_printf("INFO: Finished pushing ex01_loader program\n");
}


// Loads the test input vectors, executes the kernel, and compares
// The output vector with the expected result vector.
// Returns the mismatch count.
int test_ex01_kernel() {
	// Load the test input vector
	print("INFO: Loading the test input vector\n");
	extern int16_t ex01_testInp[];	// defined in ex01_testvec.c
	extern int ex01_testInp_size;	// same file.
	int instCount;
    instCount = img_mv_LOADVEC_ROW(regV, ex01_testInp, ex01_testInp_size);
    xil_printf("INFO: %d instructions pushed by img_mv_LOADVEC_ROW()\n", instCount);


	// Push the compute kernel
	extern IMAGine_Prog ex01_kernel;	// defined in ex01_kernel.c
	xil_printf("INFO: ex01_kernel has %d instructions\n", ex01_kernel.size);
	print("INFO: Pushing ex01-kernel program\n");
	img_clearEOV();		// clear eovInterrupt flag before kernel execution
	img_pushProgram(&ex01_kernel);
	img_pollEOVmsg();	// Wait for EOV interrupt


	// Retrieve output vector and test it against the expected values
	print("INFO: Pulling out data from IMAGine FIFO-out\n");
	img_vecval_t vecOut[VECBUF_SIZE];
	int outSize = img_popVector(vecOut, VECBUF_SIZE);
	xil_printf("INFO: %d data popped from IMAGine\n", outSize);


	// test the output
	extern int16_t ex01_testOut[];		// defined in ex01_testvec.c
	extern int ex01_testOut_size;		// same file
	const char *matched = "false";
	int misCount = 0;
	for(int i=0; i < ex01_testOut_size; ++i) {
		if(vecOut[i] == ex01_testOut[i]) {
			matched = "true";
		}
		else {
			++misCount;
			matched = "false";
		}
		xil_printf("index: %2d  data: %-6d  exp: %-6d  matched: %s\n",
							i, vecOut[i], ex01_testOut[i], matched);
	}
	xil_printf("NOTE: %d output elements mismatched\n", misCount);
	return misCount;
}


// Emulates reading from a sensor.
// Writes the sensor data into the output buffer.
// Assumes sensor generates floats just for the sake of illustration.
// @param data [out]  Buffer to write sensor data into.
void readSensor(float data[INPVEC_SIZE]) {
	// Emulate sensor read using random numbers of magnitude |2**11|
	static const int range = 1 << 12;	// generate 12-bit +ve numbers
	static const int mean  = 1 << 11;	// set the mean at 2**11
	static const float scale = 100.0;	// to scale down integer to float
	for(int i=0; i<INPVEC_SIZE; ++i){
		data[i] = (rand() % range - mean) / scale;
	}
}


// Implements the argmax() function.
// @param vector [in]  Input vector.
// @param size   [in]  Input vector length.
// @return  argmax() value, -ve on error.
int argmax(const img_vecval_t *vector, const int size) {
	if(size <= 0) return -1;
	int maxIndex = 0;
	for(int i=1; i<size; ++i) {
		if(vector[i] > vector[maxIndex]) {
			maxIndex = i;
		}
	}
	return maxIndex;
}


// Given the input vector as floats, runs inference
// Using the MLP model parameters of ex01 example program.
// THANKS: Tendayi Kamucheka
int runInference(float inpVec[INPVEC_SIZE]) {
	// Load input and run the kernel
	extern IMAGine_Prog ex01_kernel;
	img_loadVectorf_row(regV, inpVec, INPVEC_SIZE, ex01_kernel.fracWidth);
	img_clearEOV();		// clear eovInterrupt flag before kernel execution
	img_pushProgram(&ex01_kernel);
	img_pollEOV();		// Wait for EOV interrupt

	// Get the GEMV output vector and run argmax() to get the class
	img_vecval_t vecOut[VECBUF_SIZE];
	img_popVector(vecOut, VECBUF_SIZE);
	int result = argmax(vecOut, OUTVEC_SIZE);
	return result;
}



int main()
{
    init_platform();
    print("\n\nINFO: Start of new session.\n");

    
    // Perform initialization and tests
    img_test();			// Tests if IMAGine is set up correctly
    load_ex01_params();	// Load the model parameter
    int misCount = test_ex01_kernel();	// Test using test-vectors
    if(misCount > 0) {
    	print("EROR: Kernel test failed, exiting ...\n");
    	return -1;
    }

    // Free-running application
    print("INFO: Starting free-running application\n");
    float sensData[INPVEC_SIZE];
    while(1) {
    	readSensor(sensData);
    	int result = runInference(sensData);
    	// Do something with the inference result
    	xil_printf("  Result: %d\n", result);
    }


    cleanup_platform();
    return 0;
}

