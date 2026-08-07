//==============================================================================
// tb_fabric_slice.sv – Testbench for one hierarchical fabric slice
//
// Drives ops + FFT traffic into a fabric_slice and observes regional
// thermal state, pruning behaviour, and FFT completion.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module tb_fabric_slice;

  logic clk, rst_n;
  initial begin clk = 0; forever #5 clk = ~clk; end

  localparam int N_BF = 4;
  localparam int W    = 16;

  logic [31:0] ops_request;
  logic        ops_valid;
  logic        fft_in_valid;
  logic [W-1:0] in_re [N_BF*2];
  logic [W-1:0] in_im [N_BF*2];
  logic [W-1:0] tw_re [N_BF];
  logic [W-1:0] tw_im [N_BF];

  logic [1:0]  region_code;
  logic        envelope_alarm;
  logic        any_fft_valid;

  fabric_slice #(
    .NUM_TILES     (8),
    .N_REGIONS     (4),
    .ALU_WIDTH     (W),
    .N_BUTTERFLIES (N_BF),
    .SLICE_ID      (0)
  ) u_slice (
    .clk            (clk),
    .rst_n          (rst_n),
    .ops_request    (ops_request),
    .ops_valid      (ops_valid),
    .fft_in_valid   (fft_in_valid),
    .in_re          (in_re),
    .in_im          (in_im),
    .tw_re          (tw_re),
    .tw_im          (tw_im),
    .region_code    (region_code),
    .envelope_alarm (envelope_alarm),
    .any_fft_valid  (any_fft_valid)
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

  integer i;
  initial begin
    rst_n = 0;
    ops_request = 0; ops_valid = 0; fft_in_valid = 0;
    for (i = 0; i < N_BF*2; i++) begin
      in_re[i] = 16'h0100 + i;
      in_im[i] = 16'h0010 + i;
    end
    for (i = 0; i < N_BF; i++) begin
      tw_re[i] = 16'h00C0;
      tw_im[i] = 16'h0040;
    end

    repeat (20) @(posedge clk);
    rst_n = 1;
    repeat (10) @(posedge clk);

    $display("=== Fabric Slice Test ===");
    $display("time     ops      region     alarm  fft_valid");

    // Light load
    for (i = 0; i < 6; i++) begin
      ops_request  = 32'd5_000_000 + i * 32'd1_000_000;
      ops_valid    = 1;
      fft_in_valid = 1;
      @(posedge clk);
      ops_valid = 0; fft_in_valid = 0;
      repeat (4) @(posedge clk);
      $display("%0t  %8d  %-8s   %0d     %0d",
               $time, ops_request, region_name, envelope_alarm, any_fft_valid);
    end

    // Heavy load
    $display("--- heavy ---");
    for (i = 0; i < 8; i++) begin
      ops_request  = 32'd60_000_000 + i * 32'd20_000_000;
      ops_valid    = 1;
      fft_in_valid = 1;
      @(posedge clk);
      ops_valid = 0; fft_in_valid = 0;
      repeat (4) @(posedge clk);
      $display("%0t  %8d  %-8s   %0d     %0d",
               $time, ops_request, region_name, envelope_alarm, any_fft_valid);
    end

    $display("=== Test finished ===");
    $finish;
  end

endmodule : tb_fabric_slice
