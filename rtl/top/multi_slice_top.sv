//==============================================================================
// multi_slice_top.sv – Multiple fabric slices stitched together
//
// This is the structural step between a single slice and the full 2048-tile
// fabric.  Each slice carries its own regional TBCU, DSP tiles, and NoC
// address map.  A thin top-level aggregates status.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module multi_slice_top #(
  parameter int N_SLICES       = 4,
  parameter int TILES_PER_SLICE = 8,
  parameter int N_REGIONS      = 4,
  parameter int ALU_WIDTH      = 16,
  parameter int N_BUTTERFLIES  = 4
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

  output logic [1:0]                 global_region_code,
  output logic                       global_envelope_alarm,
  output logic                       any_fft_valid
);

  logic [1:0]  slice_region [N_SLICES];
  logic        slice_alarm  [N_SLICES];
  logic        slice_fft    [N_SLICES];

  genvar s;
  generate
    for (s = 0; s < N_SLICES; s++) begin : g_slices
      fabric_slice #(
        .NUM_TILES     (TILES_PER_SLICE),
        .N_REGIONS     (N_REGIONS),
        .ALU_WIDTH     (ALU_WIDTH),
        .N_BUTTERFLIES (N_BUTTERFLIES),
        .SLICE_ID      (s)
      ) u_slice (
        .clk            (clk),
        .rst_n          (rst_n),
        .ops_request    (ops_request),
        .ops_valid      (ops_valid),
        .fft_in_valid   (fft_in_valid),
        .in_re          (in_re),
        .in_im          (in_im),
        .tw_re          (tw_re),
        .tw_im          (tw_im),
        .region_code    (slice_region[s]),
        .envelope_alarm (slice_alarm[s]),
        .any_fft_valid  (slice_fft[s])
      );
    end
  endgenerate

  // Global status = hottest region + any alarm + any FFT activity
  always_comb begin
    global_envelope_alarm = 1'b0;
    global_region_code    = 2'd2;   // FREE
    any_fft_valid         = 1'b0;
    for (int i = 0; i < N_SLICES; i++) begin
      if (slice_alarm[i])
        global_envelope_alarm = 1'b1;
      if (slice_region[i] < global_region_code)
        global_region_code = slice_region[i];
      if (slice_fft[i])
        any_fft_valid = 1'b1;
    end
  end

endmodule : multi_slice_top
