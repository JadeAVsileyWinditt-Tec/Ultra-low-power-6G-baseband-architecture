//==============================================================================
// fabric_slice.sv – Reusable hierarchical slice with visible control status
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module fabric_slice #(
  parameter int NUM_TILES      = 8,
  parameter int N_REGIONS      = 4,
  parameter int ALU_WIDTH      = 16,
  parameter int N_BUTTERFLIES  = 4,
  parameter int SLICE_ID       = 0
) (
  input  logic                       clk,
  input  logic                       rst_n,

  input  logic [31:0]                ops_request,
  input  logic                       ops_valid,
  input  logic                       fft_in_valid,
  input  logic [ALU_WIDTH-1:0]       in_re  [N_BUTTERFLIES*2],
  input  logic [ALU_WIDTH-1:0]       in_im  [N_BUTTERFLIES*2],
  input  logic [ALU_WIDTH-1:0]       tw_re  [N_BUTTERFLIES],
  input  logic [ALU_WIDTH-1:0]       tw_im  [N_BUTTERFLIES],

  output logic [1:0]                 region_code,
  output logic                       envelope_alarm,
  output logic                       any_fft_valid,

  // NEW – observable control state
  output logic [15:0]                mean_throttle_q16,
  output logic [1:0]                 max_prune_level
);

  logic [31:0] tile_ops        [NUM_TILES];
  logic [15:0] tile_throttle   [NUM_TILES];
  logic        tile_fft_valid  [NUM_TILES];
  logic [1:0]  tile_prune      [NUM_TILES];
  logic [63:0] tile_route_tag  [NUM_TILES];

  regional_tbc #(
    .N_TILES     (NUM_TILES),
    .N_REGIONS   (N_REGIONS),
    .OPS_WIDTH   (32),
    .POWER_WIDTH (24)
  ) u_tbc (
    .clk                (clk),
    .rst_n              (rst_n),
    .tile_ops           (tile_ops),
    .sample_valid       (ops_valid),
    .tile_throttle      (tile_throttle),
    .global_region_code (region_code),
    .envelope_alarm     (envelope_alarm)
  );

  genvar t;
  generate
    for (t = 0; t < NUM_TILES; t++) begin : g_tiles
      noc_addr_map #(
        .N_TILES(N_TILES), .TILES_X(TILES_X), .TILES_Y(TILES_Y), .N_REGIONS(N_REGIONS)
      ) u_addr (
        .tile_id(SLICE_ID*NUM_TILES + t),
        .x(), .y(), .region_id(), .route_tag(tile_route_tag[t])
      );

      dsp_tile #(
        .TILE_ID(SLICE_ID*NUM_TILES + t),
        .OPS_WIDTH(32), .ALU_WIDTH(ALU_WIDTH), .N_BUTTERFLIES(N_BUTTERFLIES)
      ) u_dsp (
        .clk(clk), .rst_n(rst_n),
        .ops_request(ops_request), .ops_valid(ops_valid),
        .throttle_q16(tile_throttle[t]), .region_code(region_code),
        .fft_in_valid(fft_in_valid),
        .in_re(in_re), .in_im(in_im), .tw_re(tw_re), .tw_im(tw_im),
        .ops_executed(tile_ops[t]),
        .intensity_cap_hit(), .tile_active(),
        .prune_level(tile_prune[t]),
        .fft_out_valid(tile_fft_valid[t]),
        .out_re(), .out_im()
      );
    end
  endgenerate

  // Aggregate observables
  always_comb begin
    any_fft_valid = 1'b0;
    mean_throttle_q16 = '0;
    max_prune_level = 2'd0;
    for (int i = 0; i < NUM_TILES; i++) begin
      any_fft_valid |= tile_fft_valid[i];
      mean_throttle_q16 += tile_throttle[i] / NUM_TILES;
      if (tile_prune[i] > max_prune_level)
        max_prune_level = tile_prune[i];
    end
  end

endmodule : fabric_slice
