# Development and implementation steps of IMAGine

## Design Steps

1. [ ] Clean up existing tests
2. [x] Automate the GEMV test
3. [x] Modify the controller to add required register stages
4. [x] Implement the column-shift-register module
5. [x] Implement the GEMV tile
   1. [x] Modify PIM for column-shift-reg interface
   2. [x] Implement the PIM array
   3. [x] Connect controller and the fanout tree
6. [x] Build the tile array
7. [ ] Connect the tile array with column-shift-reg module
   1. [ ] Run tests
8. [ ] Design the front-end controller
   1. [ ] Design the controller FSMs
   2. [ ] Run tests
   3. [x] Learn to work with FIFO (Ask Tendayi)
9.  [ ] Add top-level fanout tree
10. [ ] Connect everything and run tests
    1.  [ ] Run PnR and rerun tests
11. [ ] Go to implementation without crossing clock domain
12. [ ] Port to Tendayi's SoC


## Implementation Steps

* 100 MHz implementation for hardware validation of the IP
  1. [ ] Tile array
  2. [ ] + colulmn-shif-reg
  3. [ ] + top-level fanout tree
  4. [ ] + front-end FSM
  5. [ ] + FIFOs

* 730 MHz implementation in the same order as above
  1. [ ] Tile array
  2. [ ] + colulmn-shif-reg
  3. [ ] + top-level fanout tree
  4. [ ] + front-end FSM
  5. [ ] + FIFOs

* Integration with SoC
    1. [ ] Convert to IP
    2. [ ] Run at lower frequency: 100 MHz
    3. [ ] Run at target frequency: 720 MHz



## Tentative Timeline


|              Task                      | Timeframe
|----------------------------------------|-----------
| Clean up tests                         | Jan 25-26
| Modify controller                      | Jan 29-30
| Implement column-shif-reg              | Jan 31 - Feb 06
| Implement GEMV tile                    | Feb 07 - Feb 09
| Build tile array                       | Feb 12
| Connect tile array and column-shift-reg| Feb 13-14
| Design front-end                       | Feb 15-21
| Add top-level fanout                   | Feb 22
| Connect everything and test            | Feb 23-26
| 100 MHz implementation                 | Feb 27 - Mar 01
| 730 MHz implementation                 | Mar 4-8
| SoC integration                        | Mar 11-15


* Implement GEMV tile subtasks
   1. Modify PIM and build array: 1 day
   3. Connect controller and fanout: 1 day
   4. Implement and test: 1 day
