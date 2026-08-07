//==============================================================================
// regional_tbc.sv – Hierarchical Thermal Boundary Control
//
// Divides the tile array into regions.  Each region has its own local power
// estimate and throttle.  Cold regions stay fully open; only regions that
// approach or cross the thermal boundary are throttled.
//
// This realises the TBU principle that containment force should be applied
// locally where the action potential is high.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module regional_tbc #(
  parameter int N_TILES       = tbu_params_pkg::N_TILES,
  parameter int N_REGIONS     = 4,          // e.g. 4 quadrants
  parameter int OPS_WIDTH     = 32,
  parameter int POWER_WIDTH   = 24
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Per-tile activity (from the tile array)
  input  logic [OPS_WIDTH-1:0]       tile_ops       [N_TILES],
  input  logic                       sample_valid,

  // Per-tile throttle output (Q0.16)
  output logic [15:0]                tile_throttle  [N_TILES],

  // Global diagnostics
  output logic [1:0]                 global_region_code,
  output logic                       envelope_alarm
);

  localparam int TILES_PER_REGION = N_TILES / N_REGIONS;

  //--------------------------------------------------------------------------
  // Sum ops inside each region
  //--------------------------------------------------------------------------
  logic [OPS_WIDTH-1:0] region_ops [N_REGIONS];

  always_comb begin
    for (int r = 0; r < N_REGIONS; r++) begin
      region_ops[r] = '0;
      for (int t = 0; t < TILES_PER_REGION; t++)
        region_ops[r] += tile_ops[r*TILES_PER_REGION + t];
    end
  end

  //--------------------------------------------------------------------------
  // One TBCU instance per region
  //--------------------------------------------------------------------------
  logic [15:0] region_throttle [N_REGIONS];
  logic [1:0]  region_code     [N_REGIONS];
  logic        region_alarm    [N_REGIONS];

  genvar r;
  generate
    for (r = 0; r < N_REGIONS; r++) begin : g_region_tbc
      tbc_unit #(
        .N_TILES     (TILES_PER_REGION),
        .OPS_WIDTH   (OPS_WIDTH),
        .POWER_WIDTH (POWER_WIDTH)
      ) u_tbc (
        .clk                (clk),
        .rst_n              (rst_n),
        .total_ops_executed (region_ops[r]),
        .sample_valid       (sample_valid),
        .throttle_q16       (region_throttle[r]),
        .estimated_power_fp (),
        .region_code        (region_code[r]),
        .envelope_alarm     (region_alarm[r])
      );
    end
  endgenerate

  //--------------------------------------------------------------------------
  // Broadcast each region’s throttle to its tiles
  //--------------------------------------------------------------------------
  always_comb begin
    for (int r = 0; r < N_REGIONS; r++)
      for (int t = 0; t < TILES_PER_REGION; t++)
        tile_throttle[r*TILES_PER_REGION + t] = region_throttle[r];
  end

  //--------------------------------------------------------------------------
  // Global status = worst-case region
  //--------------------------------------------------------------------------
  always_comb begin
    envelope_alarm      = 1'b0;
    global_region_code  = 2'd2;               // assume FREE
    for (int r = 0; r < N_REGIONS; r++) begin
      if (region_alarm[r])
        envelope_alarm = 1'b1;
      // BOUND < BOUNDARY < FREE  → take the “hottest” code
      if (region_code[r] < global_region_code)
        global_region_code = region_code[r];
    end
  end

endmodule : regional_tbc
