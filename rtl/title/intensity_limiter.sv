//==============================================================================
// intensity_limiter.sv
//
// Local hardware intensity limiter that realises the per-tile intensity
// cap (≤ 700 ops / transistor) and accepts a global/regional throttle
// factor from the Thermal Boundary Control Unit (TBCU).
//
// This is the lowest-level hardware expression of the TBU containment
// force acting on a single tile.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module intensity_limiter #(
  parameter int OPS_WIDTH = 32
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Requested operation count for the next epoch
  input  logic [OPS_WIDTH-1:0]       ops_request,

  // Throttle factor from TBCU (fixed-point 0.16, 1.0 = 16'hFFFF)
  input  logic [15:0]                throttle_q16,

  // Gated / limited operation grant
  output logic [OPS_WIDTH-1:0]       ops_grant,

  // Diagnostic: whether the local intensity cap was hit
  output logic                       intensity_cap_hit
);

  //--------------------------------------------------------------------------
  // Local intensity hard-cap (constant)
  //--------------------------------------------------------------------------
  localparam logic [OPS_WIDTH-1:0] MAX_OPS =
      MAX_OPS_PER_TILE[OPS_WIDTH-1:0];

  logic [OPS_WIDTH-1:0] capped_ops;
  logic [OPS_WIDTH+16-1:0] throttled_ops_wide;

  always_comb begin
    // 1. Hard local intensity ceiling
    if (ops_request > MAX_OPS) begin
      capped_ops        = MAX_OPS;
      intensity_cap_hit = 1'b1;
    end else begin
      capped_ops        = ops_request;
      intensity_cap_hit = 1'b0;
    end

    // 2. Apply soft TBU throttle (Q0.16 × integer)
    throttled_ops_wide = capped_ops * throttle_q16;
    ops_grant          = throttled_ops_wide[OPS_WIDTH+15:16];  // drop fractional bits
  end

endmodule : intensity_limiter
