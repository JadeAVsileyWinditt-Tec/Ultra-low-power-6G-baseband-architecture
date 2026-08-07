//==============================================================================
// ofdm_fft_pipeline.sv – Multi-stage radix-2 OFDM FFT pipeline
//
// Chains N_STAGES of ofdm_fft_stage.  Under thermal pressure the pruning
// controller can force approximate arithmetic and/or skip stages.
//
// This is the first deeper 6G PHY datapath in the architecture.
//==============================================================================

`timescale 1ns / 1ps

module ofdm_fft_pipeline #(
  parameter int WIDTH         = 16,
  parameter int N_BUTTERFLIES = 4,
  parameter int N_STAGES      = 3          // depth of the pipeline
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // From pruning / TBU
  input  logic                       approx_en,
  input  logic                       skip_noncritical,
  input  logic [1:0]                 prune_level,

  // Input vector
  input  logic                       in_valid,
  input  logic [WIDTH-1:0]           in_re  [N_BUTTERFLIES*2],
  input  logic [WIDTH-1:0]           in_im  [N_BUTTERFLIES*2],
  input  logic [WIDTH-1:0]           tw_re  [N_STAGES][N_BUTTERFLIES],
  input  logic [WIDTH-1:0]           tw_im  [N_STAGES][N_BUTTERFLIES],

  // Output vector (after all stages)
  output logic                       out_valid,
  output logic [WIDTH-1:0]           out_re [N_BUTTERFLIES*2],
  output logic [WIDTH-1:0]           out_im [N_BUTTERFLIES*2]
);

  // Pipeline registers between stages
  logic [WIDTH-1:0] stage_re [N_STAGES+1][N_BUTTERFLIES*2];
  logic [WIDTH-1:0] stage_im [N_STAGES+1][N_BUTTERFLIES*2];
  logic             stage_valid [N_STAGES+1];

  // Stage 0 input
  assign stage_re[0]    = in_re;
  assign stage_im[0]    = in_im;
  assign stage_valid[0] = in_valid;

  genvar s;
  generate
    for (s = 0; s < N_STAGES; s++) begin : g_stages
      // Under aggressive prune, later stages can be skipped
      logic skip_this;
      assign skip_this = skip_noncritical && (prune_level >= 2) && (s > 0);

      ofdm_fft_stage #(
        .WIDTH         (WIDTH),
        .N_BUTTERFLIES (N_BUTTERFLIES)
      ) u_stage (
        .clk              (clk),
        .rst_n            (rst_n),
        .approx_en        (approx_en),
        .skip_noncritical (skip_this),
        .in_valid         (stage_valid[s]),
        .in_re            (stage_re[s]),
        .in_im            (stage_im[s]),
        .tw_re            (tw_re[s]),
        .tw_im            (tw_im[s]),
        .out_valid        (stage_valid[s+1]),
        .out_re           (stage_re[s+1]),
        .out_im           (stage_im[s+1])
      );
    end
  endgenerate

  assign out_valid = stage_valid[N_STAGES];
  assign out_re    = stage_re[N_STAGES];
  assign out_im    = stage_im[N_STAGES];

endmodule : ofdm_fft_pipeline
