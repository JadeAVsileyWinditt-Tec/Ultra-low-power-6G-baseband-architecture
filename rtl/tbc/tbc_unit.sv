//==============================================================================
// tbc_unit.sv – Thermal Boundary Control Unit (TBCU)
//
// Hardware realisation of the Topological Boundary Unit (TBU) for the
// 2048-tile baseband fabric.
//
// The TBCU continuously estimates total fabric power, evaluates the smooth
// boundary measure B_δ(P), and generates a global (or hierarchical) throttle
// factor that is broadcast to every tile’s intensity limiter.
//
// This implements the containment term of the universal TBU field equation
// in the silicon domain where S = power and S_crit = 4 W.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module tbc_unit #(
  parameter int N_TILES     = tbu_params_pkg::N_TILES,
  parameter int OPS_WIDTH   = 32,
  parameter int POWER_WIDTH = 24          // fixed-point power representation
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Aggregated activity from tiles (or from a power sensor network)
  // In a full design this would be a reduction tree or sampled power rails.
  input  logic [OPS_WIDTH-1:0]       total_ops_executed,   // sum across tiles
  input  logic                       sample_valid,

  // Output throttle factor (Q0.16) broadcast to all tiles
  output logic [15:0]                throttle_q16,

  // Diagnostics
  output logic [POWER_WIDTH-1:0]     estimated_power_fp,   // fixed-point watts
  output logic [1:0]                 region_code,          // 0=BOUND, 1=BOUNDARY, 2=FREE
  output logic                       envelope_alarm
);

  //--------------------------------------------------------------------------
  // Fixed-point helpers (very simple for behavioural modelling)
  // Power (W) is represented with 8 integer bits + 16 fractional bits.
  //--------------------------------------------------------------------------
  localparam int FP_FRAC = 16;
  localparam logic [POWER_WIDTH-1:0] ENVELOPE_FP =
      THERMAL_ENVELOPE_W * (1 << FP_FRAC);          // 4.0 in Q8.16
  localparam logic [POWER_WIDTH-1:0] DELTA_FP =
      TBU_DELTA_W * (1 << FP_FRAC);

  // Approximate energy: 0.10 pJ/op = 0.10e-12 J/op
  // For a control epoch we convert ops → energy → power (W).
  // This is a placeholder scaling; a real design would use calibrated sensors.
  function automatic logic [POWER_WIDTH-1:0] ops_to_power_fp(
    input logic [OPS_WIDTH-1:0] ops
  );
    // Extremely simplified: treat a full-intensity fabric as ~4–6 W
    // and scale linearly.  Replace with measured or analytical model later.
    logic [63:0] scaled;
    scaled = ops * 64'd3;                 // toy scale factor
    return scaled[POWER_WIDTH+15:16];     // crude Q-format fit
  endfunction

  //--------------------------------------------------------------------------
  // Boundary measure B_δ approximation (thermally inverted)
  //
  // True B = 1 / (1 + exp(−(P − S_crit)/δ))
  // For thermal protection we invert so high power → low throttle.
  //--------------------------------------------------------------------------
  function automatic logic [15:0] approx_boundary_measure(
    input logic [POWER_WIDTH-1:0] P_fp
  );
    logic signed [POWER_WIDTH:0] diff;
    logic [15:0] B;
    diff = $signed({1'b0, P_fp}) - $signed({1'b0, ENVELOPE_FP});

    // Thermal inversion: throttle high when power is low,
    // throttle low when power is high (containment).
    if (diff < -$signed(DELTA_FP))
      B = 16'hFFFF;                       // deep under envelope → full open
    else if (diff > $signed(DELTA_FP))
      B = 16'h0000;                       // deep over envelope → full throttle-off
    else begin
      // Map [−δ … +δ] → [1 … 0] in Q0.16
      logic [POWER_WIDTH:0] num;
      num = $signed(DELTA_FP) - diff;     // inverted
      B = (num << 16) / (DELTA_FP << 1);
    end
    return B;
  endfunction

  //--------------------------------------------------------------------------
  // Registers
  //--------------------------------------------------------------------------
  logic [POWER_WIDTH-1:0] power_r;
  logic [15:0]            throttle_r;
  logic [1:0]             region_r;
  logic                   alarm_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      power_r     <= '0;
      throttle_r  <= 16'hFFFF;            // start fully open
      region_r    <= 2'd2;                // FREE
      alarm_r     <= 1'b0;
    end else if (sample_valid) begin
      power_r    <= ops_to_power_fp(total_ops_executed);
      throttle_r <= approx_boundary_measure(power_r);

      // Region classification
      if (power_r < ENVELOPE_FP - DELTA_FP)
        region_r <= 2'd0;                 // BOUND
      else if (power_r > ENVELOPE_FP + DELTA_FP)
        region_r <= 2'd2;                 // FREE
      else
        region_r <= 2'd1;                 // BOUNDARY

      alarm_r <= (power_r > ENVELOPE_FP);
    end
  end

  assign throttle_q16       = throttle_r;
  assign estimated_power_fp = power_r;
  assign region_code        = region_r;
  assign envelope_alarm     = alarm_r;

