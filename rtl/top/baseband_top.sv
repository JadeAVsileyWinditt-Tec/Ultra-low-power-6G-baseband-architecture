//==============================================================================
// baseband_top.sv – Minimal top-level for the TBU-controlled 6G baseband
//
// Instantiates:
//   - Array of compute tiles (parameterised, default small for sim)
//   - Thermal Boundary Control Unit (TBCU)
//   - Hierarchical NoC skeleton
//
// This is a structural skeleton so the full fabric can be elaborated
// and simulated.  Real RF front-end, pruning engine and full 2048-tile
// population will be added later.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module baseband_top #(
  // Use a small number of tiles for early simulation; set to N_TILES for full fabric
  parameter int NUM_TILES = 4
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Simple external workload interface (placeholder)
  input  logic [31:0]                global_ops_request,
  input  logic                       global_ops_valid,

  // Status
  output logic [15:0]                global_throttle_q16,
  output logic [1:0]                 global_region_code,
  output logic                       envelope_alarm
);

  //--------------------------------------------------------------------------
  // Per-tile signals
  //--------------------------------------------------------------------------
  logic [31:0] tile_ops_request  [NUM_TILES];
  logic        tile_ops_valid    [NUM_TILES];
  logic [31:0] tile_ops_executed [NUM_TILES];
  logic        tile_cap_hit      [NUM_TILES];
  logic        tile_active       [NUM_TILES];

  //--------------------------------------------------------------------------
  // Aggregate activity for TBCU
  //--------------------------------------------------------------------------
  logic [31:0] total_ops;
  always_comb begin
    total_ops = '0;
    for (int i = 0; i < NUM_TILES; i++)
      total_ops += tile_ops_executed[i];
  end

  //--------------------------------------------------------------------------
  // TBCU – continuous thermal boundary controller
  //--------------------------------------------------------------------------
  tbc_unit #(
    .N_TILES     (NUM_TILES),
    .OPS_WIDTH   (32),
    .POWER_WIDTH (24)
  ) u_tbc (
    .clk                (clk),
    .rst_n              (rst_n),
    .total_ops_executed (total_ops),
    .sample_valid       (global_ops_valid),
    .throttle_q16       (global_throttle_q16),
    .estimated_power_fp (),          // unused at top for now
    .region_code        (global_region_code),
    .envelope_alarm     (envelope_alarm)
  );

  //--------------------------------------------------------------------------
  // Tile array
  //--------------------------------------------------------------------------
  genvar t;
  generate
    for (t = 0; t < NUM_TILES; t++) begin : g_tiles
      // Simple broadcast of the global request for this skeleton
      assign tile_ops_request[t] = global_ops_request;
      assign tile_ops_valid[t]   = global_ops_valid;

      compute_tile #(
        .TILE_ID   (t),
        .OPS_WIDTH (32)
      ) u_tile (
        .clk              (clk),
        .rst_n            (rst_n),
        .ops_request      (tile_ops_request[t]),
        .ops_valid        (tile_ops_valid[t]),
        .throttle_q16     (global_throttle_q16),
        .ops_executed     (tile_ops_executed[t]),
        .intensity_cap_hit(tile_cap_hit[t]),
        .tile_active      (tile_active[t])
      );
    end
  endgenerate

  //--------------------------------------------------------------------------
  // NoC skeleton (not yet connected to real traffic)
  //--------------------------------------------------------------------------
  // hierarchical_noc #(.N_TILES(NUM_TILES)) u_noc (...);
  // Left unconnected in this first top-level – will be wired when
  // real packet interfaces are added to the tiles.

endmodule : baseband_top
