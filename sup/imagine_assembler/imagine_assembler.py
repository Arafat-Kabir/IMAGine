#===================================================================================#
#   Copyright (c) 2024, Computer Systems Design Lab, University of Arkansas         #
#                                                                                   #
#   All rights reserved.                                                            #
#                                                                                   #
#   Permission is hereby granted, free of charge, to any person obtaining a copy    #
#   of this software and associated documentation files (the "Software"), to deal   #
#   in the Software without restriction, including without limitation the rights    #
#   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell       #
#   copies of the Software, and to permit persons to whom the Software is           #
#   furnished to do so, subject to the following conditions:                        #
#                                                                                   #
#   The above copyright notice and this permission notice shall be included in all  #
#   copies or substantial portions of the Software.                                 #
#                                                                                   #
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR      #
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,        #
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE     #
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER          #
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,   #
#   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE   #
#   SOFTWARE.                                                                       #
#===================================================================================#

#================================================================================#
#                                                                                #
#   Author : MD Arafat Kabir                                                     #
#   Email  : arafat.sun@gmail.com                                                #
#   Date   : Mon, Mar 04, 04:18 PM CST 2024                                      #
#   Version: v0.1                                                                #
#                                                                                #
#   Description:                                                                 #
#   This is a python module that implements a basic assembler for IMAGine IR3    #
#   instruction-set.  Because this is a python module, the assembly programs can #
#   be written as a python script. As a result, you get some convenient features #
#   directly from python, like macros (functions), use of external modules,      #
#   complicated computation within the assembly program (python script), etc.    #                                                   
#                                                                                #
#================================================================================#

import math
import numpy as np
import yaml
from string import Template
from copy import deepcopy




# C-program template strings
c_header_name = 'imagine_prog.h'
c_header_text = '''#ifndef IMAGINE_PROG_H
#define IMAGINE_PROG_H


#include <stdint.h>

typedef struct {
    const uint32_t * const instruction;
    const int size;
    // target IMAGine configuration of the program
    const int fracWidth;
    const int mvMaxRow;
    const int mvMaxCol;
    const int regWidth;
    const int idWidth;
    const int peCount;
} IMAGine_Prog;


#endif  // IMAGINE_PROG_H
'''

c_prog_template = Template(f'''#include "{c_header_name}"


static const uint32_t word_arr[] = {{
$instructions
}};


IMAGine_Prog $progname = {{
    word_arr,
    sizeof(word_arr)/sizeof(word_arr[0]),   // size
    $fracWidth,    // fracWidth
    $mvMaxRow,   // mvMaxRow
    $mvMaxCol,   // mvMaxCol
    $regWidth,   // regWidth
    $idWidth,    // idWidth
    $peCount,   // peCount
}};
''')


# IR3 instruction format:
# [sub-module-code] [sub-module-instruction] 
# [2-bit]           [30-bit]
# total: 32-bit instruction word


