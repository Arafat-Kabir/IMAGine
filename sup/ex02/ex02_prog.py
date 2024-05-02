# An assembly program for IMAGine
# Written for IMAGineAsm v0.x for testing.
import numpy as np

from imagine_assembler import *


# Load assembler parameters and compatability checks
assert imagine_as.v_major == 0
imagine_as.loadParams('imagine_64x64_params.yml')


# Script parameters
dataFile   = 'ex02_data.npz'
progHeader = 'out/imagine_prog.h'
loaderCout = 'out/ex02_loader.c'
kernelCout = 'out/ex02_kernel.c'


# This example shows how to perform the GEMV operations involved
# in an LSTM cell. A single iteration of LSTM is computed as follows,
#   Here,
#     Xt = input vector for current iteration (element of a sequence)
#     Hp = H(t-1), the output of the previous iteration for input X(t-1)
#     Ht = the hidden state after current iteration for input Xt
#     Cp = C(t-1), cell state from previous iteration
#     Ct = cell state after current iteration for input Xt
#     @  = matrix-vector multiplication
#     *  = point-wise multiplication
#
#   LSTM cell operations
#     It  = sigmoid(Wxi @ Xt + Whi @ Hp + bi)
#     Ft  = sigmoid(Wxf @ Xt + Whf @ Hp + bf)
#     Ot  = sigmoid(Wxo @ Xt + Who @ Hp + bo)
#     C_t = tanh(Wxc @ Xt + Whc @ Hp + bc)
#     Ct  = Ft * Cp + It * C_t
#     Ht  = Ot * tanh(Ct)
#
# Because IMAGine is a GEMV engine, we'll only perform the matrix-vector
# operations on IMAGine. Rest of the operations will be performed by the CPU.
#
#   Operations on IMAGine,
#     Ia  = Wxi @ Xt + Whi @ Hp + bi
#     Fa  = Wxf @ Xt + Whf @ Hp + bf
#     Oa  = Wxo @ Xt + Who @ Hp + bo
#     C_a = Wxc @ Xt + Whc @ Hp + bc
#
#   Operations on CPU,
#     It  = sigmoid(Ia)
#     Ft  = sigmoid(Fa)
#     Ot  = sigmoid(Oa)
#     C_t = tanh(C_a)
#     Ct  = Ft * Cp + It * C_t
#     Ht  = Ot * tanh(Ct)


# ---- Load weights and biases from external file
npData = np.load(dataFile)
Wxi = npData['Wxi']
Wxf = npData['Wxf']
Wxo = npData['Wxo']
Wxc = npData['Wxc']
Whi = npData['Whi']
Whf = npData['Whf']
Who = npData['Who']
Whc = npData['Whc']

bi = npData['bi']
bf = npData['bf']
bo = npData['bo']
bc = npData['bc']

# load inputs (this is only for testing)
Xt = npData['Xt']
Hp = npData['Hp']
print(f'INFO: Weights and biases loaded from {dataFile}')




# ---- Assembly program
# Allocate registers to assign meaningful names
regWxi = 0; regWxf = 1; regWxo = 2;  regWxc = 3
regWhi = 4; regWhf = 5; regWho = 6;  regWhc = 7
regbi  = 8; regbf  = 9; regbo  = 10; regbc  = 11
# input registers
regXt  = 20
regHp  = 21
# Temporary registers
regProd  = 22
regAcumX = 23   # accumulation of Wx @ Xt
regAcumH = 24   # accumulation of Wh @ Hp
# result registers
regIa  = 30
regFa  = 31
regOa  = 32
regC_a = 33


# load the weights and biases
mv_LOADMAT(regWxi, Wxi)
mv_LOADMAT(regWxf, Wxf)
mv_LOADMAT(regWxo, Wxo)
mv_LOADMAT(regWxc, Wxc)
mv_LOADMAT(regWhi, Whi)
mv_LOADMAT(regWhf, Whf)
mv_LOADMAT(regWho, Who)
mv_LOADMAT(regWhc, Whc)
as_addComment('Finished writing weights\n')

mv_LOADVEC_COL(regbi, bi)
mv_LOADVEC_COL(regbf, bf)
mv_LOADVEC_COL(regbo, bo)
mv_LOADVEC_COL(regbc, bc)
as_addComment('Finished writing biases\n')

# load inputs (this is only for testing)
mv_LOADVEC_ROW(regXt, Xt)
mv_LOADVEC_ROW(regHp, Hp)
as_addComment('Finished writing input vector\n')


# Export the loader program then reset for the kernel program
imagine_as.export_CprogHex('ex02_loader', loaderCout)
imagine_as.reset()


# Convenience macro to compute LST gate output before activation.
# It overwrites temporary registers regProd, regAcumX, regAcumH,
# and reads from regXt and regHp.
# operation: regDest = regWx @ regXt + regWh @ regHp + regb
def computeGate(regDest, regWx, regWh, regb):
  mv_MULTFXP(rd=regProd, multiplicand=regXt, multiplier=regWx)
  mv_ALLACCUM(rd=regAcumX, rs=regProd)
  mv_MULTFXP(rd=regProd, multiplicand=regHp, multiplier=regWh)
  mv_ALLACCUM(rd=regAcumH, rs=regProd)
  mv_add(rd=regDest, rs1=regAcumX, rs2=regAcumH)
  mv_add(rd=regDest, rs1=regDest, rs2=regb)


# Compute Ia then push it to FIFO out
vv_serialEn()       # enable serial-shifting for result collection
computeGate(regIa,  regWxi, regWhi, regbi)
mv_SYNC()
vv_parallelEn()     # this disables serial-shifting
vv_SYNC()

# Compute Fa then push it to FIFO out
vv_serialEn()       # renable serial-shifting for result collection
computeGate(regFa,  regWxf, regWhf, regbf)
mv_SYNC()
vv_parallelEn()     # this disables serial-shifting
vv_SYNC()

# Compute Oa then push it to FIFO out
vv_serialEn()       # renable serial-shifting for result collection
computeGate(regOa,  regWxo, regWho, regbo)
mv_SYNC()
vv_parallelEn()     # this disables serial-shifting
vv_SYNC()

# Compute C_a then push it to FIFO out
vv_serialEn()       # renable serial-shifting for result collection
computeGate(regC_a, regWxc, regWhc, regbc)
mv_SYNC()
vv_parallelEn()
vv_SYNC()


# Export the kernel program and the program header
imagine_as.export_CprogHex('ex02_kernel', kernelCout)
imagine_as.export_CprogHeader(progHeader)

