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
#define IMGROW_SIZE  64		// No. of IMAGine rows (also the length of vector shift register)
#define INPVEC_SIZE  20 	// Length of the input vector (Xt)
#define HIDENV_SIZE  16		// Size of the LSTM hidden state (Hp)
const int regXt = 20;		// input register for Xt of ex02_kernel
const int regHp = 21;		// input register for Hp of ex02_kernel




// Loads the model parameters
void load_ex02_params() {
	// Push the parameter loader program
	extern IMAGine_Prog ex02_loader;	// defined in ex02_loader.c
	xil_printf("INFO: ex02_loader has %d instructions\n", ex02_loader.size);
	print("INFO: Pushing loader program\n");
	img_pushProgram(&ex02_loader);
	xil_printf("INFO: Finished pushing ex02_loader program\n");
}


// Compares vecTest elements with vecRef elements.
// @return  No. of mismathces.
int matchVectors(int16_t *vecTest, int16_t *vecRef, const int size) {
	const char *matched = "false";
	int misMatch = 0;
	for(int i=0; i < size; ++i) {
		if(vecTest[i] == vecRef[i]) matched = "true";
		else {
			matched = "false";
			++misMatch;
		}
		xil_printf("index: %2d  data: %-6d  exp: %-6d  matched: %s\n",
					i, vecTest[i], vecRef[i], matched);

	}
	return misMatch;
}


// Loads the test input vectors, executes the kernel, and compares
// The output vector with the expected result vector.
// Returns the total mismatch count.
int test_ex02_kernel() {
	// Load the test input vector
	extern int16_t ex02_testXt[]; extern int ex02_testXt_size;
	extern int16_t ex02_testHp[]; extern int ex02_testHp_size;
	print("INFO: Loading the test input vector Xt\n");

	int instCount;
    instCount = img_mv_LOADVEC_ROW(regXt, ex02_testXt, ex02_testXt_size);
    xil_printf("INFO: %d instructions pushed by img_mv_LOADVEC_ROW() for Xt\n", instCount);

    instCount = img_mv_LOADVEC_ROW(regHp, ex02_testHp, ex02_testHp_size);
    xil_printf("INFO: %d instructions pushed by img_mv_LOADVEC_ROW() for Hp\n", instCount);


	// Push the compute kernel
	extern IMAGine_Prog ex02_kernel;	// defined in ex01_kernel.c
	xil_printf("INFO: ex02_kernel has %d instructions\n", ex02_kernel.size);
	print("INFO: Pushing ex02-kernel program\n");
	img_clearEOV();		// clear eovInterrupt flag before kernel execution
	img_pushProgram(&ex02_kernel);
	img_pollEOVmsg();	// Wait for EOV interrupt


	// Retrieve output vector and test it against the expected values
	print("INFO: Pulling out data from IMAGine FIFO-out\n");
	img_vecval_t vecOut[VECBUF_SIZE];
	int outSize = img_popVector(vecOut, VECBUF_SIZE);
	xil_printf("INFO: %d data popped from IMAGine\n", outSize);


	// Compare the output with reference results in ex02_testvec.c
	extern int16_t ex02_IaFxp[]; extern int ex02_IaFxp_size;
	extern int16_t ex02_FaFxp[]; extern int ex02_FaFxp_size;
	extern int16_t ex02_OaFxp[]; extern int ex02_OaFxp_size;
	extern int16_t ex02_CaFxp[]; extern int ex02_CaFxp_size;

	int totalMis = 0;
	int misCount;
	misCount = matchVectors(vecOut, ex02_IaFxp, ex02_IaFxp_size);
	xil_printf("NOTE: %d mismatches for ex02_IaFxp\n", misCount);
	totalMis += misCount;

	misCount = matchVectors(&vecOut[IMGROW_SIZE], ex02_FaFxp, ex02_FaFxp_size);
	xil_printf("NOTE: %d mismatches for ex02_FaFxp\n", misCount);
	totalMis += misCount;

	misCount = matchVectors(&vecOut[IMGROW_SIZE*2], ex02_OaFxp, ex02_OaFxp_size);
	xil_printf("NOTE: %d mismatches for ex02_OaFxp\n", misCount);
	totalMis += misCount;

	misCount = matchVectors(&vecOut[IMGROW_SIZE*3], ex02_CaFxp, ex02_CaFxp_size);
	xil_printf("NOTE: %d mismatches for ex02_CaFxp\n", misCount);
	totalMis += misCount;

	return totalMis;
}



// Emulates reading from a sensor.
// Writes the sensor data into the output buffer.
// Assumes the sensor generates fixed-point numbers compatible with IMAGine.
// @param data [out]  Buffer to write sensor data into.
void readSensor(int16_t data[INPVEC_SIZE]) {
	// Emulate sensor read using random numbers of magnitude |2**11|
	static const int range = 1 << 12;	// generate 12-bit +ve numbers
	static const int mean  = 1 << 11;	// set the mean at 2**11
	static const float scale = 100.0;	// to scale down integer to float
	for(int i=0; i<INPVEC_SIZE; ++i){
		data[i] = (rand() % range - mean) / scale;
	}
}


