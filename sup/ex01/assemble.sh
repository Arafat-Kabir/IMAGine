#!/bin/bash


# Set up environment variables
asmdir=$(realpath ../../sup/imagine_assembler)   # Path to the directory containing imagine_assembler modules
export PYTHONPATH=$PYTHONPATH:$asmdir

# Assemble IMAGine Programs
python3 ./ex01_prog.py
