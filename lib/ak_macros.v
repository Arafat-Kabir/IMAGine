/*********************************************************************************
* Copyright (c) 2023, Computer Systems Design Lab, University of Arkansas        *
*                                                                                *
* All rights reserved.                                                           *
*                                                                                *
* Permission is hereby granted, free of charge, to any person obtaining a copy   *
* of this software and associated documentation files (the "Software"), to deal  *
* in the Software without restriction, including without limitation the rights   *
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell      *
* copies of the Software, and to permit persons to whom the Software is          *
* furnished to do so, subject to the following conditions:                       *
*                                                                                *
* The above copyright notice and this permission notice shall be included in all *
* copies or substantial portions of the Software.                                *
*                                                                                *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR     *
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,       *
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE    *
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         *
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  *
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  *
* SOFTWARE.                                                                      *
**********************************************************************************

==================================================================================

  Author: MD Arafat Kabir
  Email : arafat.sun@gmail.com
  Date  : Wed, Jul 19, 06:26 PM CST 2023

  Description: 
  Definition of utility macros.

================================================================================*/

`ifndef AK_MACROS_H
`define AK_MACROS_H


// Throws a compile time error if condition != True
//`define AK_ASSERT(condition)         \
//  generate                           \
//    if(!(condition))                 \
//      AK_ASSERT___Fail  Failed();    \
//  endgenerate

// this single-line version is exactly the same as the above macro, and it reports the correct line number
`define AK_ASSERT(condition) generate if(!(condition)) AK_ASSERT___Fail  Failed(); endgenerate
// Assert with message
`define AK_ASSERT2(condition, msg) generate if(!(condition)) AK_ASSERT__``msg  Failed(); endgenerate

// Min-Max macros
`define AK_MAX(A, B)  ((A) > (B) ? (A) : (B))
`define AK_MIN(A, B)  ((A) < (B) ? (A) : (B))

// These macros generates module top-level stand-alone messages (NOTE: don't use semicolons after them)
`define AK_TOP_WARN(msg)  initial $display("WARN: %s (%s:%0d)", msg, `__FILE__, `__LINE__);
`define AK_TOP_EROR(msg)  initial begin $display("EROR: %s (%s:%0d)", msg, `__FILE__, `__LINE__); $finish; end

// this macro can be used as a standalone statement (with semicolon)
// Prints the message then appends source
`define AK_MSG(msg) \
        begin  \
          $write(msg); \
          $display(" (%s:%0d)", `__FILE__, `__LINE__); \
        end if(0)

// This is the same macro as above, but can be called with formatting strings
// and variable arguments. However, it requires extra parenthesis. Example:
//   `AK_MSGP(("time: %0t", $time));
`define AK_MSGP(msg) \
        begin  \
          $write msg; \
          $display(" (%s:%0d)", `__FILE__, `__LINE__); \
        end if(0)  


// Given a value, wraps it in a pair of double-quotes 
`define STRINGIFY(x) `"x`"

// computes ceil(x/y)
`define DIV_CEIL(x,y) (x/y + (x%y ? 1 : 0))


`endif  // AK_MACROS_H
