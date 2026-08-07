//==============================================================================
// bind_assertions.sv – Example bind of TBU safety properties
//
// In a real flow this would be bound to fabric instances.  Here we show the
// pattern so it can be attached to any tile or top-level testbench.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module bind_assertions_tb;

  logic clk, rst_n;
  initial begin clk = 0; forever #5 clk = ~clk; end

  logic [31:0] ops_executed;
  logic [15:0] throttle_q16;
  logic [1:0]  region_code;
  logic        envelope_alarm;
  logic        sample_valid;

  // Instantiate the assertion module
  tbu_assertions #(
    .OPS_WIDTH(32)
  ) u_assert (
    .clk            (clk),
    .rst_n          (rst_n),
    .ops_executed   (ops_executed),
    .throttle_q16   (throttle_q16),
    .region_code    (region_code),
    .envelope_alarm (envelope_alarm),
    .sample_valid   (sample_valid)
  );

  // Simple stimulus that stays legal
  initial begin
    rst_n = 0;
    ops_executed = 0; throttle_q16 = 16'hFFFF;
    region_code = 2'd2; envelope_alarm = 0; sample_valid = 0;
    repeat (10) @(posedge clk);
    rst_n = 1;

    // Legal FREE region
    sample_valid = 1; region_code = 2'd2; throttle_q16 = 16'hFFFF;
    ops_executed = 32'd1000;
    @(posedge clk);

    // Legal BOUNDARY
    region_code = 2'd1; throttle_q16 = 16'h9000;
    @(posedge clk);

    // Legal BOUND with reduced throttle
    region_code = 2'd0; throttle_q16 = 16'h4000;
    envelope_alarm = 1;
    @(posedge clk);

    sample_valid = 0;
    $display("Assertion bind smoke test finished (no failures expected)");
    $finish;
  end

endmodule : bind_assertions_tb
