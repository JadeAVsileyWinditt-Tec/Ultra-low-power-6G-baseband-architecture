//==============================================================================
// symbol_chain.sv – Receive symbol path: multi-stage FFT → channel EQ
//==============================================================================

`timescale 1ns / 1ps

module symbol_chain #(
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
  input  logic [WIDTH-1:0]           in_re  [N_SC],
  input  logic [WIDTH-1:0]           in_im  [N_SC],
  input  logic [WIDTH-1:0]           tw_re  [N_STAGES][N_BUTTERFLIES],
  input  logic [WIDTH-1:0]           tw_im  [N_STAGES][N_BUTTERFLIES],

  input  logic [WIDTH-1:0]           h_re   [N_SC],
  input  logic [WIDTH-1:0]           h_im   [N_SC],

  output logic                       out_valid,
  output logic [WIDTH-1:0]           x_re   [N_SC],
  output logic [WIDTH-1:0]           x_im   [N_SC]
);

  logic                 fft_valid;
  logic [WIDTH-1:0]     fft_re [N_SC];
  logic [WIDTH-1:0]     fft_im [N_SC];

  ofdm_fft_pipeline #(
    .WIDTH(WIDTH), .N_BUTTERFLIES(N_BUTTERFLIES), .N_STAGES(N_STAGES)
  ) u_fft (
    .clk(clk), .rst_n(rst_n),
    .approx_en(approx_en), .skip_noncritical(skip_noncritical),
    .prune_level(prune_level),
    .in_valid(in_valid), .in_re(in_re), .in_im(in_im),
    .tw_re(tw_re), .tw_im(tw_im),
    .out_valid(fft_valid), .out_re(fft_re), .out_im(fft_im)
  );

  logic eq_in_valid;
  assign eq_in_valid = fft_valid & ~skip_noncritical;

  logic                 eq_valid;
  logic [WIDTH-1:0]     eq_re [N_SC];
  logic [WIDTH-1:0]     eq_im [N_SC];

  channel_eq #(.WIDTH(WIDTH), .N_SC(N_SC)) u_eq (
    .clk(clk), .rst_n(rst_n), .approx_en(approx_en),
    .in_valid(eq_in_valid),
    .y_re(fft_re), .y_im(fft_im),
    .h_re(h_re), .h_im(h_im),
    .out_valid(eq_valid), .x_re(eq_re), .x_im(eq_im)
  );

  always_comb begin
    if (skip_noncritical) begin
      out_valid = fft_valid;
      x_re = fft_re; x_im = fft_im;
    end else begin
      out_valid = eq_valid;
      x_re = eq_re; x_im = eq_im;
    end
  end

endmodule : symbol_chain
