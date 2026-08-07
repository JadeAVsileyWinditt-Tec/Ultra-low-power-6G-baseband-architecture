//==============================================================================
// compute_tile.sv – Compute tile with intensity limiter + approximate ALU
//
// Now couples algorithmic intensity reduction (approx_alu) with the
// thermal containment from the TBCU.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module compute_tile #(
  parameter int TILE_ID    = 0,
  parameter int OPS_WIDTH  = 32,
  parameter int ALU_WIDTH  = 16
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Workload request from scheduler / NoC
  input  logic [OPS_WIDTH-1:0]       ops_request,
  input  logic                       ops_valid,

  // Throttle from TBCU (global or regional)
  input  logic [15:0]                throttle_q16,

  // Optional direct approx control (1 = force approximate path)
  input  logic                       force_approx,

  // Simple ALU operands for this skeleton
  input  logic [ALU_WIDTH-1:0]       alu_a,
  input  logic [ALU_WIDTH-1:0]       alu_b,
  input  logic [2:0]                 alu_opcode,

  // Status back to TBCU / power monitor
  output logic [OPS_WIDTH-1:0]       ops_executed,
  output logic                       intensity_cap_hit,
  output logic                       tile_active,
  output logic [ALU_WIDTH-1:0]       alu_result,
  output logic                       alu_result_valid
);

  logic [OPS_WIDTH-1:0] ops_grant;

  //--------------------------------------------------------------------------
  // Intensity limiter (hard cap + soft TBU throttle)
  //--------------------------------------------------------------------------
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

  //--------------------------------------------------------------------------
  // Approximate ALU – enabled when throttle is low or force_approx is set
  //--------------------------------------------------------------------------
  // throttle_q16 is Q0.16; when it drops below 0.5 we prefer approximate ops
  logic approx_en;
  assign approx_en = force_approx | (throttle_q16 < 16'h8000);

  approx_alu #(
    .WIDTH      (ALU_WIDTH),
    .TRUNC_BITS (2)
  ) u_alu (
    .clk          (clk),
    .rst_n        (rst_n),
    .opcode       (alu_opcode),
    .approx_en    (approx_en),
    .op_a         (alu_a),
    .op_b         (alu_b),
    .result       (alu_result),
    .result_valid (alu_result_valid)
  );

  //--------------------------------------------------------------------------
  // Activity tracking
  //--------------------------------------------------------------------------
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
