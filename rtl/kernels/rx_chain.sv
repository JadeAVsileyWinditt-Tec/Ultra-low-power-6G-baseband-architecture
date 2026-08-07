//==============================================================================
// rx_chain.sv – Complete minimal OFDM receive path
//
//   time-domain input → multi-stage FFT → channel EQ → soft demap → LLRs
//
// Fully coupled to TBU pruning:
//   FREE      – full path, high quality
//   BOUNDARY  – approximate arithmetic
//   BOUND     – skip EQ/demap as allowed, max intensity cut
//==============================================================================

`timescale 1ns / 1ps

module rx_chain #(
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
  output logic [WIDTH-1:0]           llr0   [N_SC],
  output logic [WIDTH-1:0]           llr1   [N_SC]
);

  logic                 sym_valid;
  logic [WIDTH-1:0]     x_re [N_SC];
  logic [WIDTH-1:0]     x_im [N_SC];

  symbol_chain #(
    .WIDTH(WIDTH), .N_BUTTERFLIES(N_BUTTERFLIES),
    .N_STAGES(N_STAGES), .N_SC(N_SC)
  ) u_symbol (
    .clk(clk), .rst_n(rst_n),
    .approx_en(approx_en), .skip_noncritical(skip_noncritical),
    .prune_level(prune_level),
    .in_valid(in_valid),
    .in_re(in_re), .in_im(in_im),
    .tw_re(tw_re), .tw_im(tw_im),
    .h_re(h_re), .h_im(h_im),
    .out_valid(sym_valid),
    .x_re(x_re), .x_im(x_im)
  );

  // Under aggressive skip, demap still runs on whatever symbols we have
  soft_demap #(
    .WIDTH(WIDTH), .N_SC(N_SC), .TRUNC(2)
  ) u_demap (
    .clk(clk), .rst_n(rst_n),
    .approx_en(approx_en),
    .in_valid(sym_valid),
    .x_re(x_re), .x_im(x_im),
    .out_valid(out_valid),
    .llr0(llr0), .llr1(llr1)
  );

endmodule : rx_chain
