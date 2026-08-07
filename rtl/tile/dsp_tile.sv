//==============================================================================
// dsp_tile.sv – DSP-oriented tile that hosts an OFDM FFT stage
//
// Combines:
//   - Intensity limiter + TBU throttle
//   - Pruning controller
//   - ofdm_fft_stage (parallel butterflies)
//
// This is the first specialised tile type in the fabric.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module dsp_tile #(
  parameter int TILE_ID         = 0,
  parameter int OPS_WIDTH       = 32,
  parameter int ALU_WIDTH       = 16,
  parameter int N_BUTTERFLIES   = 4
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Workload / control from fabric
  input  logic [OPS_WIDTH-1:0]       ops_request,
  input  logic                       ops_valid,
  input  logic [15:0]                throttle_q16,
  input  logic [1:0]                 region_code,

  // FFT stage input vector
  input  logic                       fft_in_valid,
  input  logic [ALU_WIDTH-1:0]       in_re  [N_BUTTERFLIES*2],
  input  logic [ALU_WIDTH-1:0]       in_im  [N_BUTTERFLIES*2],
  input  logic [ALU_WIDTH-1:0]       tw_re  [N_BUTTERFLIES],
  input  logic [ALU_WIDTH-1:0]       tw_im  [N_BUTTERFLIES],

  // Status + results
  output logic [OPS_WIDTH-1:0]       ops_executed,
  output logic                       intensity_cap_hit,
  output logic                       tile_active,
  output logic [1:0]                 prune_level,
  output logic                       fft_out_valid,
  output logic [ALU_WIDTH-1:0]       out_re [N_BUTTERFLIES*2],
  output logic [ALU_WIDTH-1:0]       out_im [N_BUTTERFLIES*2]
);

  logic [OPS_WIDTH-1:0] ops_grant;
  logic                 approx_en;
  logic                 skip_noncritical;

  //--------------------------------------------------------------------------
  // Intensity limiter
  //--------------------------------------------------------------------------
  intensity_limiter #(.OPS_WIDTH(OPS_WIDTH)) u_limiter (
    .clk              (clk),
    .rst_n            (rst_n),
    .ops_request      (ops_request),
    .throttle_q16     (throttle_q16),
    .ops_grant        (ops_grant),
    .intensity_cap_hit(intensity_cap_hit)
  );

  //--------------------------------------------------------------------------
  // Pruning controller
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
  // OFDM FFT stage
  //--------------------------------------------------------------------------
  ofdm_fft_stage #(
    .WIDTH         (ALU_WIDTH),
    .N_BUTTERFLIES (N_BUTTERFLIES)
  ) u_fft_stage (
    .clk              (clk),
    .rst_n            (rst_n),
    .approx_en        (approx_en),
    .skip_noncritical (skip_noncritical),
    .in_valid         (fft_in_valid),
    .in_re            (in_re),
    .in_im            (in_im),
    .tw_re            (tw_re),
    .tw_im            (tw_im),
    .out_valid        (fft_out_valid),
    .out_re           (out_re),
    .out_im           (out_im)
  );

  //--------------------------------------------------------------------------
  // Activity
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

endmodule : dsp_tile
