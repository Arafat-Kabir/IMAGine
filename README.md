# IMAGine : An In-Memory Accelerated GEMV Engine Overlay

## Paper Abstract
Processor-in-Memory (PIM) overlays and alternative 
reconfigurable tile fabrics have been proposed to eliminate
the von Neumann bottleneck and enable processing performance
to scale with BRAM capacity. The performance of these FPGA-based 
PIM architectures has been limited due to a reduction of
the BRAMs maximum clock frequencies and less than ideal scaling 
of processing elements with increased BRAM capacity. 
This work presents IMAGine, an In-Memory Accelerated GEMV
engine, a PIM-array accelerator that clocks at the maximum
frequency of the BRAM and scales to 100% of the available
BRAMs. Comparative analyses are presented showing execution
speeds over existing PIM-based GEMV engines on FPGAs
and achieving a 2.65× – 3.2× faster clock. An AMD Alveo
U55 implementation is presented that achieves a system clock
speed of 737 MHz, providing 64K bit-serial multiply-accumulate
(MAC) units for GEMV operation. This establishes IMAGine
as the fastest PIM-based GEMV overlay, outperforming even
the custom PIM-based FPGA accelerators reported to date.
Additionally, it surpasses TPU v1-v2 and Alibaba Hanguang 800
in clock speed while offering an equal or greater number of
multiply-accumulate (MAC) units.


## Publications
M. A. Kabir et al., "IMAGine: An In-Memory Accelerated GEMV Engine Overlay," 2024 34th International Conference on Field-Programmable Logic and Applications (FPL), Torino, Italy, 2024, pp. 220-226, doi: 10.1109/FPL64840.2024.00038. [IEEE](https://ieeexplore.ieee.org/abstract/document/10705594), [arXive](https://arxiv.org/abs/2410.04367), [extended arXive](https://arxiv.org/pdf/2410.07546)


## Summary
IMAGine is a Processor-in-Memory architecture-based GEMV accelerator overlay.
It is the fastest and most scalable PIM-array based FPGA GEMV accelerator, 
that clocks faster than TPU v1-v2 on AMD's Ultrascale+ devices.
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

## Tutorials
1. [Setting up the Vivado Project](https://www.youtube.com/watch?v=tfgE1RbGvGw&list=PLnlOAW0JmWhr_gEKckim1y-9r5rjl5bWq&index=2)
2. [Writing the Vitis application](https://www.youtube.com/watch?v=FghzXWm2aVg&list=PLnlOAW0JmWhr_gEKckim1y-9r5rjl5bWq&index=3)
3. [Configuring and using the assembler](https://www.youtube.com/watch?v=4GFyqh0fIAM&list=PLnlOAW0JmWhr_gEKckim1y-9r5rjl5bWq&index=4)
