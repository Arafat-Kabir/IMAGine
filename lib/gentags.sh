#!/bin/bash

# tags for syntax plugin: https://github.com/vhda/verilog_systemverilog.vim
ctags -n --extras=+q --fields=+i *.v