class IMAGineAsm:
    # Module information
    v_major = 0
    v_minor = 1
    author  = 'MD Arafat Kabir (arafat.sun@gmail.com, makabir@uark.edu)'
    cpright = 'Copyright (c) 2024, Computer Systems Design Lab, University of Arkansas'

    # build and print invocation header
    invoc_header = [
        f'IMAGine IR3 Assember (IMAGineAsm) version {v_major}.{v_minor}',
        f'Author: {author}',
        cpright,
        ''
    ]


    # Tables for machine-code generation
    tbl_submCode = {
        'mv' : 0,
        'vv' : 1,
        'as' : -1,  # a dummy submodule for the assembler itself
    }

    tbl_field_width = {
        'submCode'  : 2,    # width of the submodule-code field
        'submInstr' : 30,   # width of the submodule-instruction field
    }

    tbl_vecshift_opcode = {
       'idle'        : 0,
       'serial_en'   : 1,
       'parallel_en' : 2,
       'disable'     : 3,
    }

    # Import submodule assemblers
    from picaso_assembler import PiCaSOAsm


    # Class implementation
    def __init__(self):
        self.instructions = []        # will contain internal representation of each instruction
        self.isAssembled = False      # state flag, set to True after assemble
        self.picaso_as = self.PiCaSOAsm()  # PiCaSO assembler instance
        self.setupParams()            # setup default parameter values


    # ---- Development utils: following functions are used in the development of this module

    # Prints a message when an instruction is called which is not implemented yet
    def _instrNotImpl(self, name):
        print(f"WARN: {name} is not implemented yet, skipping")


    def printCopyright(self):
        for line in self.invoc_header: print(line)


    def printParams(self, indent=''):
        print(f'{indent}fracWidth  : {self.fracWidth}')
        print(f'{indent}mvMaxRow   : {self.mvMaxRow}')
        print(f'{indent}mvMaxCol   : {self.mvMaxCol}')
        print(f'{indent}resvRegCnt : {self.resvRegCnt}')
        print(f'{indent}resvRegBase: {self.resvRegBase}')
        print(f'{indent}PiCaSOAsm Params:')
        self.picaso_as.printParams(indent=indent+'  ')


    # Given the mnemonic for the vecshift submodule, returns the 30-bit
    # instruction word segment dictionary
    # Format:
    #   - The 30-bit instruction has same format at 30-bit picaso instrurction
    #     [SEG2] [SEG1] [SEG0]
    #   - SEG0 and SEG1 is don't care, the vecshift opcode goes into SEG2 (opcode field)
    def vecshift_instrSegs(self, mnemonic):
        assert mnemonic in self.tbl_vecshift_opcode, f'EROR: Invalid opcode for vecshift submodule: {mnemonic}' 
        segDict = {'seg2' : self.tbl_vecshift_opcode[mnemonic],
                   'seg1' : 0,
                   'seg0' : 0}
        return segDict


    # Given a segment dictionary (segDict) of vecshift-reg submodule,
    # returns a list of segments (in order) for IR3 machine code generation
    def vecshift_seg2list(self, segDict):
        opcode = segDict['seg2']
        unused = segDict['seg1'] << self.picaso_as.tbl_field_width['seg1']
        unused |= segDict['seg0']
        w_opcode = self.picaso_as.tbl_field_width['seg2']
        w_unused = self.picaso_as.tbl_field_width['seg1'] + self.picaso_as.tbl_field_width['seg0']
        return [(opcode, w_opcode), (unused, w_unused)]     # unused segments are merged together


    # Given an instruction dictionary (internal representation) of a macro
    # instruction, returns a list of submSegments (definition in genMachineCode())
    def vecshift_genMacro(self, instrDict):
        assert 'macro' in instrDict, f'Instruction is not a macro: {instrDict}'
        macroName = instrDict['macro']
        llSegment = []      # list of submodule segment-lists (ordered)
        if macroName == 'sync':
            # 1 NOP is needed to create a synchronization barrier
            segDict = self.vecshift_instrSegs('idle')
            llSegment.append(self.vecshift_seg2list(segDict))
        else:
            assert 0, 'vecshift submodule does not implement a macro named: {macroName}'
        return llSegment


    # Given a segment dictionary (segDict) of GEMV array (picaso instruction)
    # submodule, returns a list of segments (in order) for IR3 machine code generation
    def gemv_seg2list(self, segDict):
        w_seg0 = self.picaso_as.tbl_field_width['seg0']
        w_seg1 = self.picaso_as.tbl_field_width['seg1']
        w_seg2 = self.picaso_as.tbl_field_width['seg2']
        return [(segDict['seg2'], w_seg2), (segDict['seg1'], w_seg1), (segDict['seg0'], w_seg0)]


    # Given an instruction dictionary (internal representation) of a macro
    # instruction, returns a list of submSegments (definition in genMachineCode())
    def gemv_genMacro(self, instrDict):
        assert 'macro' in instrDict, f'Instruction is not a macro: {instrDict}'
        macroName = instrDict['macro']
        llSegment = []      # list of submodule segment-lists (ordered)
        if macroName == 'sync':
            # 2 NOPs are needed to create a synchronization barrier
            picaso_nop = {'opcode' : 'nop'}      # picaso-ir for NOP
            segDict = self.picaso_as.genMachineCode(picaso_nop)
            segList = self.gemv_seg2list(segDict)
            llSegment.append(segList)
            llSegment.append(segList)
        elif macroName == 'mult':
            # multiplication works as follows,
            #  - clearmbit: clear the multiplier bit storage in booth's ALU
            #  - execute updatepp for all bits of multiplier, lsb to msb
            picaso_clearmbit = {'opcode' : 'superop', 'scode' : 'clrmbit'}
            picaso_updatepp  = {'opcode' : 'updatepp', 'offset' : None, 
                                'rd'  : instrDict['rd'], 
                                'rs1' : instrDict['multiplier'], 
                                'rs2' : instrDict['multiplicand']}
            # push clearmbit instruction
            segList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_clearmbit) )
            llSegment.append(segList)
            # push updatepp instruction for all multiplier bits
            for bitNo in range(self.picaso_as.regWidth):
                picaso_updatepp['offset'] = bitNo
                segList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_updatepp) )
                llSegment.append(segList)
        elif macroName == 'blockAccum':
            # block-level accumulation works as follows,
            #  - apply fold=1 from source reg to destination reg
            #  - apply rest of the folds on the destination reg
            picaso_accumblk = {'opcode' : 'accum', 'fncode' : 'accum_blk', 
                               'param' : 1,
                               'rs1' : instrDict['rs'],
                               'rs2' : instrDict['rd'],
                               'comment' : 'NOTE: First fold'}
            # push first fold
            segList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_accumblk) )
            llSegment.append(segList)
            # push rest of the folds on destination reg
            picaso_accumblk['rs1'] = instrDict['rd']
            for f in range(2, self.picaso_as.maxFold+1):
                picaso_accumblk['param'] = f
                segList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_accumblk) )
                llSegment.append(segList)
        elif macroName == 'clearReg':
            # clearReg works as follows,
            #  - select all blocks
            #  - write zeros to all rows of the specified register
            # get/build picaso IR to generate machine codes
            picaso_selectAll = self.picaso_as.instSelectAll()   # get the picaso-ir
            picaso_write = {'opcode' : 'write', 'addr' : None, 'data' : None}
            # push the selectAll() instruction
            segList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_selectAll) )
            llSegment.append(segList)
            # push the write instructions
            ptrReg = self.picaso_as.makeRegAddr(instrDict['reg'])   # get the register base address
            for i in range(self.picaso_as.regWidth):
                picaso_write['addr'] = ptrReg
                picaso_write['data'] = 0
                segList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_write) )
                llSegment.append(segList)
                ptrReg += 1     # point to the next bit of the register
        elif macroName == 'loadMat':
            # write block images corresponding to the given matrix
            #   - select a block using row-col ID, 
            #   - write all wordlines corresponding to the given register
            # generate block images
            bramArr = imagine_as.makePe2BramMat(instrDict['matrix'])
            # build picaso IR to generate machine codes
            picaso_selblk = {'opcode' : 'select', 'fncode' : 'sel_block',
                             'rowID' : None, 'colID' : None}
            picaso_write = {'opcode' : 'write', 'addr' : None, 'data' : None}
            # generate write instructions per BRAM block
            for r, bramRow in enumerate(bramArr):
                for c, bram in enumerate(bramRow): 
                    # Select the block
                    picaso_selblk['rowID'] = r
                    picaso_selblk['colID'] = c
                    selectSegList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_selblk) )
                    # selection instruction is compiled but will not be queued until a valid write is found: llSegment.append(selectSegList)
                    # Write data to the given register
                    isFirstWrite = True
                    ptrReg = self.picaso_as.makeRegAddr(instrDict['reg'])   # get the register base address
                    assert len(bram) == self.picaso_as.regWidth, f'BRAM image for loadMat contains unexpected no. of rows: {len(bram)} != {self.picaso_as.regWidth}'
                    for data in bram:
                        # Write the data if non-zero (this optimizaiton assumes the register has been already cleared calling mv_macroClearReg)
                        if data != 0:
                            # Select the block if a non-zero data is found for the first time
                            if isFirstWrite: 
                                llSegment.append(selectSegList)
                                isFirstWrite = False
                            picaso_write['addr'] = ptrReg
                            picaso_write['data'] = data
                            segList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_write) )
                            llSegment.append(segList)
                        ptrReg += 1     # point to the next bit of the register
        elif macroName == 'loadVecRow':
            # write block images corresponding to the given vector
            #   - select a column of picaso-blocks using colID
            #   - write all wordlines corresponding to the given register
            # generate block images
            bramRow = imagine_as.makePe2BramVec(instrDict['vector'])
            # build picaso IR to generate machine codes
            picaso_selcol = {'opcode' : 'select', 'fncode' : 'sel_col',
                             'rowID' : 0, 'colID' : None}
            picaso_write = {'opcode' : 'write', 'addr' : None, 'data' : None}
            # generate write instructions per BRAM column
            for c, bram in enumerate(bramRow): 
                # Select the column
                picaso_selcol['colID'] = c
                selectSegList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_selcol) )
                # selection instruction is compiled but will not be queued until a valid write is found: llSegment.append(selectSegList)
                # Write data to the given register
                isFirstWrite = True
                ptrReg = self.picaso_as.makeRegAddr(instrDict['reg'])   # get the register base address
                assert len(bram) == self.picaso_as.regWidth, f'BRAM image for loadVecRow contains unexpected no. of rows: {len(bram)} != {self.picaso_as.regWidth}'
                for data in bram:
                    # Write the data if non-zero (this optimizaiton assumes the register has been already cleared calling mv_macroClearReg)
                    if data != 0:
                        # Select the column if a non-zero data is found for the first time
                        if isFirstWrite: 
                            llSegment.append(selectSegList)
                            isFirstWrite = False
                        picaso_write['addr'] = ptrReg
                        picaso_write['data'] = data
                        segList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_write) )
                        llSegment.append(segList)
                    ptrReg += 1     # point to the next bit of the register
        elif macroName == 'loadVecCol':
            # write block images corresponding to the given vector
            #   - select a row of picaso-blocks using rowID
            #   - write all wordlines corresponding to the given register
            # generate block images for the column vector
            bramCol = imagine_as.makePe2BramColVec(instrDict['vector'])
            # build picaso IR to generate machine codes
            picaso_selrow = {'opcode' : 'select', 'fncode' : 'sel_row',
                             'rowID' : None, 'colID' : 0}
            picaso_write = {'opcode' : 'write', 'addr' : None, 'data' : None}
            # generate write instructions per BRAM column
            for r, bram in enumerate(bramCol): 
                # Select the column
                picaso_selrow['rowID'] = r
                selectSegList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_selrow) )
                # selection instruction is compiled but will not be queued until a valid write is found: llSegment.append(selectSegList)
                # Write data to the given register
                isFirstWrite = True
                ptrReg = self.picaso_as.makeRegAddr(instrDict['reg'])   # get the register base address
                assert len(bram) == self.picaso_as.regWidth, f'BRAM image for loadVecCol contains unexpected no. of rows: {len(bram)} != {self.picaso_as.regWidth}'
                for data in bram:
                    # Write the data if non-zero (this optimizaiton assumes the register has been already cleared calling mv_macroClearReg)
                    if data != 0:
                        # Select the row if a non-zero data is found for the first time
                        if isFirstWrite: 
                            llSegment.append(selectSegList)
                            isFirstWrite = False
                        picaso_write['addr'] = ptrReg
                        picaso_write['data'] = data
                        segList = self.gemv_seg2list( self.picaso_as.genMachineCode(picaso_write) )
                        llSegment.append(segList)
                    ptrReg += 1     # point to the next bit of the register
        else:
            assert 0, f'GEMV-array submodule does not implement a macro named: {macroName}'
        return llSegment


    # Given an instruction dictionary (internal representation), Returns the
    # machine code as a dictionary of instruction-word segments (assembly)
    # The format of assembly: {
    #   'submCode' : num, 
    #   'type': macro/builtin/pseudo,    # indicates if this is a macro, built-in, or pseudo instruction
    #   'submSegments': [list of (code, code-width)]/None,  # None if type == macro, list of encoded segments of built-in instruction of the submodule
    #   'submWordList': [list of submSegments]/None,        # None if type == instr, list of (ordered list of segment encoding) of macro instruction for the submodule
    # }
    def genMachineCode(self, instrDict):
        submName = instrDict['submodule']
        submCode = self.tbl_submCode[submName]
        if submCode < 0: return {'submCode' : submCode, 'type' : 'pseudo'}   # no machine code is generated for dummy submodule
        isMacro  = 'macro' in instrDict     # check if it's a macro
        instrType = 'macro' if isMacro else 'builtin'
        if submName == 'mv':
            if isMacro:
                submSegments = None
                submWordList = self.gemv_genMacro(instrDict)
            else:
                segDict = self.picaso_as.genMachineCode(instrDict['ir'])
                submSegments = self.gemv_seg2list(segDict)  # get ordered list of segments
                submWordList = None     # not a macro
        elif submName == 'vv':
            if isMacro:
                submSegments = None
                submWordList = self.vecshift_genMacro(instrDict)
            else:
                segDict = self.vecshift_instrSegs(instrDict['opcode'])
                submSegments = self.vecshift_seg2list(segDict)  # get ordered list of segments
                submWordList = None     # not a macro
        else:
            if submName in self.tbl_submCode:
                assert 0, f'Submodule code generation not implemented yet, sumbName: {submName}'
        # build the word dictionary and return
        assembly = {
            'submCode' : submCode, 
            'type'     : instrType, 
            'submSegments' : submSegments, 
            'submWordList' : submWordList,
        }
        return assembly


    # Given an assembled instruction, returns a binary text for exporting it to output program
    def makeExportBinText(self, instr, addCmt, addSrc, sep):
        assert 'assembly' in instr, f'Instruction is not assembled: {instr}'
        # build the binary machine code for the instruction
        binwords = self.makeBinWord(instr['assembly'], sep=sep)
        # build inline comment
        inlnCmt = self.makeInstrMetaInfo(instr, addCmt, addSrc)
        # build the return text
        isMacro  = 'macro' in instr     # check if it's a macro
        outText  = None
        if isMacro:
            # Handle macro instructions
            outText = []
            if addCmt: outText.append(self.makeComment('---- MACRO: ' + inlnCmt))     # start of macro marker
            outText.append('\n'.join(binwords))     # each word in its own line
            if addCmt: outText.append(self.makeComment('---- End of MACRO'))
            outText = '\n'.join(outText)
        else:
            # Handle builtin instructions
            if inlnCmt: 
                inlnCmt = self.makeComment(inlnCmt)
                outText = '  '.join([binwords[0], inlnCmt])
            else:
                outText = binwords[0]
        return outText


    # Given an assembled instruction, returns a binary text for exporting it to output program
    # Parameters:
    #   word_suffix: string to put after hex-word (usually comma required for C-arrays)
    #   indent     : string to put before hex-word (usually a few spaces as indent)
    def makeExportHexText(self, instr, addCmt, addSrc, word_suffix='', indent=''):
        assert 'assembly' in instr, f'Instruction is not assembled: {instr}'
        # build the binary machine code for the instruction
        hexwords = self.makeHexWord(instr['assembly'], suffix=word_suffix, indent=indent)
        # build inline comment
        inlnCmt = self.makeInstrMetaInfo(instr, addCmt, addSrc)
        # build the return text
        isMacro  = 'macro' in instr     # check if it's a macro
        outText  = None
        if isMacro:
            # Handle macro instructions
            outText = []
            if addCmt: outText.append(indent + self.makeComment('---- MACRO: ' + inlnCmt))     # start of macro marker
            outText.append(f'\n'.join(hexwords))     # each word in its own line
            if addCmt: outText.append(indent + self.makeComment('---- End of MACRO'))
            outText = '\n'.join(outText)
        else:
            # Handle builtin instructions
            if inlnCmt: 
                inlnCmt = self.makeComment(inlnCmt)
                outText = '  '.join([hexwords[0], inlnCmt])
            else:
                outText = hexwords[0]
        return outText


    # Given an instruction and options, returns a string with meta information of the instruction
    def makeInstrMetaInfo(self, instr, addCmt, addSrc):
        metainfo = []
        if addSrc: metainfo.append(instr['src'])        # add source instruction if requested
        if addCmt and instr['comment']: metainfo.append(instr['comment'])   # add user comments if requested
        if metainfo: metainfo = '; '.join(metainfo)
        else: metainfo = ''
        return metainfo


    # Given a pseudo-instruction and options, returns a string for export
    def makeExportPseudoText(self, instr, addCmt, addSrc):
        # Right now there is only one pseudo-instruction: as_addComment()
        if addCmt: return self.makeComment(instr['comment'])
        else: return None


    # converts the provided text into inline comment for exporting
    def makeComment(self, text):
        return f'// {text}'

    
    # Given an instruction assembly, returns a list of binary encoding strings
    # with optional separator between instruction segments
    def makeBinWord(self, assembly, sep=''):
        instrType  = assembly['type']
        submcode   = assembly['submCode']
        w_submcode = self.tbl_field_width['submCode']
        # build the binary encoding string
        if instrType == 'builtin':
            binword = [f'{submcode:0{w_submcode}b}']
            for code, w_code in assembly['submSegments']:
                binword.append(f'{code:0{w_code}b}')
            return [sep.join(binword)]    # returns a list of single string
        # build a list of binary encoding strings of the macro instruction
        elif instrType == 'macro':
            macro_words = []
            for seglist in assembly['submWordList']:
                binword = [f'{submcode:0{w_submcode}b}']
                for code, w_code in seglist:
                    binword.append(f'{code:0{w_code}b}')
                macro_words.append(sep.join(binword))
            return macro_words  # returns a list of strings
        else:
            assert 0, f'Invalid assembly type: {assembly["type"]}'


    # Given an instruction assembly, returns a list of hex encoding strings
    # with optional indent and suffix
    def makeHexWord(self, assembly, suffix='', indent=''):
        instrType   = assembly['type']
        submcode    = assembly['submCode']
        w_submcode  = self.tbl_field_width['submCode']
        w_subminstr = self.tbl_field_width['submInstr']
        w_totinstr  = w_submcode + w_subminstr
        w_hexinstr  = int(math.ceil(w_totinstr/4))  # width of the hex instruction string
        # build the binary encoding string
        if instrType == 'builtin':
            word = submcode
            for code, w_code in assembly['submSegments']:
                word = (word << w_code) | code
            return [f'{indent}0x{word:0{w_hexinstr}X}{suffix}']    # returns a list of single string
        # build a list of binary encoding strings of the macro instruction
        elif instrType == 'macro':
            macro_words = []
            for seglist in assembly['submWordList']:
                word = submcode
                for code, w_code in seglist:
                    word = (word << w_code) | code
                macro_words.append(f'{indent}0x{word:0{w_hexinstr}X}{suffix}')
            return macro_words  # returns a list of strings
        else:
            assert 0, f'Invalid assembly type: {assembly["type"]}'


    # Given an array of numbers <= to the no. of PEs in a block,
    # returns a bit-level transposed array (columnal layout).
    def makePe2BramBlock(self, block):
        arrLen = len(block)
        peCount = self.picaso_as.peCount
        regWidth = self.picaso_as.regWidth
        assert len(block) <= peCount, f'Given block has more elements ({arrLen}) than PEs in a PiCaSO block ({peCount})'
        outArr = [0] * regWidth
        # transpose the bits
        for bitNo in range(regWidth):
            for peNo in range(arrLen):
                peBit = (block[peNo] >> bitNo) & 1   # extract the bit from the pe-register
                outArr[bitNo] |= peBit << peNo       # put the bit into its rightful place in BRAM row
        return outArr


    # Given a row-vector that maps to the conceptual layout of the PE-row
    # returns the corresponding array of bram images.
    def makePe2BramVec(self, vec):
        outBramArr = []
        peCount = self.picaso_as.peCount
        upbound = len(vec)
        for i in range(0, len(vec), peCount):
            eslice = min(upbound, i+peCount)    # end of slice
            block = vec[i:eslice]
            outBramArr.append(self.makePe2BramBlock(block))
        return outBramArr


    # Given a column-vector that maps to the conceptual layout of the PE-column
    # returns the corresponding array of bram images.
    def makePe2BramColVec(self, vec):
        outBramArr = []
        peCount = self.picaso_as.peCount
        for i in range(len(vec)):
            block = [vec[i]] * peCount   # Meaning: select an vector element, copy into all PEs in the row of the PIM block
            outBramArr.append(self.makePe2BramBlock(block))
        return outBramArr


    # Given a matrix that maps to the conceptual layout of the PE-array
    # returns the corresponding 2D array of bram images.
    def makePe2BramMat(self, mat):
        outBramArr = []     # array of BRAM rows
        for row in mat:
            bramRow = self.makePe2BramVec(row)
            outBramArr.append(bramRow)
        return outBramArr




    # ---- Assembler directives

    # Sets up assembler parameters
    # Parameters:
    #   fracWidth : No. of fractional bits to use for fixed-point operations
    #   mvBlockDim: (BLK_ROW_CNT, BLK_COL_CNT), these are parameters of IMAGine-instance.
    #               if set to None, matrix/vector bound checking will be disabled.
    #   resvRegCnt: Registers (regCnt, regCnt+resvReg-1) are reserved to be freely used by the assembler.
    def setupParams(self, regCnt=16, regWidth=16, maxLevel=3, maxFold=4, idWidth=8, fracWidth=0, mvBlockDim=None, resvRegCnt=0):
        # setup picaso instruction parameters
        assert regCnt   <= 60, "This initial version only supports upto 60 16-bit user registers"   # TODO: Adjust these assertion
        assert regWidth == 16, "This initial version only supports 16-bit registers"                # when more precisions are supported
        if mvBlockDim:
            recMaxLevel = math.ceil(math.log(mvBlockDim[1], 2)) - 1     # compute the recommended maxLevel
            if recMaxLevel < maxLevel: print(f'WARN: Specified maxLevel ({maxLevel}) is not optimal; recommended maxLevel = {recMaxLevel}')
            assert recMaxLevel <= maxLevel, f'Specified maxLevel ({maxLevel}) is incorrect; recommended maxLevel = {recMaxLevel}'
        # forward PiCaSOAsm parameters
        self.picaso_as.setupParams(regCnt=regCnt, regWidth=regWidth,  
                                   maxLevel=maxLevel, maxFold=maxFold,
                                   idWidth=idWidth)
        # check and set IMAGine parameters
        assert fracWidth >= 0 and fracWidth <= regWidth, "Fixed-point fracWidth must be >= 0 and <= regWidth ({regWidth})"
        self.fracWidth = fracWidth
        if mvBlockDim:
            self.mvMaxRow = mvBlockDim[0]          # PiCaSO has 1 PE row per block row
            self.mvMaxCol = mvBlockDim[1] * self.picaso_as.peCount
        else:
            self.mvMaxRow = None
            self.mvMaxCol = None
        if resvRegCnt:
            totReg = regCnt + resvRegCnt
            avlReg = self.picaso_as.pimDepth//regWidth  # total available registers in PiCaSO
            assert totReg <= avlReg, f"Too many ({regCnt}+{resvRegCnt}>{avlReg}) registers specified; adjust the assembler parameters"
            self.resvRegBase = regCnt   # lowest of the reserved registers
            self.resvRegCnt  = resvRegCnt
        else:
            self.resvRegBase = None     # no reserved registers
            self.resvRegCnt  = 0


    # Sets up assembler parameters from a YAML file
    def loadParams(self, filepath, cpright=True, showparams=True):
        if cpright: imagine_as.printCopyright()     # by default prints the copyright notice
        # set up assembler parameters from the given file
        with open(filepath, 'r') as fconf: params = yaml.safe_load(fconf)
        imagine_as.setupParams(**params)    # unpack dictionary as function parameters
        # by default print the loaded parameters
        if showparams:      
            print('IMagine Assembler Parameters:')
            imagine_as.printParams()
            print('')


    # Resets the internal state for a fresh new program, preserving the assembler parameters
    def reset(self):
        self.instructions = []     # clear instruction cache
        self.isAssembled = False   # unset assemble flag
        self.picaso_as.reset()     # reset PiCaSO assembler instance


    # Compiles the instructions into machine code fields for exporting
    def assemble(self, verbose=False):
        if verbose: print("INFO: Encoding instructions ...")
        for instr in self.instructions:
            if verbose: print(f"instr: {instr['src']}")
            word = self.genMachineCode(instr)
            instr['assembly'] = word
        print(f"INFO: {len(self.instructions)} instructions assembled")
        self.isAssembled = True


    # Exports the compiled instructions as program image for Verilog readmemb
    # Options:
    #    filename : path of the output file, prints to stdout if None
    #    comment  : if true, appends user-comments as inline comment
    #    source   : if true, appends the source instruction mnemonics as inline comment
    #    separator: Separator between instruction segments for easy reading
    def export_verilogBin(self, filename=None, comment=True, source=True, separator='_'):
        # Run assembler if not already
        if not self.isAssembled:
            print("WARN: Export invoked before the code is assembled")
            print("INFO: Running assembler ...")
            self.assemble()
        # build output string
        outprog = []
        for instr in self.instructions:
            if instr['assembly']['type'] == 'pseudo': 
                outxt = self.makeExportPseudoText(instr, addCmt=comment, addSrc=source)
            else: 
                outxt = self.makeExportBinText(instr, addCmt=comment, addSrc=source, sep=separator)  # build the instruction text for executable instructions
            if outxt: outprog.append(outxt)   # save the instruction text for writing
        # write the output
        if filename:
            with open(filename, 'w') as fout:
                for txt in outprog: fout.write(txt+'\n')
            print(f"INFO: assembled program written to {filename}")
        else:
            print("---- Assembled Program ----")
            for txt in outprog: print(txt)
            print("---- End of Program ----")


    # Exports the compiled instructions as a C-array of hex numbers, wrapped in a struct
    # Options:
    #    progname : name of the program instance in the C-file
    #    filename : path of the output file, prints to stdout if None
    #    comment  : if true, appends user-comments as inline comment
    #    source   : if true, appends the source instruction mnemonics as inline comment
    def export_CprogHex(self, progname, filename=None, comment=True, source=True):
        # Run assembler if not already
        if not self.isAssembled:
            print("WARN: Export invoked before the code is assembled")
            print("INFO: Running assembler ...")
            self.assemble()
        # build output string
        instructions = []
        for instr in self.instructions:
            if instr['assembly']['type'] == 'pseudo':
                outxt = self.makeExportPseudoText(instr, addCmt=comment, addSrc=source)
            else:
                outxt = self.makeExportHexText(instr, addCmt=comment, addSrc=source, word_suffix=', ', indent=' '*4)  # build the instruction text
            if outxt: instructions.append(outxt)   # save the instruction text for writing
        instructions = '\n'.join(instructions)
        cprog = c_prog_template.substitute(instructions=instructions, progname=progname,
                                   fracWidth=self.fracWidth, mvMaxRow=self.mvMaxRow, mvMaxCol=self.mvMaxCol,
                                   regWidth=self.picaso_as.regWidth, idWidth=self.picaso_as.idWidth, peCount=self.picaso_as.peCount)
        # write the output
        if filename:
            with open(filename, 'w') as fout:
                fout.write(cprog)
            print(f"INFO: assembled C-program written to {filename}")
            #self.export_CprogHeader(c_header_name)      # also export the generic program header
        else:
            print("---- Assembled Program ----")
            print(cprog)
            print("---- End of Program ----")


    # Exports the header for C-programs
    def export_CprogHeader(self, filename=None):
        if filename:
            with open(filename, 'w') as fout:
                fout.write(c_header_text)
            print(f'INFO: C-header written to {filename}')
        else:
            print("---- C-Header ----")
            print(c_header_text)
            print("---- End of C-Header ----")
        pass




    # ---- Instruction mnemonic functions: when called with parameters, encodes
    #      the instruction into internal representation (self.instructions).
    def mv_instSelectBlock(self, rowID, colID, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instSelectBlock(rowID, colID)
        # Ecoding
        src = f'MV_SELECT_BLOCK rowID={rowID}, colID={colID}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instSelectRow(self, rowID, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instSelectRow(rowID)
        # Ecoding
        src = f'MV_SELECT_ROW rowID={rowID}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instSelectCol(self, colID, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instSelectCol(colID)
        # Ecoding
        src = f'MV_SELECT_COL colID={colID}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instSelectAll(self, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instSelectAll()
        # Ecoding
        src = f'MV_SELECT_ALL'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instWrite(self, addr, data, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instWrite(addr, data)
        # Ecoding
        src = f'MV_WRITE addr={addr}, data=0x{data:X}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instUpdatepp(self, ppreg, multiplicand, multiplier, bitNo, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instUpdatepp(ppreg, multiplicand, multiplier, bitNo)
        # Ecoding
        src = f'MV_UPDATEPP ppreg={{{ppreg}, {ppreg+1}}}, multiplicand={multiplicand}, multiplier={multiplier}, bitNo={bitNo}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instAdd(self, rd, rs1, rs2, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instAdd(rd, rs1, rs2)
        # Ecoding
        src = f'MV_ADD rd={rd}, rs1={rs1}, rs2={rs2}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instSub(self, rd, rs1, rs2, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instSub(rd, rs1, rs2)
        # Ecoding
        src = f'MV_SUB rd={rd}, rs1={rs1}, rs2={rs2}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instBlockFold(self, fold, rd, rs, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instAccumblk(fold, rd, rs)
        # Ecoding
        src = f'MV_BLOCK_FOLD fold={fold}, dest={rd}, src={rs}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instAccumrow(self, level, reg, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instAccumrow(level, reg)
        # Ecoding
        src = f'MV_ACCUM_ROW level={level}, reg={reg}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instNop(self, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instNop()
        # Ecoding
        src = 'MV_NOP'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instMov(self, rd, rs, *, comment=None):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instMov(rd, rs)
        # Ecoding
        src = f'MV_MOV dest={rd}, src={rs}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_instMovOffset(self, offset, rd, rs, *, comment=None, skipChecks=False):
        # argument validation and submodule instruction generation
        picaso_ir = self.picaso_as.instMovOffset(offset, rd, rs, skipChecks=skipChecks)
        # Ecoding
        src = f'MV_MOV_OFFSET offset={offset}, dest={rd}, src={rs}'
        instr = {
            'submodule' : 'mv', 'ir' : picaso_ir,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def vv_instSerialEn(self, *, comment=None):
        # argument validation and submodule instruction generation
        vecshift_op = 'serial_en'
        # Ecoding
        src = f'VV_SERIAL_EN'
        instr = {
            'submodule' : 'vv', 'opcode' : vecshift_op,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def vv_instParallelEn(self, *, comment=None):
        # argument validation and submodule instruction generation
        vecshift_op = 'parallel_en'
        # Ecoding
        src = f'VV_PARALLEL_EN'
        instr = {
            'submodule' : 'vv', 'opcode' : vecshift_op,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def vv_instDisableShift(self, *, comment=None):
        # argument validation and submodule instruction generation
        vecshift_op = 'disable'
        # Ecoding
        src = f'VV_DISABLE_SHIFT'
        instr = {
            'submodule' : 'vv', 'opcode' : vecshift_op,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def vv_instNop(self, *, comment=None):
        # argument validation and submodule instruction generation
        vecshift_op = 'idle'
        # Ecoding
        src = f'VV_NOP'
        instr = {
            'submodule' : 'vv', 'opcode' : vecshift_op,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # Adds a comment to the source (mainly for debugging)
    def as_addComment(self, comment):
        src = 'AS_COMMENT'
        instr = {
            'submodule' : 'as', 
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr




    # ---- Macro instructions built on top of submodule instructions

    def mv_macroMult(self, rd, multiplicand, multiplier, *, comment=None, skipChecks=False):
        # argument validation needs to be performed here to generate error at the instruction invocation line
        if not skipChecks:      # WARNING: skipChecks should only be set True by internal macros which already validates user inputs
            self.picaso_as.validateReg(rd)
            self.picaso_as.validateReg(rd+1, f'reg {rd+1} not valid (rd of mult spans 2 pe-registers)')
            self.picaso_as.validateReg(multiplicand)
            self.picaso_as.validateReg(multiplier)
            assert multiplicand != rd and multiplicand != rd+1, f'multiplicand cannot overlap with dest registers {rd, rd+1}'
            assert multiplier != rd and multiplier != rd+1, f'multiplier cannot overlap with dest registers {rd, rd+1}'
        # Create a macro IR
        src = f'MV_MULT rd={rd}, multiplicand={multiplicand}, multiplier={multiplier}'
        instr = {
            'submodule' : 'mv', 'macro' : 'mult',
            'rd' : rd, 'multiplier' : multiplier, 'multiplicand' : multiplicand,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_macroMultFxp(self, rd, multiplicand, multiplier, *, comment=None):
        # argument validation needs to be performed here to generate error at the instruction invocation line
        assert self.resvRegCnt>=2, "This macro requires at least 2 reserved registers; adjust assembler parameters"
        self.picaso_as.validateReg(rd)  # rd+1 register is not needed due to the use of reserved registers
        self.picaso_as.validateReg(multiplicand)
        self.picaso_as.validateReg(multiplier)
        assert multiplicand != rd, f'multiplicand cannot overlap with dest register {rd}'
        assert multiplier != rd, f'multiplier cannot overlap with dest register {rd}'
        # Invoke other macros and instructions
        src = f'MV_MULTFPX rd={rd}, multiplicand={multiplicand}, multiplier={multiplier}'
        if comment==None: comment = ''
        instr0 = self.mv_macroMult(self.resvRegBase, multiplicand, multiplier,         # perform integer multiplication and store the result in reserved registers.
                                   comment=f'From macro call: {src}; {comment}',   # append the original comment with the macro call note.
                                   skipChecks=True)                                    # inputs are already validated.
        instr1 = self.mv_instMovOffset(self.fracWidth, rd=rd, rs=self.resvRegBase,         # store the fixed-point mult output into the original destination register, rd.
                                       comment=f'From macro call: {src}; {comment}',   # append the original comment with the macro call note.
                                       skipChecks=True)                                    # inputs are already validated.
        return [instr0, instr1]


    def mv_macroBlockAccum(self, rd, rs, *, comment=None):
        # argument validation needs to be performed here to generate error at the instruction invocation line
        self.picaso_as.validateReg(rd)
        self.picaso_as.validateReg(rs)
        # Create a macro IR
        src = f'MV_BLOCK_ACCUM rd={rd}, rs={rs}'
        instr = {
            'submodule' : 'mv', 'macro' : 'blockAccum',
            'rd' : rd, 'rs' : rs,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # Accumulates the rs register of PE columns (0 : colCnt-1) into rd register
    def mv_macroRangeAccum(self, colCnt, rd, rs, *, comment=None):
        # argument validation needs to be performed here to generate error at the instruction invocation line
        validCounts = {2**i * self.picaso_as.peCount for i in range(self.picaso_as.maxLevel+2)}  # 1 block: accum_blk, 2 blocks: level=0
        assert colCnt in validCounts, f'Only {validCounts} are valid values for colCnt (maxLevel={self.picaso_as.maxLevel}, peCount={self.picaso_as.peCount})'
        self.picaso_as.validateReg(rd)
        self.picaso_as.validateReg(rs)
        # Invoke other macros and instructions
        if comment==None: comment = ''
        src = f'MV_RNGACCUM colCnt={colCnt}, rd={rd}, rs={rs}'
        blkCols = colCnt//self.picaso_as.peCount    # no. of PiCaSO blocks to accumulate
        # block-level accumulation
        assert blkCols >= 1, f'Invalid blkCols={blkCols}'   # if the input validation is correct, blkCols should always be >= 1
        instr0 = self.mv_macroBlockAccum(rd=rd, rs=rs,
                                         comment=f'From macro call: {src}; {comment}')   # append the original comment with the macro call note.
        instr = [instr0]
        if blkCols > 1:
            upLevel = math.ceil(math.log(blkCols, 2)) - 1   # maximum level need to be applied
            for l in range(0, upLevel+1):
                instrL = self.mv_instAccumrow(level=l, reg=rd,      # accumulate block-level result stored in rd
                                              comment=f'From macro call: {src}; {comment}')   # append the original comment with the macro call note.
                instr.append(instrL)
        return instr


    # Accumulates the rs register of all PE columns into rd register
    def mv_macroAllAccum(self, rd, rs, *, comment=None):
        # argument validation needs to be performed here to generate error at the instruction invocation line
        self.picaso_as.validateReg(rd)
        self.picaso_as.validateReg(rs)
        # Invoke other macros and instructions
        if comment==None: comment = ''
        src = f'MV_ALLACCUM rd={rd}, rs={rs}'
        # block-level accumulation
        instr0 = self.mv_macroBlockAccum(rd=rd, rs=rs,
                                         comment=f'From macro call: {src}; {comment}')   # append the original comment with the macro call note.
        instr = [instr0]
        # array-level accumulation
        for l in range(0, self.picaso_as.maxLevel+1):
            instrL = self.mv_instAccumrow(level=l, reg=rd,      # accumulate block-level result stored in rd
                                          comment=f'From macro call: {src}; {comment}')   # append the original comment with the macro call note.
            instr.append(instrL)
        return instr


    def mv_macroSync(self, *, comment=None):
        # Create a macro IR
        src = 'MV_SYNC'
        instr = {
            'submodule' : 'mv', 'macro' : 'sync',
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def vv_macroSync(self, *, comment=None):
        # Create a macro IR
        src = 'VV_SYNC'
        instr = {
            'submodule' : 'vv', 'macro' : 'sync',
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # Given a 2D-array, generates instructions for loading it into the
    # specified register. The array elements can be integers or floats, which
    # will be converted to fixed-points based on the assembler parameters. The
    # conversion is done at the macro invocation step, not at the assemble step.
    def mv_macroLoadMat(self, reg, matrix, *, comment=None):
        # Validate parameters
        self.picaso_as.validateReg(reg)
        matRowCnt = len(matrix)
        matColCnt = -1
        if self.mvMaxRow: assert matRowCnt <= self.mvMaxRow, f'Row count ({matRowCnt}) of the given matrix is too big (>{self.mvMaxRow})'
        for row in matrix: 
            colCnt = len(row)
            if self.mvMaxCol: assert colCnt <= self.mvMaxCol, f'Column count ({colCnt}) of the given matrix is too big (>{self.mvMaxCol})' 
            matColCnt = max(matColCnt, colCnt)     # may contain rows of different sizes
        # Convert to fixed-point
        scaleFact = 1 << self.fracWidth
        matrix = np.array(matrix)    # create a deepcopy as numpy array
        matrix = (matrix*scaleFact).astype(int)   # convert to integer representation of fixed-point
        # Add dependencies
        self.mv_macroClearReg(reg, comment='dependency of MV_LOADMAT')
        # Create a macro IR
        src = f'MV_LOADMAT Mat({matRowCnt}, {matColCnt})'
        instr = {
            'submodule' : 'mv', 'macro' : 'loadMat',
            'reg' : reg, 'matrix' : matrix,     # save the fixed-point matrix for assemble() phase
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # Given a 1D-array, generates instructions for loading it into the specified register of all PE rows
    def mv_macroLoadVecRow(self, reg, vector, *, comment=None):
        # Validate parameters
        self.picaso_as.validateReg(reg)
        vecLen = len(vector)
        if self.mvMaxCol: assert vecLen <= self.mvMaxCol, f'Column count ({vecLen}) of the given vector is too big (>{self.mvMaxCol})' 
        # Convert to fixed-point
        scaleFact = 1 << self.fracWidth
        vector = np.array(vector)    # create a deepcopy as numpy array
        vector = (vector*scaleFact).astype(int)    # convert to integer representation of fixed-point
        # Add dependencies
        self.mv_macroClearReg(reg, comment='dependency of MV_LOADVEC_ROW')
        # Create a macro IR
        src = f'MV_LOADVEC_ROW Vec({vecLen})'
        instr = {
            'submodule' : 'mv', 'macro' : 'loadVecRow',
            'reg' : reg, 'vector' : vector,    # save the fixed-point vector for assemble() phase
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # Given a 1D-array, generates instructions for loading it into the specified register of all PE columns
    def mv_macroLoadVecCol(self, reg, vector, *, comment=None):
        # Validate parameters
        self.picaso_as.validateReg(reg)
        vecLen = len(vector)
        if self.mvMaxRow: assert vecLen <= self.mvMaxRow, f'Row count ({vecLen}) of the given vector is too big (>{self.mvMaxRow})' 
        # Convert to fixed-point
        scaleFact = 1 << self.fracWidth
        vector = np.array(vector)    # create a deepcopy as numpy array
        vector = (vector*scaleFact).astype(int)    # convert to integer representation of fixed-point
        # Add dependencies
        self.mv_macroClearReg(reg, comment='dependency of MV_LOADVEC_COL')
        # Create a macro IR
        src = f'MV_LOADVEC_COL Vec({vecLen})'
        instr = {
            'submodule' : 'mv', 'macro' : 'loadVecCol',
            'reg' : reg, 'vector' : vector,    # save the fixed-point vector for assemble() phase
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def mv_macroClearReg(self, reg, *, comment=None):
        # argument validation needs to be performed here to generate error at the instruction invocation line
        self.picaso_as.validateReg(reg)
        # Create a macro IR
        src = f'MV_CLRREG reg={reg}'
        instr = {
            'submodule' : 'mv', 'macro' : 'clearReg',
            'reg' : reg,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr









# Scripting interface. Use it as follows,
#   from imagine_assembler import *
#
#   imagine_as.setupParams(...)
#
#   add(rd, rs1, rs2)
#   sub(rd, rs1, rs2)
#     .
#     .
#     .
#   imagine_as.assemble(flags...)
#   imagine_as.export_verilogBin(filename, flags...)

# Assembler object
imagine_as = IMAGineAsm()

# instructions and macros exposed as callable objects.
# Note: Macros are all caps, while built-in instructions are in camelCase.
mv_write = imagine_as.mv_instWrite
mv_nop   = imagine_as.mv_instNop
mv_mov   = imagine_as.mv_instMov
mv_add   = imagine_as.mv_instAdd
mv_sub   = imagine_as.mv_instSub
mv_movOffset = imagine_as.mv_instMovOffset
mv_selectBlk = imagine_as.mv_instSelectBlock
mv_selectRow = imagine_as.mv_instSelectRow
mv_selectCol = imagine_as.mv_instSelectCol
mv_selectAll = imagine_as.mv_instSelectAll
mv_accumRow  = imagine_as.mv_instAccumrow
mv_updatepp  = imagine_as.mv_instUpdatepp
mv_blockFold = imagine_as.mv_instBlockFold

vv_nop  = imagine_as.vv_instNop
vv_shiftOff = imagine_as.vv_instDisableShift
vv_serialEn = imagine_as.vv_instSerialEn
vv_parallelEn = imagine_as.vv_instParallelEn

mv_MULT = imagine_as.mv_macroMult
mv_SYNC = imagine_as.mv_macroSync
vv_SYNC = imagine_as.vv_macroSync
mv_BLOCKACCUM = imagine_as.mv_macroBlockAccum
mv_RNGACCUM   = imagine_as.mv_macroRangeAccum
mv_ALLACCUM   = imagine_as.mv_macroAllAccum
mv_LOADMAT = imagine_as.mv_macroLoadMat
mv_CLRREG  = imagine_as.mv_macroClearReg
mv_MULTFXP = imagine_as.mv_macroMultFxp
mv_LOADVEC_ROW = imagine_as.mv_macroLoadVecRow
mv_LOADVEC_COL = imagine_as.mv_macroLoadVecCol

as_addComment = imagine_as.as_addComment
