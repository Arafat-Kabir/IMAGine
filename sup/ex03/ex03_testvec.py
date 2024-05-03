# This script exports the test vectors for the example
import numpy as np


# Script parameters
testCout   = 'out/ex03_testvec.c'
dataFile   = 'ex03_data.npz'


# ---- Load weights and biases from external file
npData = np.load(dataFile)
Xtfxp = npData['Xtfxp']
Hpfxp = npData['Hpfxp']
XHfxp = npData['XHfxp']
expOut = npData['expOut']   # expected output of A@V+B in fixed-point for testing


# Returns a C-array representation string of the given
# array arr, with varName as the variable name and
# typeName as the data type.
def makeCarray(arr, varName, typeName):
    lines = [f'{typeName} {varName}[] = {{']
    for e in arr:
        lines.append(f'  {e},')
    lines.append('};')
    lines.append(f'int {varName}_size = sizeof({varName})/sizeof({varName}[0]);');
    print(f'INFO: Built C-array for {varName}')
    return '\n'.join(lines)


# Export the test vectors as C-arrays
header = '#include <stdint.h>'
with open(testCout, 'w') as fexp:
    testXt = makeCarray(Xtfxp, 'ex03_testXt', 'int16_t')
    testHp = makeCarray(Hpfxp, 'ex03_testHp', 'int16_t')
    testXH = makeCarray(Hpfxp, 'ex03_testXH', 'int16_t')
    testOut = makeCarray(expOut, 'ex03_testOut', 'int16_t')
    fexp.write('\n\n\n'.join([header, testXt, testHp, testXH, testOut]))
print(f'INFO: Expected outputs C-array written to {testCout}')


