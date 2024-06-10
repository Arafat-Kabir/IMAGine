#===================================================================================#
#   Copyright (c) 2023, Computer Systems Design Lab, University of Arkansas         #
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
#   Date   : Tue, Oct 24, 12:48 PM CST 2023                                      #
#   Version: v0.1                                                                #
#                                                                                #
#   Description:                                                                 #
#   This is a python module that implements a basic assembler for PiCaSO tile    #
#   controller instruction-set.  Because this is a python module, the assembly   #
#   programs can be written as a python script. As a result, you get some        #
#   convenient features directly from python, like macros (functions), use of    #
#   external modules, complicated computation within the assembly program        #
#   (python script), etc.                                                        #
#                                                                                #
#================================================================================#


class PiCaSOAsm:
    # Module information
    v_major = 0
    v_minor = 1
    author  = 'MD Arafat Kabir (arafat.sun@gmail.com, makabir@uark.edu)'
    cpright = 'Copyright (c) 2023, Computer Systems Design Lab, University of Arkansas'

    # build and print invocation header
    invoc_header = [
        f'PiCaSO Tile Assember (PiCaSOAsm) version {v_major}.{v_minor}',
        f'Author: {author}',
        cpright,
        ''
    ]


    # Tables for machine-code generation
    tbl_opcode = {
        'nop'      : 0,
        'write'    : 1,
        'read'     : 2,
        'updatepp' : 3,
        'accum'    : 4,
        'aluop'    : 5,
        'select'   : 6,     # TODO: Move it under super-op
        'mov'      : 7,
        'superop'  : 8      # TODO: Change opcode to select
    }

    tbl_fncode = {
        'accum_blk'  : 0,
        'accum_row'  : 1,
        'alu_add'    : 0,
        'alu_cpx'    : 1,
        'alu_cpy'    : 2,
        'alu_sub'    : 3,
        'mov_offset' : 0,
        'sel_col'    : 0,
        'sel_block'  : 1,
        'sel_row'    : 2,
        'sel_enc'    : 3,
    }

    tbl_super_code = {
        'clrmbit' : 0
    }
    
    tbl_field_width = {
        'opcode' : 4,   # width of the OpCode field
        'fncode' : 2,   # width of the Fn field (part of ADDR)
        'addr'   : 10,  # width of the ADDR field
        'data'   : 16,  # width of the DATA field
        'offset' : 4,   # width of the offset field (needed for UPDATE-PP instruction)
        'reg'    : 6,   # width of the register base addresses
        'param'  : 4,   # width of param field, used as net-level, opmux-Conf, alu-Conf, etc.
        'id'     : 8    # width of PiCaSO block row/column IDs
    }
    # composite field widths
    tbl_field_width['seg2'] = tbl_field_width['opcode']
    tbl_field_width['seg1'] = tbl_field_width['addr']
    tbl_field_width['seg0'] = tbl_field_width['data']


    # Class implementation
    def __init__(self):
        self.instructions = []      # will contain internal representation of each instruction
        self.isAssembled = False    # state flag, set to True after assemble
        self.setupParams()          # setup default parameter values


    # Resets the internal state for a fresh new program, preserving the assembler parameters
    def reset(self):
        self.instructions = []
        self.isAssembled = False


    # ---- Development utils: following functions are used in the development of this module

    # Prints a message when an instruction is called which is not implemented yet
    def _instrNotImpl(self, name):
        print(f"WARN: {name} is not implemented yet, skipping")


    def printCopyright(self):
        for line in self.invoc_header: print(line)


    def printParams(self, indent=''):
        print(f'{indent}regCnt  : {self.regCnt}')
        print(f'{indent}regWidth: {self.regWidth}')
        print(f'{indent}maxLevel: {self.maxLevel}')
        print(f'{indent}maxFold : {self.maxFold}')
        print(f'{indent}idWidth : {self.idWidth}')
        print(f'{indent}peCount : {self.peCount}')


    # Given an assembled instruction, returns a binary text for exporting it to output program
    def makeExportBinText(self, instr, addCmt, addSrc, sep):
        # build machine code for the instruction
        binword = self.makeBinWord(instr['word'], sep=sep)
        # build inline comment
        inlnCmt = []
        if addSrc: inlnCmt.append(instr['src'])        # add source instruction if requested
        if addCmt and instr['comment']: inlnCmt.append(instr['comment'])   # add user comments if requested
        if inlnCmt:
            inlnCmt = self.makeComment('; '.join(inlnCmt))   # build the comment string if comments exist
        else:
            inlnCmt = ''
        # return the text for exporting
        if inlnCmt: text = '  '.join([binword, inlnCmt])
        else: text = binword
        return text


    # converts the provided text into inline comment for exporting
    def makeComment(self, text):
        return f'// {text}'


    # Given a word dictionary with segments, returns the binary representation
    # of the instruction word as a string (with separators)
    def makeBinWord(self, wordDict, sep=''):
        w_seg0 = self.tbl_field_width['seg0']
        w_seg1 = self.tbl_field_width['seg1']
        w_seg2 = self.tbl_field_width['seg2']
        seg2, seg1, seg0 = wordDict['seg2'], wordDict['seg1'], wordDict['seg0']
        # format the instruction word in binary format, with separator {seg:0wb}
        binword = f"{seg2:0{w_seg2}b}{sep}{seg1:0{w_seg1}b}{sep}{seg0:0{w_seg0}b}"
        return binword


    # Given a word dictionary with segments, returns the numeric representation
    # of the instruction word.
    def makeNumWord(self, wordDict):
        w_seg0 = self.tbl_field_width['seg0']
        w_seg1 = self.tbl_field_width['seg1']
        w_seg2 = self.tbl_field_width['seg2']
        word = (wordDict['seg2'] << w_seg1) | wordDict['seg1']
        word = (word << w_seg0) | wordDict['seg0']
        return word


    # Given a register number and a bit index, returns its address in the PIM block
    def makeRegAddr(self, reg, bit=0):
        return reg*self.regWidth + bit


    # Given an instruction dictionary (internal representation), Returns the
    # machine code as a dictionary of instruction-word segements (wordDict)
    def genMachineCode(self, instrDict):
        # shorthands for field widths
        w_reg  = self.tbl_field_width['reg']
        w_id   = self.tbl_field_width['id']
        # get the opcode name and machine code
        opcode = instrDict['opcode']
        opnum  = self.tbl_opcode[opcode]
        # Encode instructions
        if opcode == 'aluop':
            # [ opcode ] [ Fn, RD ] [ RS2, RS1 ]
            fn = self.tbl_fncode[instrDict['fncode']]
            rd, rs1, rs2 = instrDict['rd'], instrDict['rs1'], instrDict['rs2']
            seg2 = opnum
            seg1 = (fn  << w_reg) | rd
            seg0 = (rs2 << w_reg) | rs1
        elif opcode == 'accum':
            # [ opcode ] [ Fn, Param ] [ R2, R1 ]
            fn   = self.tbl_fncode[instrDict['fncode']]
            param, rs1 = instrDict['param'], instrDict['rs1']
            if 'rs2' in instrDict: rs2 = instrDict['rs2']
            else: rs2 = 0
            seg2 = opnum
            seg1 = (fn  << w_reg) | param
            seg0 = (rs2 << w_reg) | rs1
        elif opcode == 'updatepp':
            # [ opcode ] [ OFFSET, RD ] [ RS2, RS1 ]
            offset = instrDict['offset']
            rd, rs1, rs2 = instrDict['rd'], instrDict['rs1'], instrDict['rs2']
            seg2 = opnum
            seg1 = (offset  << w_reg) | rd
            seg0 = (rs2 << w_reg) | rs1
        elif opcode == 'select':
            # [ opcode ] [ Fn, xx ] [ Row, Col ]
            fn = self.tbl_fncode[instrDict['fncode']]
            rowID, colID = instrDict['rowID'], instrDict['colID']
            seg2 = opnum
            seg1 = (fn << w_reg)
            seg0 = (rowID << w_id) | colID
        elif opcode == 'mov':
            # [ opcode ] [ Fn, Param ] [ R2, R1 ]
            fn   = self.tbl_fncode[instrDict['fncode']]
            param, rs1, rs2 = instrDict['offset'], instrDict['rs1'], instrDict['rs2']
            seg2 = opnum
            seg1 = (fn  << w_reg) | param
            seg0 = (rs2 << w_reg) | rs1
        elif opcode == 'write':
            # [ opcode ] [ ADDR ] [ DATA ]
            addr = instrDict['addr']
            data = instrDict['data']
            seg2 = opnum
            seg1 = addr
            seg0 = data
        elif opcode == 'nop':
            seg2 = opnum
            seg1 = seg0 = 0
        elif opcode == 'superop':
            seg2 = opnum
            seg1, seg0 = self.genSuperopMachineCode(instrDict)
        else:
            if opcode in self.tbl_opcode:
                assert 0, f"Instruction not implemented yet, opcode: {opcode}"
            else:
                assert 0, f"Invalid opcode: {opcode}"
        # build the word dictionary and return
        wordDict = {'seg0' : seg0, 'seg1' : seg1, 'seg2': seg2}
        return wordDict


    # Given an instruction dictionary (internal representation), Returns the
    # machine code for SUPER-OP instruction segments as tuple.
    def genSuperopMachineCode(self, instrDict):
        opcode = instrDict['opcode']
        scode  = instrDict['scode']
        assert opcode == 'superop', f"Not a SUPER-OP instruction, opcode: {opcode}"
        # Encode instructions
        if scode == 'clrmbit':
            seg1 = self.tbl_super_code['clrmbit']
            seg0 = 0
        else: assert 0, f"Invalid scode: {scode}"
        return seg1, seg0


    # Instruction parameter validation utilities
    def validateReg(self, reg, msg=None):
        if msg==None: msg=f'invalid register: {reg}'
        assert reg >= 0 and reg < self.regCnt, msg

    def validateLevel(self, level, msg=None):
        if msg==None: msg=f'invalid network level: {level}'
        assert level >= 0 and level <= self.maxLevel, msg

    def validateFold(self, fold, msg=None):
        if msg==None: msg=f'invalid fold: {fold}'
        assert fold >= 1 and fold <= self.maxFold, msg

    def validateOffset(self, offset, msg=None):
        if msg==None: msg=f'invalid offset: {offset}'
        assert offset >= 0 and offset < self.regWidth, msg

    def validateID(self, rcID, msg=None):
        if msg==None: msg=f'invalid row/col ID: {rcID}'
        maxID = 2**self.idWidth - 1
        assert rcID <= maxID and rcID >= 0, msg

    def validateAddress(self, addr, msg=None):
        if msg==None: msg=f'invalid address: {addr}'
        maxAddr = 2**self.tbl_field_width['addr'] - 1
        assert addr <= maxAddr and addr >= 0, msg

    def validateData(self, data, msg=None):
        # all data are unsigned numbers (rows of BRAMs, no the PE-registers)
        dataWidth = self.tbl_field_width['data']
        maxData = 2**dataWidth - 1
        minData = 0
        if msg==None: msg=f'invalid data: {data}, range ({minData}, {maxData})'
        assert data <= maxData and data >= minData, msg


    # ---- Assembler directives

    # Sets up assembler parameters
    def setupParams(self, regCnt=16, regWidth=16,  maxLevel=3, maxFold=4, idWidth=8):
        self.regCnt   = regCnt     # maximum no. of registers
        self.regWidth = regWidth   # width of PE registers
        self.maxLevel = maxLevel   # maximum allowed level for accum-row
        self.maxFold  = maxFold    # maximum allowed level for accum-row
        self.idWidth  = idWidth    # width of row/col IDs
        self.peCount  = 16         # no. of PEs in a block (fixed for now)
        self.pimDepth = 1024       # no. of rows in the PIM (BRAM) block, (fixed for now)
        assert regCnt <= self.pimDepth//regWidth, f"Register count is not consistent with regWidth ({regWidth}) and pimDepth ({self.pimDepth})"


    # Compiles the instructions into machine code for exporting
    def assemble(self, verbose=False):
        if verbose: print("INFO: Encoding instructions ...")
        for instr in self.instructions:
            if verbose: print(f"instr: {instr['src']}")
            word = self.genMachineCode(instr)
            instr['word'] = word
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
        # build output string, always outputs in binary format
        outprog = []
        for instr in self.instructions:
            outxt = self.makeExportBinText(instr, addCmt=comment, addSrc=source, sep=separator)  # build the instruction text
            outprog.append(outxt)   # save the instruction text for writing
        # write the output
        if filename:
            with open(filename, 'w') as fout:
                for txt in outprog: fout.write(txt+'\n')
            print(f"INFO: assembled program written to {filename}")
        else:
            print("---- Assembled Program ----")
            for txt in outprog: print(txt)
            print("---- End of Program ----")



    # ---- Instruction mnemonic functions: when called with parameters, encodes
    #   the instruction into internal representation (self.instructions).
    #
    #   Internal represenstation notes:
    #     - The internal representation is more close to the machine compared
    #       to the mnemonic funtions.
    #     - It is basically a dictionary of instruction-word fields, with their
    #       conceptual values.
    #     - The compilation step takes this internal format then converts it
    #       into machine code based on assembler parameters and any other
    #       directives specified
    #     - The comment field can be used to pass (debugging) information into
    #       the assembled output if needed.


    # rd = rs1 + rs2
    def instAdd(self, rd, rs1, rs2, *, comment=None):
        # argument validation
        self.validateReg(rd)
        self.validateReg(rs1)
        self.validateReg(rs2)
        # Ecoding
        src = f'ADD rd={rd}, rs1={rs1}, rs2={rs2}'
        instr = {
            'opcode' : 'aluop', 'fncode' : 'alu_add',
            'rd' : rd, 'rs1' : rs1, 'rs2' : rs2,
            'comment': comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # rd = rs1 + rs2
    def instSub(self, rd, rs1, rs2, *, comment=None):
        # argument validation
        self.validateReg(rd)
        self.validateReg(rs1)
        self.validateReg(rs2)
        # Ecoding
        src = f'SUB rd={rd}, rs1={rs1}, rs2={rs2}'
        instr = {
            'opcode' : 'aluop', 'fncode' : 'alu_sub',
            'rd' : rd, 'rs1' : rs1, 'rs2' : rs2,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # ppreg[bitNo +: N] += multiplicand * multiplier[bitNo] (N = register width)
    # Then sign extension: ppreg[bitNo + N] = ppreg[bitNo + N - 1]
    def instUpdatepp(self, ppreg, multiplicand, multiplier, bitNo, *, comment=None):
        # argument validation
        self.validateReg(ppreg)
        self.validateReg(ppreg+1, f'{ppreg+1} not be valid (ppreg spans 2 pe-registers)')
        self.validateReg(multiplicand)
        self.validateReg(multiplier)
        self.validateOffset(bitNo, msg=f'invalid bitNo: {bitNo}')
        assert multiplicand != ppreg and multiplicand != ppreg+1, f'multiplicand cannot overlap with dest registers {ppreg, ppreg+1}'
        assert multiplier != ppreg and multiplier != ppreg+1, f'multiplier cannot overlap with dest registers {ppreg, ppreg+1}'
        # Ecoding
        src = f'UPDATEPP ppreg={{{ppreg}, {ppreg+1}}}, multiplicand={multiplicand}, multiplier={multiplier}, bitNo={bitNo}'
        instr = {
            'opcode' : 'updatepp', 'offset' : bitNo,
            'rd' : ppreg, 'rs1' : multiplier, 'rs2' : multiplicand,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # rd = rs + folded(rs, fold)
    def instAccumblk(self, fold, rd, rs, *, comment=None):
        # argument validation
        self.validateFold(fold)
        self.validateReg(rd)
        self.validateReg(rs)
        # Ecoding
        src = f'ACCUM-BLK fold={fold}, dest={rd}, src={rs}'
        # Note that, the destination register is encoded in the rs2 field,
        # because the param field overlaps with the rd field.
        instr = {
            'opcode' : 'accum', 'fncode' : 'accum_blk',
            'param' : fold, 'rs1' : rs, 'rs2' : rd,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # receiver-pe0-reg += transmitter-pe0-reg
    # level decides whether a block is # receiver/transmitter
    def instAccumrow(self, level, reg, *, comment=None):
        # argument validation
        self.validateLevel(level)
        self.validateReg(reg)
        # Ecoding
        src = f'ACCUM-ROW level={level}, reg={reg}'
        instr = {
            'opcode' : 'accum', 'fncode' : 'accum_row',
            'param' : level, 'rs1' : reg,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # generates NOP
    def instNop(self, *, comment=None):
        src = 'NOP'
        instr = {'opcode' : 'nop', 'comment': comment, 'src' : src}
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    # clears multiplier-bits stored in the ALU
    def instClearmbit(self, *, comment=None):
        src = 'SUPER-OP CLRMBIT'
        instr = {
            'opcode' : 'superop', 'scode' : 'clrmbit',
            'comment': comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def instSelectBlock(self, rowID, colID, *, comment=None):
        # TODO: reimplement this instruction if it is moved under super-instruction
        # argument validation
        self.validateID(rowID, f'invalid rowID: {rowID}')
        self.validateID(colID, f'invalid colID: {colID}')
        # Ecoding
        src = f'SELECT fncode={self.tbl_fncode["sel_block"]} (SEL_BLOCK), rowID={rowID}, colID={colID}'
        instr = {
            'opcode' : 'select', 'fncode' : 'sel_block',
            'rowID' : rowID, 'colID' : colID,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def instSelectRow(self, rowID, *, comment=None):
        # TODO: reimplement this instruction if it is moved under super-instruction
        # argument validation
        self.validateID(rowID, f'invalid rowID: {rowID}')
        # Ecoding
        colID = 0       # we need some value to put into the instruction word
        src = f'SELECT fncode={self.tbl_fncode["sel_row"]} (SEL_ROW), rowID={rowID}, colID={colID}'
        instr = {
            'opcode' : 'select', 'fncode' : 'sel_row',
            'rowID' : rowID, 'colID' : colID,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def instSelectCol(self, colID, *, comment=None):
        # TODO: reimplement this instruction if it is moved under super-instruction
        # argument validation
        self.validateID(colID, f'invalid colID: {colID}')
        # Ecoding
        rowID = 0       # we need some value to put into the instruction word
        src = f'SELECT fncode={self.tbl_fncode["sel_col"]} (SEL_COL), rowID={rowID}, colID={colID}'
        instr = {
            'opcode' : 'select', 'fncode' : 'sel_col',
            'rowID' : rowID, 'colID' : colID,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def instSelectAll(self, *, comment=None):
        # TODO: reimplement this instruction if it is moved under super-instruction
        # Ecoding
        rowID = 0
        colID = 0
        src = f'SELECT fncode={self.tbl_fncode["sel_enc"]} (SEL_ENC), rowID={rowID}, colID={colID}'
        instr = {
            'opcode' : 'select', 'fncode' : 'sel_enc',
            'rowID' : rowID, 'colID' : colID,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def instMovOffset(self, offset, rd, rs, *, comment=None, skipChecks=False):
        # argument validation
        if not skipChecks:      # WARNING: skipChecks should only be set True by internal macros which already validates user inputs
            self.validateOffset(offset)
            self.validateReg(rd)
            self.validateReg(rs)
        # Ecoding
        src = f'MOV-OFFSET offset={offset}, dest={rd}, src={rs}'
        # Note that, the destination register is encoded in the rs2 field,
        # because the param field overlaps with the rd field.
        instr = {
            'opcode' : 'mov', 'fncode' : 'mov_offset',
            'offset' : offset, 'rs1' : rs, 'rs2' : rd,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def instMov(self, rd, rs, *, comment=None):
        # argument validation
        self.validateReg(rd)
        self.validateReg(rs)
        # Ecoding
        offset = 0      # simply copy rs into rd
        src = f'MOV-OFFSET offset={offset}, dest={rd}, src={rs}'
        # Note that, the destination register is encoded in the rs2 field,
        # because the param field overlaps with the rd field.
        instr = {
            'opcode' : 'mov', 'fncode' : 'mov_offset',
            'offset' : offset, 'rs1' : rs, 'rs2' : rd,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr


    def instWrite(self, addr, data, *, comment=None):
        # argument validation
        self.validateAddress(addr)
        self.validateData(data)
        # Ecoding
        src = f'WRITE addr={addr}, data=0x{data:X}'
        instr = {
            'opcode' : 'write',
            'addr' : addr, 'data' : data,
            'comment' : comment, 'src' : src
        }
        self.instructions.append(instr)
        self.isAssembled = False        # un-assembled instruction added
        return instr





# Scripting interface. Use it as follows,
#   from picaso_assembler import *
#
#   picaso_as.setupParams(...)
#
#   add(rd, rs1, rs2)
#   sub(rd, rs1, rs2)
#     .
#     .
#     .
#   picaso_as.assemble(flags...)
#   picaso_as.export_verilogBin(filename, flags...)


# Assembler object
picaso_as = PiCaSOAsm()

# simpler interface to instruction mnemonic functions for scripting
add = picaso_as.instAdd
sub = picaso_as.instSub
nop = picaso_as.instNop
updatepp  = picaso_as.instUpdatepp
accumblk  = picaso_as.instAccumblk
accumrow  = picaso_as.instAccumrow
clearmbit = picaso_as.instClearmbit

selectBlk = picaso_as.instSelectBlock
selectRow = picaso_as.instSelectRow
selectCol = picaso_as.instSelectCol
selectAll = picaso_as.instSelectAll
movOffset = picaso_as.instMovOffset
mov   = picaso_as.instMov
write = picaso_as.instWrite
