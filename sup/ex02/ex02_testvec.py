# This script exports the test vectors for the example
import numpy as np


# Script parameters
testCout   = 'out/ex02_testvec.c'
dataFile   = 'ex02_data.npz'


# ---- Load weights and biases from external file
npData = np.load(dataFile)
Xtfxp = npData['Xtfxp']
Hpfxp = npData['Hpfxp']
expOut = npData['expOut']   # expected output in fixed-point for testing


# Returns a C-array representation string of the given
# array arr, with varName as the variable name and
# typeName as the data type.
def makeCarray(arr, varName, typeName):
    lines = [f'{typeName} {varName}[] = {{']
    for e in arr:
        lines.append(f'  {e},')
    lines.append('};')
    lines.append(f'int {varName}_size = sizeof({varName})/sizeof({varName}[0]);');
    return '\n'.join(lines)


# Export the expected output as C-array
with open(testCout, 'w') as fexp:
    testXt = makeCarray(Xtfxp, 'ex02_testXt', 'int16_t')
    testHp = makeCarray(Hpfxp, 'ex02_testHp', 'int16_t')
    testOut = makeCarray(expOut, 'ex02_testOut', 'int16_t')
    fexp.write('\n\n\n'.join([testXt, testHp, testOut]))
print(f'INFO: Expected outputs C-array written to {testCout}')


