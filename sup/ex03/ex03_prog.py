# An assembly program for IMAGine
# Written for IMAGineAsm v0.x for testing.
import numpy as np

from imagine_assembler import *


# Load assembler parameters and compatability checks
assert imagine_as.v_major == 0
imagine_as.loadParams('imagine_64x64_params.yml')


# Script parameters
dataFile   = 'ex03_data.npz'
progHeader = 'out/imagine_prog.h'
loaderCout = 'out/ex03_loader.c'
kernelCout = 'out/ex03_kernel.c'


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
# 
# In this example we will compute Ia, Fa, Oa, and C_a in a single GEMV operation.
# This is only possible if we can concatenate all weight matrices into a single
# matrix with dimensions that fits in IMAGine. 
# The operation will look as follows,
#
#   Concatenated weights, biases, inputs, and outputs,
#     W  = | Wxi, Whi |
#          | Wxf, Whf |
#          | Wxo, Who |
#          | Wxc, Whc |
#
#     bb = | bi |
#          | bf |
#          | bi |
#          | bi |
# 
#     XH = | Xt, Hp |
#
#     Ra = | Ia  |
#          | Fa  |
#          | Oa  |
#          | C_a |
#
#   Operation on IMAGine,
#     Ra = W @ XH + bb


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

# Concatenate weights, biases, and inputs
Wx = np.concatenate((Wxi, Wxf, Wxo, Wxc), axis=0)   # stack rows
Wh = np.concatenate((Whi, Whf, Who, Whc), axis=0)   # stack rows
W  = np.concatenate((Wx, Wh), axis=1)               # append columns
bb = np.concatenate((bi, bf, bo, bc), axis=0)  # append elements
XH = np.concatenate((Xt, Hp), axis=0)          # append elements
print(f'INFO: Weights and biases concatenated')



# ---- Assembly program
# Allocate registers to assign meaningful names
regW  = 0
regbb = 1
regXH = 2
regRa = 10  # result register
# Temporary registers
regProd = 5
regAcum = 6


# load the weights and biases
mv_LOADMAT(regW, W);       as_addComment('Finished writing weights\n')
mv_LOADVEC_COL(regbb, bb); as_addComment('Finished writing biases\n')
mv_LOADVEC_ROW(regXH, XH); as_addComment('Finished writing test input vector\n')


# Export the loader program then reset for the kernel program
imagine_as.export_CprogHex('ex03_loader', loaderCout)
imagine_as.reset()


# Compute W @ XH + bb
vv_serialEn()       # enable serial-shifting for result collection
mv_MULTFXP(rd=regProd, multiplicand=regXH, multiplier=regW)
mv_ALLACCUM(rd=regAcum, rs=regProd)
mv_add(rd=regRa, rs1=regAcum, rs2=regbb)
mv_SYNC()           # Wait until the last MV instruction finishes
vv_parallelEn()     # start parallel shifting output vector


# Export the kernel program and the program header
imagine_as.export_CprogHex('ex03_kernel', kernelCout)
imagine_as.export_CprogHeader(progHeader)

