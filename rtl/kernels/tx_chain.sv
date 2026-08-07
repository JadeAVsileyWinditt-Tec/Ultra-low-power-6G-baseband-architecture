//==============================================================================
// tx_chain.sv – Transmit path: constellation map → multi-stage IFFT
//
// IFFT is realised with the same ofdm_fft_pipeline (conjugate / reorder
// handled externally in a full design; here we reuse the pipeline as the
// transform engine under TBU intensity control).
//==============================================================================

`timescale 1ns / 1ps

module tx_chain #(
  parameter int WIDTH         = 16,
  parameter int N_BUTTERFLIES = 4,
  parameter int N_STAGES      = 3,
  parameter int N_SC          = 8
) (
  input  logic                       clk,
  input  logic                       rst_n,

  input  logic                       approx_en,
  input  logic                       skip_noncritical,
  input  logic [1:0]                 prune_level,

  input  logic                       in_valid,
  input  logic [1:0]                 bits   [N_SC],
  input  logic [WIDTH-1:0]           tw_re  [N_STAGES][N_BUTTERFLIES],
  input  logic [WIDTH-1:0]           tw_im  [N_STAGES][N_BUTTERFLIES],

  output logic                       out_valid,
  output logic [WIDTH-1:0]           out_re [N_SC],
  output logic [WIDTH-1:0]           out_im [N_SC]
);

  logic                 map_valid;
  logic [WIDTH-1:0]     s_re [N_SC];
  logic [WIDTH-1:0]     s_im [N_SC];

  constellation_map #(
    .WIDTH(WIDTH), .N_SC(N_SC)
  ) u_map (
    .clk(clk), .rst_n(rst_n),
    .approx_en(approx_en),
    .in_valid(in_valid),
    .bits(bits),
    .out_valid(map_valid),
    .s_re(s_re), .s_im(s_im)
  );

  // Under aggressive skip, bypass transform and emit mapped symbols
  logic fft_in_valid;
  assign fft_in_valid = map_valid & ~skip_noncritical;

  logic                 fft_valid;
  logic [WIDTH-1:0]     fft_re [N_SC];
  logic [WIDTH-1:0]     fft_im [N_SC];

  ofdm_fft_pipeline #(
    .WIDTH(WIDTH), .N_BUTTERFLIES(N_BUTTERFLIES), .N_STAGES(N_STAGES)
  ) u_ifft (
    .clk(clk), .rst_n(rst_n),
    .approx_en(approx_en),
    .skip_noncritical(1'b0),   // transform itself not skipped mid-pipeline here
    .prune_level(prune_level),
    .in_valid(fft_in_valid),
    .in_re(s_re), .in_im(s_im),
    .tw_re(tw_re), .tw_im(tw_im),
    .out_valid(fft_valid),
    .out_re(fft_re), .out_im(fft_im)
  );

  always_comb begin
    if (skip_noncritical) begin
      out_valid = map_valid;
      out_re    = s_re;
      out_im    = s_im;
    end else begin
      out_valid = fft_valid;
      out_re    = fft_re;
      out_im    = fft_im;
    end
  end

endmodule : tx_chain
