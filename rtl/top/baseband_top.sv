//==============================================================================
// baseband_top.sv – Top-level with regional TBU + pruning + FFT kernels
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module baseband_top #(
  parameter int NUM_TILES   = 8,
  parameter int N_REGIONS   = 4,
  parameter int ALU_WIDTH   = 16
) (
  input  logic                       clk,
  input  logic                       rst_n,

  input  logic [31:0]                global_ops_request,
  input  logic                       global_ops_valid,

  // Shared FFT stimulus for this skeleton
  input  logic [ALU_WIDTH-1:0]       a_re, a_im,
  input  logic [ALU_WIDTH-1:0]       b_re, b_im,
  input  logic [ALU_WIDTH-1:0]       tw_re, tw_im,
  input  logic                       fft_in_valid,

  output logic [1:0]                 global_region_code,
  output logic                       envelope_alarm,
  output logic                       any_fft_valid
);

  logic [31:0] tile_ops_executed [NUM_TILES];
  logic [15:0] tile_throttle     [NUM_TILES];
  logic        tile_active       [NUM_TILES];
  logic        tile_fft_valid    [NUM_TILES];
  logic [1:0]  tile_prune_level  [NUM_TILES];

  //--------------------------------------------------------------------------
  // Regional thermal boundary control
  //--------------------------------------------------------------------------
  regional_tbc #(
    .N_TILES     (NUM_TILES),
    .N_REGIONS   (N_REGIONS),
    .OPS_WIDTH   (32),
    .POWER_WIDTH (24)
  ) u_regional_tbc (
    .clk                (clk),
    .rst_n              (rst_n),
    .tile_ops           (tile_ops_executed),
    .sample_valid       (global_ops_valid),
    .tile_throttle      (tile_throttle),
    .global_region_code (global_region_code),
    .envelope_alarm     (envelope_alarm)
  );

  //--------------------------------------------------------------------------
  // Tile array
  //--------------------------------------------------------------------------
  genvar t;
  generate
    for (t = 0; t < NUM_TILES; t++) begin : g_tiles
      compute_tile #(
        .TILE_ID   (t),
        .OPS_WIDTH (32),
        .ALU_WIDTH (ALU_WIDTH)
      ) u_tile (
        .clk              (clk),
        .rst_n            (rst_n),
        .ops_request      (global_ops_request),
        .ops_valid        (global_ops_valid),
        .throttle_q16     (tile_throttle[t]),
        .region_code      (global_region_code),
        .a_re             (a_re),
        .a_im             (a_im),
        .b_re             (b_re),
        .b_im             (b_im),
        .tw_re            (tw_re),
        .tw_im            (tw_im),
        .fft_in_valid     (fft_in_valid),
        .ops_executed     (tile_ops_executed[t]),
        .intensity_cap_hit(),
        .tile_active      (tile_active[t]),
        .a_out_re         (),
        .a_out_im         (),
        .b_out_re         (),
        .b_out_im         (),
        .fft_out_valid    (tile_fft_valid[t]),
        .prune_level      (tile_prune_level[t])
      );
    end
  endgenerate

  // OR-reduce FFT valids for a simple top-level observation
  always_comb begin
    any_fft_valid = 1'b0;
    for (int i = 0; i < NUM_TILES; i++)
      any_fft_valid |= tile_fft_valid[i];
  end

endmodule : baseband_top
