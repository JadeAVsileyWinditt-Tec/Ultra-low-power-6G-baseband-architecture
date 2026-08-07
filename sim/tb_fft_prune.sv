//==============================================================================
// tb_fft_prune.sv – Testbench for FFT butterfly under pruning + TBU pressure
//
// Shows that as thermal region moves BOUNDARY → BOUND, the pruning controller
// enables approximate arithmetic and the butterfly still produces results.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module tb_fft_prune;

  logic clk, rst_n;
  initial begin clk = 0; forever #5 clk = ~clk; end

  //--------------------------------------------------------------------------
  // DUT – single tile focused on FFT path
  //--------------------------------------------------------------------------
  logic [31:0] ops_request;
  logic        ops_valid;
  logic [15:0] throttle_q16;
  logic [1:0]  region_code;

  logic [15:0] a_re, a_im, b_re, b_im, tw_re, tw_im;
  logic        fft_in_valid;
  logic [15:0] a_out_re, a_out_im, b_out_re, b_out_im;
  logic        fft_out_valid;
  logic [1:0]  prune_level;
  logic [31:0] ops_executed;
  logic        tile_active;

  compute_tile #(
    .TILE_ID   (0),
    .OPS_WIDTH (32),
    .ALU_WIDTH (16)
  ) u_tile (
    .clk              (clk),
    .rst_n            (rst_n),
    .ops_request      (ops_request),
    .ops_valid        (ops_valid),
    .throttle_q16     (throttle_q16),
    .region_code      (region_code),
    .a_re             (a_re),
    .a_im             (a_im),
    .b_re             (b_re),
    .b_im             (b_im),
    .tw_re            (tw_re),
    .tw_im            (tw_im),
    .fft_in_valid     (fft_in_valid),
    .ops_executed     (ops_executed),
    .intensity_cap_hit(),
    .tile_active      (tile_active),
    .a_out_re         (a_out_re),
    .a_out_im         (a_out_im),
    .b_out_re         (b_out_re),
    .b_out_im         (b_out_im),
    .fft_out_valid    (fft_out_valid),
    .prune_level      (prune_level)
  );

  string region_name;
  always_comb begin
    case (region_code)
      2'd0: region_name = "BOUND";
      2'd1: region_name = "BOUNDARY";
      2'd2: region_name = "FREE";
      default: region_name = "???";
    endcase
  end

  //--------------------------------------------------------------------------
  // Stimulus
  //--------------------------------------------------------------------------
  initial begin
    rst_n = 0;
    ops_request = 0; ops_valid = 0;
    throttle_q16 = 16'hFFFF;
    region_code  = 2'd2;
    a_re = 16'h0100; a_im = 16'h0010;
    b_re = 16'h0080; b_im = 16'h0020;
    tw_re = 16'h00C0; tw_im = 16'h0040;
    fft_in_valid = 0;

    repeat (15) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);

    $display("=== FFT + Pruning Test ===");
    $display("region    throttle  prune  fft_valid  a_out_re");

    // FREE – full quality
    region_code  = 2'd2;
    throttle_q16 = 16'hFFFF;
    fft_in_valid = 1; ops_valid = 1; ops_request = 32'd1000;
    @(posedge clk);
    fft_in_valid = 0; ops_valid = 0;
    repeat (4) @(posedge clk);
    $display("%-8s  0x%04h    %0d      %0d         0x%04h",
             region_name, throttle_q16, prune_level, fft_out_valid, a_out_re);

    // BOUNDARY – light pruning + approx
    region_code  = 2'd1;
    throttle_q16 = 16'hA000;
    fft_in_valid = 1; ops_valid = 1; ops_request = 32'd5000;
    @(posedge clk);
    fft_in_valid = 0; ops_valid = 0;
    repeat (4) @(posedge clk);
    $display("%-8s  0x%04h    %0d      %0d         0x%04h",
             region_name, throttle_q16, prune_level, fft_out_valid, a_out_re);

    // BOUND – aggressive pruning
    region_code  = 2'd0;
    throttle_q16 = 16'h4000;
    fft_in_valid = 1; ops_valid = 1; ops_request = 32'd20000;
    @(posedge clk);
    fft_in_valid = 0; ops_valid = 0;
    repeat (4) @(posedge clk);
    $display("%-8s  0x%04h    %0d      %0d         0x%04h",
             region_name, throttle_q16, prune_level, fft_out_valid, a_out_re);

    $display("=== Test finished ===");
    $finish;
  end

endmodule : tb_fft_prune