// CPU function to perform activation operations
// of the LSTM cell. (Dummy for illustration)
// @param Ct [out]  Output Ct, the next cell state.
// @param Ht [out]  Output Ht, the next hidden state.
void runActivation(img_vecval_t Ia[HIDENV_SIZE],
				   img_vecval_t Fa[HIDENV_SIZE],
				   img_vecval_t Oa[HIDENV_SIZE],
				   img_vecval_t C_a[HIDENV_SIZE],
				   img_vecval_t Ct[HIDENV_SIZE],
				   img_vecval_t Ht[HIDENV_SIZE])
{
	// Perform the following operations on CPU
	//   Operations on CPU,
	//     It  = sigmoid(Ia)
	//     Ft  = sigmoid(Fa)
	//     Ot  = sigmoid(Oa)
	//     C_t = tanh(C_a)
	//     Ct  = Ft * Cp + It * C_t
	//     Ht  = Ot * tanh(Ct)
}


// Given the input vector and current hidden-state as fixed-point vectors, 
// runs one iteration of LSTM cell using IMAGine ex02_kernel.
// Puts the next hidden-state into the hiddenState vector.
// @param inpVec      [in]     Input vector from sensor (Xt)
// @param hiddenState [in/out] Reads the last hidden-state from it,
//							   Then updated it with the new hidden state.
// @param cellState   [in/out] Reads the last cell-state from it,
//							   Then updated it with the new cell state.
void runLSTMCell(int16_t inpVec[INPVEC_SIZE],
		         int16_t hiddenState[HIDENV_SIZE],
				 int16_t cellState[HIDENV_SIZE])
{
	// Load input and run the kernel
	extern IMAGine_Prog ex02_kernel;
    img_mv_LOADVEC_ROW(regXt, inpVec, INPVEC_SIZE);
    img_mv_LOADVEC_ROW(regHp, hiddenState, HIDENV_SIZE);
	img_clearEOV();		// clear eovInterrupt flag before kernel execution
	img_pushProgram(&ex02_kernel);
	img_pollEOV();	    // Wait for EOV interrupt

	// Get the GEMV output vector and separate them for activation
	img_vecval_t vecOut[VECBUF_SIZE];
	img_popVector(vecOut, VECBUF_SIZE);
	//  Operations on IMAGine,
	//     Ia  = Wxi @ Xt + Whi @ Hp + bi
	//     Fa  = Wxf @ Xt + Whf @ Hp + bf
	//     Oa  = Wxo @ Xt + Who @ Hp + bo
	//     C_a = Wxc @ Xt + Whc @ Hp + bc
	img_vecval_t Ia[HIDENV_SIZE];
	img_vecval_t Fa[HIDENV_SIZE];
	img_vecval_t Oa[HIDENV_SIZE];
	img_vecval_t C_a[HIDENV_SIZE];
	for(int i=0; i<HIDENV_SIZE; ++i) {
		Ia[i]  = vecOut[IMGROW_SIZE*0 + i];
		Fa[i]  = vecOut[IMGROW_SIZE*1 + i];
		Oa[i]  = vecOut[IMGROW_SIZE*2 + i];
		C_a[i] = vecOut[IMGROW_SIZE*2 + i];
	}
	
	// Apply activation using CPU
	img_vecval_t Ct[HIDENV_SIZE];
	img_vecval_t Ht[HIDENV_SIZE];
	runActivation(Ia, Fa, Oa, C_a, Ct, Ht);
	
	// Then copy Ht into hiddenState[];
	// and copy Ct into cellState[] for the next iteration.
	for(int i=0; i<HIDENV_SIZE; ++i) {
		hiddenState[i] = Ht[i];
		cellState[i]   = Ct[i];
	}
}




int main()
{
    init_platform();
    print("\n\nINFO: Start of new session.\n");

    
    // Perform initialization and tests
    img_test();			// Tests if IMAGine is set up correctly
    load_ex02_params();	// Load the model parameter
    int misCount = test_ex02_kernel();	// Test using test-vectors
    if(misCount > 0) {
    	print("EROR: Kernel test failed, exiting ...\n");
    	return -1;
    }
    
    
    // Free-running application
    print("INFO: Starting free-running application\n");
    int16_t sensData[INPVEC_SIZE];
	img_vecval_t hiddenState[HIDENV_SIZE];
	img_vecval_t cellState[HIDENV_SIZE];
	int iterCount = 0;
    while(1) {
    	readSensor(sensData);
    	runLSTMCell(sensData, hiddenState, cellState);
    	// Do something with the hiddenState
    	xil_printf("  iteration: %d\n", iterCount);
    	++iterCount;
    }
	

    cleanup_platform();
    return 0;
}

