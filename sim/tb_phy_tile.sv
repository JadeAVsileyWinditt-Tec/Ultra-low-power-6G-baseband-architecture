//==============================================================================
// tb_phy_tile.sv – PHY tile TX + RX under TBU regions
//==============================================================================

`timescale 1ns / 1ps

module tb_phy_tile;

  logic clk, rst_n;
  initial begin clk = 0; forever #5 clk = ~clk; end

  localparam int W = 16;
  localparam int N_BF = 4;
  localparam int N_ST = 3;
  localparam int N_SC = 8;

  logic [31:0] ops_request;
  logic ops_valid, mode_tx, in_valid, out_valid;
  logic [15:0] throttle_q16;
  logic [1:0] region_code, prune_level;
  logic [W-1:0] in_re [N_SC], in_im [N_SC];
  logic [1:0] bits [N_SC];
  logic [W-1:0] tw_re [N_ST][N_BF], tw_im [N_ST][N_BF];
  logic [W-1:0] h_re [N_SC], h_im [N_SC];
  logic [W-1:0] out_re [N_SC], out_im [N_SC];
  logic [W-1:0] llr0 [N_SC], llr1 [N_SC];

  phy_tile #(
    .TILE_ID(0), .WIDTH(W), .N_BUTTERFLIES(N_BF),
    .N_STAGES(N_ST), .N_SC(N_SC)
  ) u_dut (
    .clk(clk), .rst_n(rst_n),
    .ops_request(ops_request), .ops_valid(ops_valid),
    .throttle_q16(throttle_q16), .region_code(region_code),
    .mode_tx(mode_tx), .in_valid(in_valid),
    .in_re(in_re), .in_im(in_im), .bits(bits),
    .tw_re(tw_re), .tw_im(tw_im), .h_re(h_re), .h_im(h_im),
    .ops_executed(), .intensity_cap_hit(), .tile_active(),
    .prune_level(prune_level), .out_valid(out_valid),
    .out_re(out_re), .out_im(out_im), .llr0(llr0), .llr1(llr1)
  );

  integer i, s;
  initial begin
    rst_n = 0;
    ops_request = 0; ops_valid = 0; mode_tx = 0; in_valid = 0;
    throttle_q16 = 16'hFFFF; region_code = 2'd2;
    for (i = 0; i < N_SC; i++) begin
      in_re[i] = 16'h0100+i; in_im[i] = 16'h0020+i;
      bits[i] = i[1:0]; h_re[i] = 16'h00C0; h_im[i] = 16'h0010;
    end
    for (s = 0; s < N_ST; s++)
      for (i = 0; i < N_BF; i++) begin
        tw_re[s][i] = 16'h00B0; tw_im[s][i] = 16'h0020;
      end

    repeat (12) @(posedge clk); rst_n = 1; repeat (4) @(posedge clk);

    $display("=== PHY Tile TX/RX ===");

    // RX FREE
    mode_tx = 0; region_code = 2'd2; throttle_q16 = 16'hFFFF;
    in_valid = 1; ops_valid = 1; ops_request = 1000;
    @(posedge clk); in_valid = 0; ops_valid = 0;
    repeat (N_ST+8) @(posedge clk);
    $display("RX FREE      prune=%0d valid=%0d llr0=0x%04h", prune_level, out_valid, llr0[0]);

    // TX BOUNDARY
    mode_tx = 1; region_code = 2'd1; throttle_q16 = 16'h9000;
    in_valid = 1; ops_valid = 1; ops_request = 5000;
    @(posedge clk); in_valid = 0; ops_valid = 0;
    repeat (N_ST+8) @(posedge clk);
    $display("TX BOUNDARY  prune=%0d valid=%0d out_re=0x%04h", prune_level, out_valid, out_re[0]);

    // RX BOUND
    mode_tx = 0; region_code = 2'd0; throttle_q16 = 16'h3000;
    in_valid = 1; ops_valid = 1; ops_request = 20000;
    @(posedge clk); in_valid = 0; ops_valid = 0;
    repeat (N_ST+8) @(posedge clk);
    $display("RX BOUND     prune=%0d valid=%0d llr0=0x%04h", prune_level, out_valid, llr0[0]);

    $display("=== PHY tile test finished ===");
    $finish;
  end

endmodule : tb_phy_tile
