//==============================================================================
// tb_symbol_chain.sv – FFT → EQ under FREE / BOUNDARY / BOUND
//==============================================================================

`timescale 1ns / 1ps

module tb_symbol_chain;

  logic clk, rst_n;
  initial begin clk = 0; forever #5 clk = ~clk; end

  localparam int W = 16;
  localparam int N_BF = 4;
  localparam int N_ST = 3;
  localparam int N_SC = 8;

  logic approx_en, skip_noncritical;
  logic [1:0] prune_level;
  logic in_valid, out_valid;
  logic [W-1:0] in_re [N_SC], in_im [N_SC];
  logic [W-1:0] tw_re [N_ST][N_BF], tw_im [N_ST][N_BF];
  logic [W-1:0] h_re [N_SC], h_im [N_SC];
  logic [W-1:0] x_re [N_SC], x_im [N_SC];

  symbol_chain #(
    .WIDTH(W), .N_BUTTERFLIES(N_BF), .N_STAGES(N_ST), .N_SC(N_SC)
  ) u_dut (
    .clk(clk), .rst_n(rst_n),
    .approx_en(approx_en), .skip_noncritical(skip_noncritical),
    .prune_level(prune_level),
    .in_valid(in_valid), .in_re(in_re), .in_im(in_im),
    .tw_re(tw_re), .tw_im(tw_im), .h_re(h_re), .h_im(h_im),
    .out_valid(out_valid), .x_re(x_re), .x_im(x_im)
  );

  integer i, s;
  initial begin
    rst_n = 0;
    approx_en = 0; skip_noncritical = 0; prune_level = 0; in_valid = 0;
    for (i = 0; i < N_SC; i++) begin
      in_re[i] = 16'h0100 + i*4; in_im[i] = 16'h0020 + i;
      h_re[i] = 16'h00C0; h_im[i] = 16'h0010;
    end
    for (s = 0; s < N_ST; s++)
      for (i = 0; i < N_BF; i++) begin
        tw_re[s][i] = 16'h00B0; tw_im[s][i] = 16'h0030;
      end

    repeat (12) @(posedge clk); rst_n = 1; repeat (4) @(posedge clk);

    $display("=== Symbol Chain (FFT→EQ) ===");
    $display("mode       approx  skip  prune  out_valid  x_re0");

    approx_en = 0; skip_noncritical = 0; prune_level = 0;
    in_valid = 1; @(posedge clk); in_valid = 0;
    repeat (N_ST + 6) @(posedge clk);
    $display("FREE       %0d      %0d     %0d      %0d         0x%04h",
             approx_en, skip_noncritical, prune_level, out_valid, x_re[0]);

    approx_en = 1; skip_noncritical = 0; prune_level = 1;
    in_valid = 1; @(posedge clk); in_valid = 0;
    repeat (N_ST + 6) @(posedge clk);
    $display("BOUNDARY   %0d      %0d     %0d      %0d         0x%04h",
             approx_en, skip_noncritical, prune_level, out_valid, x_re[0]);

    approx_en = 1; skip_noncritical = 1; prune_level = 2;
    in_valid = 1; @(posedge clk); in_valid = 0;
    repeat (N_ST + 6) @(posedge clk);
    $display("BOUND      %0d      %0d     %0d      %0d         0x%04h",
             approx_en, skip_noncritical, prune_level, out_valid, x_re[0]);

    $display("=== Symbol chain test finished ===");
    $finish;
  end

endmodule : tb_symbol_chain
