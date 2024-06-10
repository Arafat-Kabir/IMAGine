# This script exports the test vectors for the example
import numpy as np


# Script parameters
testCout   = 'out/ex02_testvec.c'
dataFile   = 'ex02_data.npz'


# ---- Load weights and biases from external file
npData = np.load(dataFile)
Xtfxp = npData['Xtfxp']
Hpfxp = npData['Hpfxp']
Ia_fxp = npData['Ia_fxp']
Fa_fxp = npData['Fa_fxp']
Oa_fxp = npData['Oa_fxp']
C_a_fxp = npData['C_a_fxp']
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
    print(f'INFO: Built C-array for {varName}')
    return '\n'.join(lines)


# Export the test vectors as C-arrays
header = '#include <stdint.h>'
with open(testCout, 'w') as fexp:
    testXt = makeCarray(Xtfxp, 'ex02_testXt', 'int16_t')
    testHp = makeCarray(Hpfxp, 'ex02_testHp', 'int16_t')
    Ia = makeCarray(Ia_fxp, 'ex02_IaFxp', 'int16_t')
    Fa = makeCarray(Fa_fxp, 'ex02_FaFxp', 'int16_t')
    Oa = makeCarray(Oa_fxp, 'ex02_OaFxp', 'int16_t')
    Ca = makeCarray(C_a_fxp, 'ex02_CaFxp', 'int16_t')
    fexp.write('\n\n\n'.join([header, testXt, testHp, Ia, Fa, Oa, Ca]))
print(f'INFO: Test vectors C-array written to {testCout}')


