#include <xparameters.h>
#include <imagine_gemv.h>
#include <xil_printf.h>
#include "imagine_driver.h"


// Alias for base address and register offsets
#define IMG_BASEADDR  XPAR_IMAGINE_GEMV_0_S00_AXI_BASEADDR
#define REG0  IMAGINE_GEMV_S00_AXI_SLV_REG0_OFFSET
#define REG1  IMAGINE_GEMV_S00_AXI_SLV_REG1_OFFSET
#define REG2  IMAGINE_GEMV_S00_AXI_SLV_REG2_OFFSET
#define REG3  IMAGINE_GEMV_S00_AXI_SLV_REG3_OFFSET
#define REG4  IMAGINE_GEMV_S00_AXI_SLV_REG4_OFFSET
#define REG5  IMAGINE_GEMV_S00_AXI_SLV_REG5_OFFSET
#define REG6  IMAGINE_GEMV_S00_AXI_SLV_REG6_OFFSET
#define REG7  IMAGINE_GEMV_S00_AXI_SLV_REG7_OFFSET
#define REG8  IMAGINE_GEMV_S00_AXI_SLV_REG8_OFFSET
#define REG9  IMAGINE_GEMV_S00_AXI_SLV_REG9_OFFSET
#define REG10 IMAGINE_GEMV_S00_AXI_SLV_REG10_OFFSET
#define REG11 IMAGINE_GEMV_S00_AXI_SLV_REG11_OFFSET
#define REG12 IMAGINE_GEMV_S00_AXI_SLV_REG12_OFFSET
#define REG13 IMAGINE_GEMV_S00_AXI_SLV_REG13_OFFSET
#define REG14 IMAGINE_GEMV_S00_AXI_SLV_REG14_OFFSET
#define REG15 IMAGINE_GEMV_S00_AXI_SLV_REG15_OFFSET


// Bit masks for status and control registers
// slv_reg1 (FIFO control register)
#define BIT_FIFO_RST   (1u << 0)
#define BIT_FINP_WR    (1u << 1)
#define BIT_FOUT_RD    (1u << 2)
// slv_reg2 (IMAGine control register)
#define BIT_IMG_CLREOV (1u << 0)
// slv_reg9 (FIFO status register)
#define BIT_FINP_FULL  (1u << 0)
#define BIT_FOUT_VALID (1u << 1)
// slv_reg10 (IMAGine status register)
#define BIT_IMG_EOVINT (1u << 0)


// Register read-write utilities
static inline
uint32_t readImgReg(uintptr_t regOffset)
{
	return *(volatile uint32_t *) (IMG_BASEADDR + regOffset);
}

static inline
void writeImgReg(uintptr_t regOffset, uint32_t data)
{
	volatile uint32_t *addr = (volatile uint32_t *)(IMG_BASEADDR + regOffset);
	*addr = data;
}



// AK-NOTE: Following register map is taken from the IP verilog
// imagine-ip input register map:
// finp-data input    : reg0
// fifo-control reg   : reg1 (bit control)
// imagine-control reg: reg2 (bit control)
// reserved R/W regs  : reg 3-7

// imagine-ip output register map:
// fout-data output      : reg8
// fifo-status reg       : reg9
// imagine-status reg    : reg10
// reserved readonly regs: reg 11-15


// writes to FIFO-in data register
static inline
void img_writeFinpData(uint32_t data) {
	writeImgReg(REG0, data);
}


// generates FIFO-in write pulse
static inline
void img_genFinpWrPulse() {
	uint32_t ctrl = readImgReg(REG1);		// read current register content
	writeImgReg(REG1, ctrl | BIT_FINP_WR);	// set the pulse-gen bit
	writeImgReg(REG1, ctrl & ~BIT_FINP_WR);	// clear the pulse-gen bit
}


// generates FIFO-out read pulse
static inline
void img_genFoutRdPulse() {
	uint32_t ctrl = readImgReg(REG1);		// read current register content
	writeImgReg(REG1, ctrl | BIT_FOUT_RD);	// set the pulse-gen bit
	writeImgReg(REG1, ctrl & ~BIT_FOUT_RD);	// clear the pulse-gen bit
}


// Reads the FIFO-out data output register
static inline
uint32_t img_readFoutData() {
	return readImgReg(REG8);
}


// Reads the FIFO status register
static inline
uint32_t img_readStatusFifo() {
	return readImgReg(REG9);
}


// Reads imagine-status register
static inline
uint32_t img_readStatusIMAGine() {
	return readImgReg(REG10);
}


// returns true if FIFO-in is full
static inline
bool img_isFinpFull() {
	return (img_readStatusFifo() & BIT_FINP_FULL) != 0;
}


// returns true if FIFO-out data is valid
static inline
bool img_isFoutValid() {
	return (img_readStatusFifo() & BIT_FOUT_VALID) != 0;
}


// returns true if IMAGine eovInterrupt is set
static inline
bool img_isEovSet() {
	return (img_readStatusIMAGine() & BIT_IMG_EOVINT) != 0;
}




// ---- User APIs
// Pushes an instruction into the FIFO-in (waits if full)
void img_pushInstruction(uint32_t instr) {
	// wait if FIFO-in full
	while(img_isFinpFull()) print("img_pushInstruction: FIFO-in full, waiting ...\n");
	// write to FIFO-in data register
	img_writeFinpData(instr);
	// generate FIFO-in write pulse
	img_genFinpWrPulse();
}


// Returns true if IMAGine eovInterrupt is set (Alias to img_EovSet())
bool img_isEOV() {
	return img_isEovSet();
}


// Returns the FIFO-out data if valid
IMAGine_Dout img_popData() {
	IMAGine_Dout dout;
	// check if FIFO-out valid
	if(!img_isFoutValid()) {
		dout.status = IMAGINE_DOUT_INVALID;
		return dout;
	}
	// read FIFO-out data
	uint32_t foutData = img_readFoutData();
	// generate FIFO-out read pulse
	img_genFoutRdPulse();
	// build the return value
	dout.status = IMAGINE_DOUT_VALID;
	dout.data   = (int16_t)(foutData & 0xFFFF);	 // only lower 16-bits hold the data
	dout.attrib = (uint8_t)(foutData >> 24);	 // upper 8-bits hold the data attributes
	return dout;
}


// place-holder function, can contain anything
void img_test() {
	// test register read/write
	xil_printf("REG0 : %X\n", readImgReg(REG0));
	xil_printf("REG15: %X\n", readImgReg(REG15));

	writeImgReg(REG0, 0xFEEDBEEF);
	xil_printf("REG0 : %X\n", readImgReg(REG0));
	xil_printf("REG15: %X\n", readImgReg(REG15));

	img_writeFinpData(0xDEAFCAFE);
	xil_printf("REG0 : %X\n", readImgReg(REG0));
	xil_printf("REG15: %X\n", readImgReg(REG15));
}
