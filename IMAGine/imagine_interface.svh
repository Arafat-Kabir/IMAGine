// Defines the parameters and datatypes for the imagine_interface module.
// This is not supposed to be reusable. This should be implemented as a package
// in the future. Include this file within a module.

localparam IMAGINE_INSTR_WIDTH = 32;

// AK-NOTE: instruction format is defined in the _imagineIntf_fetchDispatch module

// Submodule selection codes
localparam IMAGINE_SUBMODULE_CODE_WIDTH = 2;
localparam [IMAGINE_SUBMODULE_CODE_WIDTH-1:0] 
  IMAGINE_SUBMODULE_GEMVARR_SELECT  = 0,     // submodule selection code
  IMAGINE_SUBMODULE_VECSHIFT_SELECT = 1;    // submodule selection code
