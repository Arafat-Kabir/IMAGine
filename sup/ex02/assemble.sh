#!/bin/bash


# Set up environment variables
asmdir=$(realpath ../../sup/imagine_assembler)   # Path to the directory containing imagine_assembler modules
export PYTHONPATH=$PYTHONPATH:$asmdir

# Assemble IMAGine Program and generate test vectors
python3 ./ex02_prog.py
python3 ./ex02_testvec.py
