//==============================================================================
// tb_fft_pipeline.sv – Multi-stage OFDM FFT under TBU + pruning pressure
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module tb_fft_pipeline;

  logic clk, rst_n;
  initial begin clk = 0; forever #5 clk = ~clk; end

  localparam int W = 16;
  localparam int N_BF = 4;
  localparam int N_ST = 3;

  logic [31:0] ops_request;
  logic        ops_valid;
  logic [15:0] throttle_q16;
  logic [1:0]  region_code;

  logic        fft_in_valid, fft_out_valid;
  logic [W-1:0] in_re [N_BF*2], in_im [N_BF*2];
  logic [W-1:0] out_re [N_BF*2], out_im [N_BF*2];
  logic [W-1:0] tw_re [N_ST][N_BF], tw_im [N_ST][N_BF];
  logic [1:0]  prune_level;
  logic        tile_active;

  dsp_tile_pipeline #(
    .TILE_ID(0), .OPS_WIDTH(32), .ALU_WIDTH(W),
    .N_BUTTERFLIES(N_BF), .N_STAGES(N_ST)
  ) u_tile (
    .clk(clk), .rst_n(rst_n),
    .ops_request(ops_request), .ops_valid(ops_valid),
    .throttle_q16(throttle_q16), .region_code(region_code),
    .fft_in_valid(fft_in_valid),
    .in_re(in_re), .in_im(in_im), .tw_re(tw_re), .tw_im(tw_im),
    .ops_executed(), .intensity_cap_hit(), .tile_active(tile_active),
    .prune_level(prune_level),
    .fft_out_valid(fft_out_valid),
    .out_re(out_re), .out_im(out_im)
  );

  string region_name;
  always_comb case (region_code)
    2'd0: region_name = "BOUND";
    2'd1: region_name = "BOUNDARY";
    2'd2: region_name = "FREE";
    default: region_name = "???";
  endcase

  integer i, s;
  initial begin
    rst_n = 0;
    ops_request = 0; ops_valid = 0; fft_in_valid = 0;
    throttle_q16 = 16'hFFFF; region_code = 2'd2;

    for (i = 0; i < N_BF*2; i++) begin
      in_re[i] = 16'h0100 + i*3; in_im[i] = 16'h0020 + i;
    end
    for (s = 0; s < N_ST; s++)
      for (i = 0; i < N_BF; i++) begin
        tw_re[s][i] = 16'h00C0 - s*8; tw_im[s][i] = 16'h0040 + s*4;
      end

    repeat (15) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);

    $display("=== Multi-stage FFT Pipeline Test ===");
    $display("region    thr     prune  fft_out  out_re0");

    region_code = 2'd2; throttle_q16 = 16'hFFFF;
    fft_in_valid = 1; ops_valid = 1; ops_request = 32'd2000;
    @(posedge clk); fft_in_valid = 0; ops_valid = 0;
    repeat (N_ST + 4) @(posedge clk);
    $display("%-8s  0x%04h  %0d      %0d       0x%04h",
             region_name, throttle_q16, prune_level, fft_out_valid, out_re[0]);

    region_code = 2'd1; throttle_q16 = 16'h9000;
    fft_in_valid = 1; ops_valid = 1; ops_request = 32'd8000;
    @(posedge clk); fft_in_valid = 0; ops_valid = 0;
    repeat (N_ST + 4) @(posedge clk);
    $display("%-8s  0x%04h  %0d      %0d       0x%04h",
             region_name, throttle_q16, prune_level, fft_out_valid, out_re[0]);

    region_code = 2'd0; throttle_q16 = 16'h3000;
    fft_in_valid = 1; ops_valid = 1; ops_request = 32'd20000;
    @(posedge clk); fft_in_valid = 0; ops_valid = 0;
    repeat (N_ST + 4) @(posedge clk);
    $display("%-8s  0x%04h  %0d      %0d       0x%04h",
             region_name, throttle_q16, prune_level, fft_out_valid, out_re[0]);

    $display("=== Pipeline test finished ===");
    $finish;
  end

endmodule : tb_fft_pipeline
