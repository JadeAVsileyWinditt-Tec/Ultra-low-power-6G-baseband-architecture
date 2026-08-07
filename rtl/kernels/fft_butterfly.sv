//==============================================================================
// fft_butterfly.sv – Radix-2 butterfly for OFDM / 6G baseband processing
//
// Classic complex butterfly:
//   A' = A + twiddle * B
//   B' = A - twiddle * B
//
// When approx_en is asserted the multiplies and adds use the approximate
// ALU path, cutting switching activity (intensity reduction).
//==============================================================================

`timescale 1ns / 1ps

module fft_butterfly #(
  parameter int WIDTH = 16
) (
  input  logic                       clk,
  input  logic                       rst_n,

  input  logic                       approx_en,
  input  logic                       in_valid,

  // Complex inputs {imag, real}
  input  logic [WIDTH-1:0]           a_re, a_im,
  input  logic [WIDTH-1:0]           b_re, b_im,
  input  logic [WIDTH-1:0]           tw_re, tw_im,   // twiddle factor

  output logic [WIDTH-1:0]           a_out_re, a_out_im,
  output logic [WIDTH-1:0]           b_out_re, b_out_im,
  output logic                       out_valid
);

  //--------------------------------------------------------------------------
  // Twiddle * B  (complex multiply)
  //   (tw_re + j tw_im) * (b_re + j b_im)
  //   = (tw_re*b_re - tw_im*b_im) + j (tw_re*b_im + tw_im*b_re)
  //--------------------------------------------------------------------------
  logic [WIDTH-1:0] mul_rr, mul_ii, mul_ri, mul_ir;
  logic [WIDTH-1:0] tw_b_re, tw_b_im;

  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_mul_rr (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd2), .approx_en(approx_en),
    .op_a(tw_re), .op_b(b_re),
    .result(mul_rr), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_mul_ii (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd2), .approx_en(approx_en),
    .op_a(tw_im), .op_b(b_im),
    .result(mul_ii), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_mul_ri (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd2), .approx_en(approx_en),
    .op_a(tw_re), .op_b(b_im),
    .result(mul_ri), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_mul_ir (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd2), .approx_en(approx_en),
    .op_a(tw_im), .op_b(b_re),
    .result(mul_ir), .result_valid()
  );

  // Real / imag parts of twiddle*B
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_tw_re (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd1), .approx_en(approx_en),   // SUB
    .op_a(mul_rr), .op_b(mul_ii),
    .result(tw_b_re), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_tw_im (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd0), .approx_en(approx_en),   // ADD
    .op_a(mul_ri), .op_b(mul_ir),
    .result(tw_b_im), .result_valid()
  );

  //--------------------------------------------------------------------------
  // A' = A + tw*B    B' = A - tw*B
  //--------------------------------------------------------------------------
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_a_re (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd0), .approx_en(approx_en),
    .op_a(a_re), .op_b(tw_b_re),
    .result(a_out_re), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_a_im (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd0), .approx_en(approx_en),
    .op_a(a_im), .op_b(tw_b_im),
    .result(a_out_im), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_b_re (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd1), .approx_en(approx_en),
    .op_a(a_re), .op_b(tw_b_re),
    .result(b_out_re), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u_b_im (
    .clk(clk), .rst_n(rst_n),
    .opcode(3'd1), .approx_en(approx_en),
    .op_a(a_im), .op_b(tw_b_im),
    .result(b_out_im), .result_valid()
  );

  // Simple 1-cycle valid pipeline (approximation of latency)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      out_valid <= 1'b0;
    else
      out_valid <= in_valid;
  end

endmodule : fft_butterfly
