//==============================================================================
// tbc_unit.sv – Thermal Boundary Control Unit (TBCU)
//
// Hardware realisation of the Topological Boundary Unit (TBU).
// Now uses a compact piecewise-linear approximation of the logistic
// boundary measure B_δ, inverted for thermal containment.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module tbc_unit #(
  parameter int N_TILES     = tbu_params_pkg::N_TILES,
  parameter int OPS_WIDTH   = 32,
  parameter int POWER_WIDTH = 24
) (
  input  logic                       clk,
  input  logic                       rst_n,

  input  logic [OPS_WIDTH-1:0]       total_ops_executed,
  input  logic                       sample_valid,

  output logic [15:0]                throttle_q16,

  output logic [POWER_WIDTH-1:0]     estimated_power_fp,
  output logic [1:0]                 region_code,
  output logic                       envelope_alarm
);

  //--------------------------------------------------------------------------
  // Fixed-point helpers (Q8.16 style)
  //--------------------------------------------------------------------------
  localparam int FP_FRAC = 16;
  localparam logic [POWER_WIDTH-1:0] ENVELOPE_FP =
      THERMAL_ENVELOPE_W * (1 << FP_FRAC);          // 4.0
  localparam logic [POWER_WIDTH-1:0] DELTA_FP =
      TBU_DELTA_W * (1 << FP_FRAC);                 // 0.20

  //--------------------------------------------------------------------------
  // Ops → power (placeholder scaling – replace with calibrated model later)
  //--------------------------------------------------------------------------
  function automatic logic [POWER_WIDTH-1:0] ops_to_power_fp(
    input logic [OPS_WIDTH-1:0] ops
  );
    logic [63:0] scaled;
    scaled = ops * 64'd3;
    return scaled[POWER_WIDTH+15:16];
  endfunction

  //--------------------------------------------------------------------------
  // Piecewise-linear approximation of the logistic
  //   B = 1 / (1 + exp(-(P - S_crit)/δ))
  // then invert for thermal throttle: throttle = 1 - B
  //
  // We evaluate at a few key points relative to the envelope and
  // linearly interpolate.  This is cheap in hardware and tracks the
  // true sigmoid far better than a single linear ramp.
  //--------------------------------------------------------------------------
  function automatic logic [15:0] logistic_throttle(
    input logic [POWER_WIDTH-1:0] P_fp
  );
    logic signed [POWER_WIDTH:0] diff;
    logic [15:0] thr;

    diff = $signed({1'b0, P_fp}) - $signed({1'b0, ENVELOPE_FP});

    // Key points (approx values of 1-B at these offsets from S_crit)
    //   diff <= -2δ  → throttle ≈ 1.00
    //   diff  = -δ   → throttle ≈ 0.88
    //   diff  =  0   → throttle ≈ 0.50
    //   diff  = +δ   → throttle ≈ 0.12
    //   diff >= +2δ  → throttle ≈ 0.00

    if (diff <= -$signed(DELTA_FP << 1)) begin
      thr = 16'hFFFF;                                 // fully open
    end else if (diff <= -$signed(DELTA_FP)) begin
      // interpolate 1.00 → 0.88
      thr = 16'hFFFF - ((diff + (DELTA_FP << 1)) * 16'h1F00) / DELTA_FP;
    end else if (diff <= 0) begin
      // interpolate 0.88 → 0.50
      thr = 16'hE0FF - ((diff + DELTA_FP) * 16'h60FF) / DELTA_FP;
    end else if (diff <= $signed(DELTA_FP)) begin
      // interpolate 0.50 → 0.12
      thr = 16'h8000 - (diff * 16'h61FF) / DELTA_FP;
    end else if (diff <= $signed(DELTA_FP << 1)) begin
      // interpolate 0.12 → 0.00
      thr = 16'h1E00 - ((diff - DELTA_FP) * 16'h1E00) / DELTA_FP;
    end else begin
      thr = 16'h0000;                                 // fully closed
    end

    return thr;
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
      throttle_r  <= 16'hFFFF;
      region_r    <= 2'd2;
      alarm_r     <= 1'b0;
    end else if (sample_valid) begin
      power_r    <= ops_to_power_fp(total_ops_executed);
      throttle_r <= logistic_throttle(power_r);

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

endmodule : tbc_unit
