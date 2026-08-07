//==============================================================================
// params.sv – Architectural parameters for the TBU-controlled 2048-tile
//             ultra-low-power 6G baseband fabric.
//
// Derived from the design specification and the Topological Boundary Unit
// (TBU) framework (Jade Siley-Winditt, 2026).
//==============================================================================

package tbu_params_pkg;

  //----------------------------------------------------------------------------
  // Fabric geometry
  //----------------------------------------------------------------------------
  localparam int N_TILES              = 2048;
  localparam int TILES_X              = 64;          // 64 × 32 mesh (example)
  localparam int TILES_Y              = 32;

  // Approximate transistor budget (~40 billion total)
  localparam longint TRANSISTORS_TOTAL = 40_000_000_000;
  localparam longint TRANSISTORS_PER_TILE = TRANSISTORS_TOTAL / N_TILES;

  //----------------------------------------------------------------------------
  // Intensity & energy targets
  //----------------------------------------------------------------------------
  // Local hard cap – prevents any single tile becoming a thermal hotspot
  localparam int INTENSITY_CAP_OPS_PER_TRANSISTOR = 700;

  // Derived max operations a tile may issue in one control epoch
  localparam longint MAX_OPS_PER_TILE =
      TRANSISTORS_PER_TILE * INTENSITY_CAP_OPS_PER_TRANSISTOR;

  // Target energy efficiency
  // 0.10 pJ/op = 0.10 × 10⁻¹² J/op
  // In fixed-point we will later use a scaled integer representation.
  localparam real ENERGY_PER_OP_PJ = 0.10;

  //----------------------------------------------------------------------------
  // Thermal envelope (critical boundary of the TBU)
  //----------------------------------------------------------------------------
  localparam real THERMAL_ENVELOPE_W = 4.0;

  // Boundary layer thickness δ (softness of the throttle)
  // Expressed as a fraction of the envelope for fixed-point convenience.
  localparam real TBU_DELTA_W = 0.20;

  // Containment strength (used by higher-level controllers)
  localparam real TBU_K = 12.0;

  //----------------------------------------------------------------------------
  // NoC & data-path widths
  //----------------------------------------------------------------------------
  localparam int NOC_ADDR_WIDTH  = 64;
  localparam int NOC_DATA_WIDTH  = 256;        // example high-bandwidth link
  localparam int TILE_ID_WIDTH   = $clog2(N_TILES);

  //----------------------------------------------------------------------------
  // Control epoch
  //----------------------------------------------------------------------------
  // How often the TBCU re-evaluates total power and updates throttles
  localparam int TBCU_EPOCH_CYCLES = 64;

endpackage : tbu_params_pkg
