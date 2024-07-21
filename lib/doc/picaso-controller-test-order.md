# Test order for picaso_controller submodules

## Test order:

1. [x] loop_counter
2. [x] transition_tables
   1. [x] aluop
3. [x] algo_fsm
4. [x] up_counter
5. [x] algo_var_man
6. [x] algo_decoder
7. [x] multicycle_driver
8. [x] instr_fsm
9.  [x] outmux
10. [x] singlecycle_driver
11. [x] instr_decoder
12. [ ] instr_valid_ff
13. [ ] instruction_reg
14. [ ] picaso_controller



## Dependency graph (order)
```
picaso_controller (14)
|
|- multicycle_driver (7)
|  |- algo_fsm (3)
|  |   |- loop_counter (1)
|  |   `- tran_tables (2)
|  |
|  |- algo_var_man (5)
|  |   `- up_counter (4)
|  |
|  `- algo_decoder (6)
|
|- instr_fsm (8)
|- outmux (9)
|- singlecycle_driver (10)
|- instruction_reg (11)
|- instr_valid_ff (12)
`- instr_decoder (13)
```
