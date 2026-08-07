//==============================================================================
// compute_tile.sv – Full tile: intensity limiter + pruning + FFT butterfly
//
// Intensity reduction now comes from two cooperating mechanisms:
//   1. TBCU thermal throttle  (containment force)
//   2. Pruning controller     (algorithmic approx / skip)
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

  // Workload
  input  logic [OPS_WIDTH-1:0]       ops_request,
  input  logic                       ops_valid,

  // From regional / global TBCU
  input  logic [15:0]                throttle_q16,
  input  logic [1:0]                 region_code,

  // FFT kernel inputs (complex pair + twiddle)
  input  logic [ALU_WIDTH-1:0]       a_re, a_im,
  input  logic [ALU_WIDTH-1:0]       b_re, b_im,
  input  logic [ALU_WIDTH-1:0]       tw_re, tw_im,
  input  logic                       fft_in_valid,

  // Status / results
  output logic [OPS_WIDTH-1:0]       ops_executed,
  output logic                       intensity_cap_hit,
  output logic                       tile_active,
  output logic [ALU_WIDTH-1:0]       a_out_re, a_out_im,
  output logic [ALU_WIDTH-1:0]       b_out_re, b_out_im,
  output logic                       fft_out_valid,
  output logic [1:0]                 prune_level
);

  logic [OPS_WIDTH-1:0] ops_grant;
  logic                 approx_en;
  logic                 skip_noncritical;

  //--------------------------------------------------------------------------
  // Intensity limiter
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
  // Pruning controller (algorithmic intensity reduction)
  //--------------------------------------------------------------------------
  pruning_controller u_prune (
    .clk              (clk),
    .rst_n            (rst_n),
    .throttle_q16     (throttle_q16),
    .region_code      (region_code),
    .approx_en        (approx_en),
    .prune_level      (prune_level),
    .skip_noncritical (skip_noncritical)
  );

  //--------------------------------------------------------------------------
  // FFT butterfly kernel (uses approx ALU when approx_en is high)
  //--------------------------------------------------------------------------
  logic fft_fire;
  assign fft_fire = fft_in_valid & ~skip_noncritical;

  fft_butterfly #(
    .WIDTH(ALU_WIDTH)
  ) u_fft (
    .clk        (clk),
    .rst_n      (rst_n),
    .approx_en  (approx_en),
    .in_valid   (fft_fire),
    .a_re       (a_re),
    .a_im       (a_im),
    .b_re       (b_re),
    .b_im       (b_im),
    .tw_re      (tw_re),
    .tw_im      (tw_im),
    .a_out_re   (a_out_re),
    .a_out_im   (a_out_im),
    .b_out_re   (b_out_re),
    .b_out_im   (b_out_im),
    .out_valid  (fft_out_valid)
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
