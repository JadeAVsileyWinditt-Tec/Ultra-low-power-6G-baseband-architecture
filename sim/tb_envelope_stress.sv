//==============================================================================
// tb_envelope_stress.sv – Envelope stress + live TBU assertions
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module tb_envelope_stress;

  logic clk, rst_n;
  initial begin clk = 0; forever #5 clk = ~clk; end

  localparam int W = 16;
  localparam int N_BF = 4;

  logic [31:0] ops_request;
  logic        ops_valid, fft_in_valid;
  logic [W-1:0] in_re [N_BF*2], in_im [N_BF*2];
  logic [W-1:0] tw_re [N_BF], tw_im [N_BF];
  logic [1:0]  region_code;
  logic        envelope_alarm, any_fft_valid;

  full_fabric_top #(
    .NUM_TILES       (16),
    .TILES_PER_SLICE (8),
    .N_REGIONS       (4),
    .ALU_WIDTH       (W),
    .N_BUTTERFLIES   (N_BF)
  ) u_dut (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .ops_request           (ops_request),
    .ops_valid             (ops_valid),
    .fft_in_valid          (fft_in_valid),
    .in_re                 (in_re),
    .in_im                 (in_im),
    .tw_re                 (tw_re),
    .tw_im                 (tw_im),
    .global_region_code    (region_code),
    .global_envelope_alarm (envelope_alarm),
    .any_fft_valid         (any_fft_valid)
  );

  // Live safety checks
  tbu_assertions #(.OPS_WIDTH(32)) u_assert (
    .clk            (clk),
    .rst_n          (rst_n),
    .ops_executed   (ops_request),   // proxy for this stress view
    .throttle_q16   (16'h8000),      // placeholder – tighten when throttle is exported
    .region_code    (region_code),
    .envelope_alarm (envelope_alarm),
    .sample_valid   (ops_valid)
  );

  string region_name;
  always_comb case (region_code)
    2'd0: region_name = "BOUND";
    2'd1: region_name = "BOUNDARY";
    2'd2: region_name = "FREE";
    default: region_name = "???";
  endcase

  integer i;
  initial begin
    rst_n = 0;
    ops_request = 0; ops_valid = 0; fft_in_valid = 0;
    for (i = 0; i < N_BF*2; i++) begin
      in_re[i] = 16'h0100 + i; in_im[i] = 16'h0020 + i;
    end
    for (i = 0; i < N_BF; i++) begin
      tw_re[i] = 16'h00B0; tw_im[i] = 16'h0030;
    end

    repeat (20) @(posedge clk);
    rst_n = 1;
    repeat (10) @(posedge clk);

    $display("=== ENVELOPE STRESS + ASSERTIONS ===");
    $display("phase     ops_req     region     alarm  fft");

    $display("-- ramp --");
    for (i = 0; i < 8; i++) begin
      ops_request  = 32'd5_000_000 * (i + 1);
      ops_valid    = 1; fft_in_valid = 1;
      @(posedge clk);
      ops_valid = 0; fft_in_valid = 0;
      repeat (3) @(posedge clk);
      $display("ramp    %10d  %-8s   %0d     %0d",
               ops_request, region_name, envelope_alarm, any_fft_valid);
    end

    $display("-- stress --");
    for (i = 0; i < 12; i++) begin
      ops_request  = 32'd80_000_000 + i * 32'd25_000_000;
      ops_valid    = 1; fft_in_valid = 1;
      @(posedge clk);
      ops_valid = 0; fft_in_valid = 0;
      repeat (3) @(posedge clk);
      $display("stress  %10d  %-8s   %0d     %0d",
               ops_request, region_name, envelope_alarm, any_fft_valid);
    end

    $display("-- cool --");
    for (i = 0; i < 6; i++) begin
      ops_request  = 32'd3_000_000;
      ops_valid    = 1; fft_in_valid = 1;
      @(posedge clk);
      ops_valid = 0; fft_in_valid = 0;
      repeat (3) @(posedge clk);
      $display("cool    %10d  %-8s   %0d     %0d",
               ops_request, region_name, envelope_alarm, any_fft_valid);
    end

    $display("=== STRESS TEST FINISHED ===");
    $finish;
  end

endmodule : tb_envelope_stress
