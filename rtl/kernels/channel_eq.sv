//==============================================================================
// channel_eq.sv – Per-subcarrier channel equalizer (zero-forcing style stub)
//
// For each complex sample Y and channel estimate H:
//   X_hat = Y / H   ≈ Y * conj(H) / |H|^2
//
// Uses approx ALU under thermal pressure.  This is a behavioural first cut
// suitable for demonstrating intensity reduction on a second major PHY kernel.
//==============================================================================

`timescale 1ns / 1ps

module channel_eq #(
  parameter int WIDTH = 16,
  parameter int N_SC  = 8          // subcarriers processed in parallel
) (
  input  logic                       clk,
  input  logic                       rst_n,

  input  logic                       approx_en,
  input  logic                       in_valid,

  // Received frequency-domain samples
  input  logic [WIDTH-1:0]           y_re [N_SC],
  input  logic [WIDTH-1:0]           y_im [N_SC],

  // Channel estimates
  input  logic [WIDTH-1:0]           h_re [N_SC],
  input  logic [WIDTH-1:0]           h_im [N_SC],

  // Equalized outputs
  output logic                       out_valid,
  output logic [WIDTH-1:0]           x_re [N_SC],
  output logic [WIDTH-1:0]           x_im [N_SC]
);

  genvar i;
  generate
    for (i = 0; i < N_SC; i++) begin : g_eq
      logic [WIDTH-1:0] conj_h_im;
      logic [WIDTH-1:0] num_re, num_im;
      logic [WIDTH-1:0] mag2;
      logic [WIDTH-1:0] inv_mag2;

      assign conj_h_im = (~h_im[i]) + 1'b1;   // crude two's complement negate

      // num = Y * conj(H)
      logic [WIDTH-1:0] yr_hr, yi_hi, yr_hi, yi_hr;
      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_yrhr (
        .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
        .op_a(y_re[i]), .op_b(h_re[i]), .result(yr_hr), .result_valid()
      );
      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_yihi (
        .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
        .op_a(y_im[i]), .op_b(h_im[i]), .result(yi_hi), .result_valid()
      );
      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_yrhi (
        .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
        .op_a(y_re[i]), .op_b(h_im[i]), .result(yr_hi), .result_valid()
      );
      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_yihr (
        .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
        .op_a(y_im[i]), .op_b(h_re[i]), .result(yi_hr), .result_valid()
      );

      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_numre (
        .clk(clk), .rst_n(rst_n), .opcode(3'd0), .approx_en(approx_en),
        .op_a(yr_hr), .op_b(yi_hi), .result(num_re), .result_valid()
      );
      // imag part: yi*hr - yr*hi  (simplified)
      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_numim (
        .clk(clk), .rst_n(rst_n), .opcode(3'd1), .approx_en(approx_en),
        .op_a(yi_hr), .op_b(yr_hi), .result(num_im), .result_valid()
      );

      // |H|^2 ≈ hr*hr + hi*hi  (approx)
      logic [WIDTH-1:0] hr2, hi2;
      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_hr2 (
        .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
        .op_a(h_re[i]), .op_b(h_re[i]), .result(hr2), .result_valid()
      );
      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_hi2 (
        .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
        .op_a(h_im[i]), .op_b(h_im[i]), .result(hi2), .result_valid()
      );
      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_mag (
        .clk(clk), .rst_n(rst_n), .opcode(3'd0), .approx_en(approx_en),
        .op_a(hr2), .op_b(hi2), .result(mag2), .result_valid()
      );

      // Crude inverse: for stub use shift-based approx when mag2 != 0
      // Real design would use reciprocal LUT / Newton
      assign inv_mag2 = (mag2 == '0) ? {WIDTH{1'b1}} : (16'h7FFF / mag2[7:0]);

      approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_xre (
        .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
        .op_a(num_re), .op_
