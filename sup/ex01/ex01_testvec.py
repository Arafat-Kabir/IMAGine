# This script exports the test vectors for the example
import numpy as np


# Script parameters
testCout   = 'out/ex01_testvec.c'
dataFile   = 'ex01_data.npz'


# ---- Load weights and biases from external file
npData = np.load(dataFile)
Vfxp = npData['Vfxp']
expOut = npData['expOut']   # expected output of A@V+B in fixed-point for testing


# Returns a C-array representation string of the given
# array arr, with varName as the variable name and
# typeName as the data type.
def makeCarray(arr, varName, typeName):
    lines = [f'{typeName} {varName}[] = {{']
    for e in arr:
        lines.append(f'  {e},')
    lines.append('};')
    lines.append(f'int {varName}_size = sizeof({varName})/sizeof({varName}[0]);')
    print(f'INFO: Built C-array for {varName}')
    return '\n'.join(lines)


# Export the expected output as C-array
header = '#include <stdint.h>'
with open(testCout, 'w') as fexp:
    testVec = makeCarray(Vfxp, 'ex01_testInp', 'int16_t')
    testOut = makeCarray(expOut, 'ex01_testOut', 'int16_t')
    fexp.write('\n\n\n'.join([header, testVec, testOut]))
print(f'INFO: Expected outputs C-array written to {testCout}')


