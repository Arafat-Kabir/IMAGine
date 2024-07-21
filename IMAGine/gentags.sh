#!/bin/bash


# Description:
# Use this script to generate/update tags in the IMAGine directory
# from files in IMAGine and the lib directory.


# tags for syntax plugin: https://github.com/vhda/verilog_systemverilog.vim
ctags -n --extras=+q --fields=+i ../lib/*.v ../lib/*.inc.v ../lib/*.vh ../IMAGine/*.sv* && echo "INFO: tags file updated" || echo "EROR: tags generation faile"
