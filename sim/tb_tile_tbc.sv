//==============================================================================
// tb_tile_tbc.sv – Minimal testbench for one compute tile + TBCU
//
// Drives a rising workload, lets the Thermal Boundary Control Unit react,
// and prints power / throttle / region behaviour.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module tb_tile_tbc;

  //--------------------------------------------------------------------------
  // Clock & reset
  //--------------------------------------------------------------------------
  logic clk;
  logic rst_n;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;          // 100 MHz
  end

  //--------------------------------------------------------------------------
  // DUT signals
  //--------------------------------------------------------------------------
  logic [31:0] ops_request;
  logic        ops_valid;
  logic [15:0] throttle_q16;
  logic [31:0] ops_executed;
  logic        intensity_cap_hit;
  logic        tile_active;

  logic [31:0] total_ops_executed;
  logic        sample_valid;
  logic [23:0] estimated_power_fp;
  logic [1:0]  region_code;
  logic        envelope_alarm;

  //--------------------------------------------------------------------------
  // Instantiate one tile
  //--------------------------------------------------------------------------
  compute_tile #(
    .TILE_ID   (0),
    .OPS_WIDTH (32)
  ) u_tile (
    .clk              (clk),
    .rst_n            (rst_n),
    .ops_request      (ops_request),
    .ops_valid        (ops_valid),
    .throttle_q16     (throttle_q16),
    .ops_executed     (ops_executed),
    .intensity_cap_hit(intensity_cap_hit),
    .tile_active      (tile_active)
  );

  //--------------------------------------------------------------------------
  // Instantiate TBCU
  //--------------------------------------------------------------------------
  tbc_unit #(
    .N_TILES     (1),               // single-tile smoke test
    .OPS_WIDTH   (32),
    .POWER_WIDTH (24)
  ) u_tbc (
    .clk                (clk),
    .rst_n              (rst_n),
    .total_ops_executed (total_ops_executed),
    .sample_valid       (sample_valid),
    .throttle_q16       (throttle_q16),
    .estimated_power_fp (estimated_power_fp),
    .region_code        (region_code),
    .envelope_alarm     (envelope_alarm)
  );

  // Feed the single tile’s activity back to the TBCU
  assign total_ops_executed = ops_executed;
  assign sample_valid       = ops_valid;

  //--------------------------------------------------------------------------
  // Stimulus
  //--------------------------------------------------------------------------
  string region_name;
  always_comb begin
    case (region_code)
      2'd0: region_name = "BOUND";
      2'd1: region_name = "BOUNDARY";
      2'd2: region_name = "FREE";
      default: region_name = "???";
    endcase
  end

  initial begin
    rst_n       = 0;
    ops_request = 0;
    ops_valid   = 0;

    repeat (10) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);

    $display("=== TBU Tile + TBCU smoke test ===");
    $display("time  ops_req   ops_exec  throttle  region     alarm");

    // Rising load profile
    for (int load = 0; load <= 20; load++) begin
      ops_request = load * 32'd50_000_000;   // artificial ramp
      ops_valid   = 1;
      @(posedge clk);
      ops_valid   = 0;

      // let TBCU react for a few cycles
      repeat (4) @(posedge clk);

      $display("%0t  %8d  %8d  0x%04h   %-8s  %0d",
               $time, ops_request, ops_executed,
               throttle_q16, region_name, envelope_alarm);
    end

    $display("=== Test finished ===");
    $finish;
  end

endmodule : tb_tile_tbc
