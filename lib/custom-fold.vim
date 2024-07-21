"==================================================================================
"
"  Author : MD Arafat Kabir
"  Email  : arafat.sun@gmail.com
"  Date   : Tue, Sep 05, 03:40 PM CST 2023
"
"  Description: Defines custom folding rules that matches my verilog coding
"  style. Source this file when these custom folding rules are needed.
"
"================================================================================*/


" Define a function for foldexp
function! AKFold(lnum)
  " Get the current line
  let line = getline(a:lnum)
  let indent = indent(a:lnum)
  let next_indent = indent(a:lnum + 1)
  let nofoldPat = ["// --"]   " lines with these patterns will use the foldLevel=0
  let blankPat = "^\s*$"
  let foldLevel = indent / &shiftwidth    " fold-level purely based on indent

  " A single blankline uses previous lines foldlevel
  if AKSurroundNonBlank(a:lnum)
    return '='
  endif

  " use previous line fold, or use indent-based fold
  if AKMatch(line, nofoldPat)
    return 0
  else
    return foldLevel
  endif
endfunction


" Check if any of the patterns exist in text
function! AKMatch(text, patterns)
  " Loop through the list of patterns
  for pat in a:patterns
    " Use matchstr() to check if the pattern matches the line
    if match(a:text, pat) >= 0
      " Return 1 if a match is found
      return 1
    endif
  endfor
  " Return 0 if no match is found
  return 0
endfunction


" Returns 1 if lnum is blank but its previous and next lines are not blanks
function! AKSurroundNonBlank(lnum)
  " Get the text of the current line and the surrounding lines
  let current_line = getline(a:lnum)
  let previous_line = getline(a:lnum - 1)
  let next_line = getline(a:lnum + 1)

  " Define the regular expression pattern for a blank line
  let blank_pattern = '^\s*$'

  " Check if the current line is blank and the surrounding lines are not
  if current_line =~# blank_pattern && previous_line !~# blank_pattern && next_line !~# blank_pattern
    return 1
  else
    return 0
  endif
endfunction


" activate custom folding rules
set foldexpr=AKFold(v:lnum)
set foldmethod=expr
set foldcolumn=2
set foldlevel=1
