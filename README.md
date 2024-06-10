# IMAGine
IMAGine : An In-Memory Accelerated GEMV Engine Overlay.
It is the fastest and most scalable PIM-array based 
FPGA GEMV accelerator, that clocks faster than TPU v1-v2
on AMD's Ultrascale+ devices.
This is an evaluation release with the IMAGine IP packaged
for ZCU-104 with example application projects.

Package organization,
```
/
├── ip: Contains the IMAGine IP for Vivado
├── sup: Contains supplementary files for evaluation
│   ├── ex01: A basic GEMV example
│   ├── ex02: A generic LSTM GEMV kernel
│   ├── ex03: An optimized LSTM GEMV kernel
│   ├── imagine_assembler: The assembler Python module
│   └── proj-zcu104: Files to set up ZCU-104 projects
└── work: Work area with setup commands (Makefile)
```
