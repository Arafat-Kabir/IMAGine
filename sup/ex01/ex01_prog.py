# An assembly program for IMAGine
# Written for IMAGineAsm v0.x for testing.
import numpy as np

from imagine_assembler import *


# Load assembler parameters and compatability checks
assert imagine_as.v_major == 0
imagine_as.loadParams('imagine_64x64_params.yml')


# Script parameters
dataFile   = 'ex01_data.npz'
progHeader = 'out/imagine_prog.h'
loaderCout = 'out/ex01_loader.c'
kernelCout = 'out/ex01_kernel.c'
testCout   = 'out/ex01_testarr.c'


# ---- Load weights and biases from external file
npData = np.load(dataFile)
A = npData['A']
B = npData['B']
V = npData['V']
expOut = npData['expOut']   # expected output of A@V+B for testing
print(f'INFO: Weights and biases loaded from {dataFile}')


# Export the expected output as C-array (Optional, only needed for testing)
with open(testCout, 'w') as fexp:
    ftext = ['int16_t ex01_testarr[] = {\n']
    for e in expOut:
        ftext.append(f'  {e},\n')
    ftext.append('};\n')
    fexp.writelines(ftext)
print(f'INFO: Expected outputs C-array written to {testCout}')




# ---- Assembly program
# Allocate registers to assign meaningful names
regA = 0
regB = 1
regV = 2
regProd = 3     # the output of multfxp will be stored here
regAcum = 4     # result of accumulation will be stored here
regBSum = 5     # result of bias (B) addition will be stored here


# Progam to load the matrix and vector
mv_LOADMAT(reg=regA, matrix=A);     as_addComment('Finished writing matrix A\n')
mv_LOADVEC_COL(reg=regB, vector=B); as_addComment('Finished writing vector B as column\n')
mv_LOADVEC_ROW(reg=regV, vector=V); as_addComment('Finished writing vector V as rows\n')


# Export the loader program then reset for the kernel program
imagine_as.export_CprogHex('ex01_loader', loaderCout)
imagine_as.reset()


# Perform A@V + B
vv_serialEn()       # enable serial-shifting for result collection
mv_MULTFXP(rd=regProd, multiplicand=regV, multiplier=regA)  # compute A * V
mv_ALLACCUM(rd=regAcum, rs=regProd)            # compute A@V
mv_add(rd=regBSum, rs1=regAcum, rs2=regB)      # compute A@V + B

# Wait till the accumulation finishes, then start parallel shifting
mv_SYNC()
vv_parallelEn()


# Export the kernel program and the program header
imagine_as.export_CprogHex('ex01_kernel', kernelCout)
imagine_as.export_CprogHeader(progHeader)

