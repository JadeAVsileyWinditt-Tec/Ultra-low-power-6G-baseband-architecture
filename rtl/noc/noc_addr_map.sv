//==============================================================================
// noc_addr_map.sv – Hierarchical address map for the 64-bit NoC
//
// Converts a linear tile ID into:
//   - (x, y) mesh coordinates
//   - region ID
//   - hierarchical route tag
//
// This is the addressing foundation for the ~10¹⁸ combinatorial path claim
// and for scaling the NoC from the current skeleton to the full fabric.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module noc_addr_map #(
  parameter int N_TILES   = tbu_params_pkg::N_TILES,   // 2048
  parameter int TILES_X   = tbu_params_pkg::TILES_X,   // 64
  parameter int TILES_Y   = tbu_params_pkg::TILES_Y,   // 32
  parameter int N_REGIONS = 4
) (
  input  logic [$clog2(N_TILES)-1:0] tile_id,

  output logic [$clog2(TILES_X)-1:0] x,
  output logic [$clog2(TILES_Y)-1:0] y,
  output logic [$clog2(N_REGIONS)-1:0] region_id,

  // Simple hierarchical route tag:
  //   [region | y_hi | x_hi | y_lo | x_lo]
  output logic [63:0]                route_tag
);

  // Linear ID → 2-D coordinates (row-major)
  assign x = tile_id % TILES_X;
  assign y = tile_id / TILES_X;

  // Region: quadrant-style split
  //   0 = top-left, 1 = top-right, 2 = bottom-left, 3 = bottom-right
  logic x_hi, y_hi;
  assign x_hi = (x >= TILES_X/2);
  assign y_hi = (y >= TILES_Y/2);
  assign region_id = {y_hi, x_hi};

  // Pack a 64-bit route tag (plenty of room for future virtual channels, QoS, etc.)
  always_comb begin
    route_tag = 64'b0;
    route_tag[1:0]   = region_id;
    route_tag[7:2]   = y[$clog2(TILES_Y)-1:0];   // full y
    route_tag[13:8]  = x[$clog2(TILES_X)-1:0];   // full x
    // upper bits reserved for VC, priority, multicast, etc.
  end

endmodule : noc_addr_map
