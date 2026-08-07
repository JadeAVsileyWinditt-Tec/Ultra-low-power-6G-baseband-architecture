//==============================================================================
// ofdm_fft_stage.sv – One stage of a radix-2 OFDM FFT (pipeline stub)
//
// Instantiates multiple butterflies in parallel.  When the pruning controller
// raises approx_en / skip_noncritical, the stage automatically reduces
// computational intensity while still producing output samples.
//
// This is the first concrete 6G baseband kernel block in the fabric.
//==============================================================================

`timescale 1ns / 1ps

module ofdm_fft_stage #(
  parameter int WIDTH        = 16,
  parameter int N_BUTTERFLIES = 4          // parallel butterflies this stage
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // From pruning / TBU
  input  logic                       approx_en,
  input  logic                       skip_noncritical,

  // Input vector (interleaved complex pairs)
  input  logic                       in_valid,
  input  logic [WIDTH-1:0]           in_re  [N_BUTTERFLIES*2],
  input  logic [WIDTH-1:0]           in_im  [N_BUTTERFLIES*2],
  input  logic [WIDTH-1:0]           tw_re  [N_BUTTERFLIES],
  input  logic [WIDTH-1:0]           tw_im  [N_BUTTERFLIES],

  // Output vector
  output logic                       out_valid,
  output logic [WIDTH-1:0]           out_re [N_BUTTERFLIES*2],
  output logic [WIDTH-1:0]           out_im [N_BUTTERFLIES*2]
);

  logic [N_BUTTERFLIES-1:0] bf_valid;

  genvar i;
  generate
    for (i = 0; i < N_BUTTERFLIES; i++) begin : g_bf
      fft_butterfly #(
        .WIDTH(WIDTH)
      ) u_bf (
        .clk        (clk),
        .rst_n      (rst_n),
        .approx_en  (approx_en),
        .in_valid   (in_valid & ~skip_noncritical),
        .a_re       (in_re[2*i]),
        .a_im       (in_im[2*i]),
        .b_re       (in_re[2*i+1]),
        .b_im       (in_im[2*i+1]),
        .tw_re      (tw_re[i]),
        .tw_im      (tw_im[i]),
        .a_out_re   (out_re[2*i]),
        .a_out_im   (out_im[2*i]),
        .b_out_re   (out_re[2*i+1]),
        .b_out_im   (out_im[2*i+1]),
        .out_valid  (bf_valid[i])
      );
    end
  endgenerate

  // Stage valid when all butterflies have produced a result
  // (or when the stage was skipped under aggressive pruning)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      out_valid <= 1'b0;
    else if (skip_noncritical)
      out_valid <= in_valid;          // pass-through / drop semantics
    else
      out_valid <= &bf_valid;
  end

endmodule : ofdm_fft_stage
