//==============================================================================
// mimo_detect.sv – 2x2 MIMO ZF detector stub (approx-aware)
//
// Solves Y = H X + N  for X using a simplified zero-forcing path.
// Under approx_en, multiplies use truncated arithmetic to cut intensity.
//==============================================================================

`timescale 1ns / 1ps

module mimo_detect #(
  parameter int WIDTH = 16
) (
  input  logic                       clk,
  input  logic                       rst_n,
  input  logic                       approx_en,
  input  logic                       in_valid,

  // Received Y (2 antennas), channel H (2x2)
  input  logic [WIDTH-1:0]           y0_re, y0_im, y1_re, y1_im,
  input  logic [WIDTH-1:0]           h00_re, h00_im, h01_re, h01_im,
  input  logic [WIDTH-1:0]           h10_re, h10_im, h11_re, h11_im,

  output logic                       out_valid,
  output logic [WIDTH-1:0]           x0_re, x0_im, x1_re, x1_im
);

  // Stub: matched-filter style combine (not full inverse)
  // x0 ≈ h00* y0 + h10* y1   (conj multiply approximated as real path for skeleton)
  logic [WIDTH-1:0] t0, t1, t2, t3;

  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u0 (
    .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
    .op_a(h00_re), .op_b(y0_re), .result(t0), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u1 (
    .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
    .op_a(h10_re), .op_b(y1_re), .result(t1), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u2 (
    .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
    .op_a(h01_re), .op_b(y0_re), .result(t2), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) u3 (
    .clk(clk), .rst_n(rst_n), .opcode(3'd2), .approx_en(approx_en),
    .op_a(h11_re), .op_b(y1_re), .result(t3), .result_valid()
  );

  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) ua (
    .clk(clk), .rst_n(rst_n), .opcode(3'd0), .approx_en(approx_en),
    .op_a(t0), .op_b(t1), .result(x0_re), .result_valid()
  );
  approx_alu #(.WIDTH(WIDTH), .TRUNC_BITS(2)) ub (
    .clk(clk), .rst_n(rst_n), .opcode(3'd0), .approx_en(approx_en),
    .op_a(t2), .op_b(t3), .result(x1_re), .result_valid()
  );

  // imag paths held simple for stub
  assign x0_im = y0_im;
  assign x1_im = y1_im;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'b0;
    else        out_valid <= in_valid;
  end

endmodule : mimo_detect
