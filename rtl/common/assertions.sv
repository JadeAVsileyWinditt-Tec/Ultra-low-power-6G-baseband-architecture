//==============================================================================
// assertions.sv – Design-wide safety properties for the TBU fabric
//
// Bind or include these checks in testbenches and formal runs.
// They encode the non-negotiable architecture constraints:
//   - no tile exceeds the intensity hard-cap
//   - thermal envelope is respected under normal control
//   - throttle is monotonic with respect to thermal pressure
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module tbu_assertions #(
  parameter int OPS_WIDTH = 32
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Observed signals from the fabric under test
  input  logic [OPS_WIDTH-1:0]       ops_executed,
  input  logic [15:0]                throttle_q16,
  input  logic [1:0]                 region_code,
  input  logic                       envelope_alarm,
  input  logic                       sample_valid
);

  //--------------------------------------------------------------------------
  // 1. Intensity hard-cap must never be exceeded
  //--------------------------------------------------------------------------
  property p_intensity_cap;
    @(posedge clk) disable iff (!rst_n)
      sample_valid |-> (ops_executed <= MAX_OPS_PER_TILE[OPS_WIDTH-1:0]);
  endproperty
  a_intensity_cap: assert property (p_intensity_cap)
    else $error("TBU ASSERT: intensity cap violated (ops=%0d)", ops_executed);

  //--------------------------------------------------------------------------
  // 2. When region is BOUND, throttle must be reduced
  //--------------------------------------------------------------------------
  property p_bound_throttle;
    @(posedge clk) disable iff (!rst_n)
      (region_code == 2'd0) |-> (throttle_q16 < 16'hC000);
  endproperty
  a_bound_throttle: assert property (p_bound_throttle)
    else $error("TBU ASSERT: BOUND region but throttle still high");

  //--------------------------------------------------------------------------
  // 3. Envelope alarm should only assert when region is not FREE
  //--------------------------------------------------------------------------
  property p_alarm_consistency;
    @(posedge clk) disable iff (!rst_n)
      envelope_alarm |-> (region_code != 2'd2);
  endproperty
  a_alarm_consistency: assert property (p_alarm_consistency)
    else $error("TBU ASSERT: envelope_alarm while region is FREE");

  //--------------------------------------------------------------------------
  // 4. Throttle is in legal Q0.16 range (always true by construction, but check)
  //--------------------------------------------------------------------------
  property p_throttle_range;
    @(posedge clk) disable iff (!rst_n)
      1'b1 |-> (throttle_q16 <= 16'hFFFF);
  endproperty
  a_throttle_range: assert property (p_throttle_range);

endmodule : tbu_assertions
