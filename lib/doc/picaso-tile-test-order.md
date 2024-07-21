# Test and development order for PiCaSO tile and its submodules

## Test order:

1. [x] picaso controller submodules
2. [x] picaso controller
3. [ ] picaso array 2D
4. [ ] Tile inflow: commands/data
5. [ ] picaso-read-network submodules
6. [ ] picaso-read-network
7. [ ] picaso response module
8. [ ] Tile outflow: reads
9. [ ] Entire picaso tile


## Dependency graph (order)
```
picaso-tile (9)
|
|- Tile inflow: commands/data (4)
|  |- picaso-controller (2)
|  |   `- test submodules (1)
|  |
|  `- picaso-array-2D (3)
|
`- Tile outflow: reads (8)
   |- picaso-read-network (6)
   |  `- test submodules (5)
   |
   `- picaso-response-module (7)
```
