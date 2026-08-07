//==============================================================================
// tb_regional_fabric.sv – Multi-tile testbench with regional TBU control
//
// Instantiates baseband_top (8 tiles, 4 regions), applies a rising load,
// and prints per-cycle throttle / region / alarm behaviour so we can see
// hierarchical containment in action.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module tb_regional_fabric;

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
  logic [31:0] global_ops_request;
  logic        global_ops_valid;
  logic        force_approx;
  logic [15:0] alu_a, alu_b;
  logic [2:0]  alu_opcode;
  logic [1:0]  global_region_code;
  logic        envelope_alarm;

  baseband_top #(
    .NUM_TILES (8),
    .N_REGIONS (4),
    .ALU_WIDTH (16)
  ) u_dut (
    .clk                (clk),
    .rst_n              (rst_n),
    .global_ops_request (global_ops_request),
    .global_ops_valid   (global_ops_valid),
    .force_approx       (force_approx),
    .alu_a              (alu_a),
    .alu_b              (alu_b),
    .alu_opcode         (alu_opcode),
    .global_region_code (global_region_code),
    .envelope_alarm     (envelope_alarm)
  );

  //--------------------------------------------------------------------------
  // Helpers
  //--------------------------------------------------------------------------
  string region_name;
  always_comb begin
    case (global_region_code)
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
    rst_n              = 0;
    global_ops_request = 0;
    global_ops_valid   = 0;
    force_approx       = 0;
    alu_a              = 16'h00A0;
    alu_b              = 16'h0010;
    alu_opcode         = 3'd0;          // ADD

    repeat (20) @(posedge clk);
    rst_n = 1;
    repeat (10) @(posedge clk);

    $display("=== Regional TBU Fabric Test ===");
    $display("time     ops_req    region     alarm  approx");

    // Phase 1 – light load (should stay open)
    for (int i = 0; i < 8; i++) begin
      global_ops_request = 32'd10_000_000 + i * 32'd2_000_000;
      global_ops_valid   = 1;
      force_approx       = 0;
      @(posedge clk);
      global_ops_valid   = 0;
      repeat (3) @(posedge clk);
      $display("%0t  %8d   %-8s   %0d     %0d",
               $time, global_ops_request, region_name,
               envelope_alarm, force_approx);
    end

    // Phase 2 – heavy load (should enter BOUNDARY / BOUND and throttle)
    $display("--- heavy load ---");
    for (int i = 0; i < 12; i++) begin
      global_ops_request = 32'd80_000_000 + i * 32'd15_000_000;
      global_ops_valid   = 1;
      force_approx       = (i > 6);     // also exercise approx path
      @(posedge clk);
      global_ops_valid   = 0;
      repeat (3) @(posedge clk);
      $display("%0t  %8d   %-8s   %0d     %0d",
               $time, global_ops_request, region_name,
               envelope_alarm, force_approx);
    end

    // Phase 3 – cool-down
    $display("--- cool-down ---");
    for (int i = 0; i < 6; i++) begin
      global_ops_request = 32'd5_000_000;
      global_ops_valid   = 1;
      force_approx       = 0;
      @(posedge clk);
      global_ops_valid   = 0;
      repeat (3) @(posedge clk);
      $display("%0t  %8d   %-8s   %0d     %0d",
               $time, global_ops_request, region_name,
               envelope_alarm, force_approx);
    end

    $display("=== Test finished ===");
    $finish;
  end

endmodule : tb_regional_fabric
