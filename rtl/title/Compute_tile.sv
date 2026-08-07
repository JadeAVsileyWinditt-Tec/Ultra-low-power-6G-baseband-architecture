//==============================================================================
// compute_tile.sv – Minimal behavioural tile skeleton
//
// Contains:
//   - Local intensity limiter (TBU containment)
//   - Placeholder for approximate arithmetic units
//   - Simple activity counter for power estimation
//
// Future work: full datapath, approximate ALU, AI-pruned kernels.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module compute_tile #(
  parameter int TILE_ID    = 0,
  parameter int OPS_WIDTH  = 32
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Workload request from scheduler / NoC
  input  logic [OPS_WIDTH-1:0]       ops_request,
  input  logic                       ops_valid,

  // Throttle from TBCU (global or regional)
  input  logic [15:0]                throttle_q16,

  // Status back to TBCU / power monitor
  output logic [OPS_WIDTH-1:0]       ops_executed,
  output logic                       intensity_cap_hit,
  output logic                       tile_active
);

  logic [OPS_WIDTH-1:0] ops_grant;

  intensity_limiter #(
    .OPS_WIDTH(OPS_WIDTH)
  ) u_limiter (
    .clk              (clk),
    .rst_n            (rst_n),
    .ops_request      (ops_request),
    .throttle_q16     (throttle_q16),
    .ops_grant        (ops_grant),
    .intensity_cap_hit(intensity_cap_hit)
  );

  // Simple activity register – in a real design this would be the
  // cycle-accurate execution pipeline.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ops_executed <= '0;
      tile_active  <= 1'b0;
    end else if (ops_valid) begin
      ops_executed <= ops_grant;
      tile_active  <= (ops_grant != '0);
    end else begin
      ops_executed <= '0;
      tile_active  <= 1'b0;
    end
  end

endmodule : compute_tile
