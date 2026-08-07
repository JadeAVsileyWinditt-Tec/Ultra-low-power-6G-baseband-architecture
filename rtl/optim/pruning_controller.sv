//==============================================================================
// pruning_controller.sv – Algorithmic intensity reduction
//
// Works together with the TBCU:
//   - TBCU handles thermal containment (power)
//   - This block handles computational intensity (ops)
//
// When the fabric is under thermal pressure, more aggressive pruning is
// enabled so that fewer exact operations are issued.
//==============================================================================

`timescale 1ns / 1ps

module pruning_controller (
  input  logic                       clk,
  input  logic                       rst_n,

  // From TBCU
  input  logic [15:0]                throttle_q16,   // Q0.16
  input  logic [1:0]                 region_code,    // 0=BOUND, 1=BOUNDARY, 2=FREE

  // Pruning outputs
  output logic                       approx_en,      // force approximate ALU
  output logic [1:0]                 prune_level,    // 0=none, 1=light, 2=aggressive
  output logic                       skip_noncritical // drop non-critical kernels
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      approx_en         <= 1'b0;
      prune_level       <= 2'd0;
      skip_noncritical  <= 1'b0;
    end else begin
      // Default – full quality
      approx_en        <= 1'b0;
      prune_level      <= 2'd0;
      skip_noncritical <= 1'b0;

      // Under thermal pressure → increase algorithmic intensity reduction
      if (region_code == 2'd1) begin          // BOUNDARY
        approx_en   <= 1'b1;
        prune_level <= 2'd1;                  // light pruning
      end else if (region_code == 2'd0) begin // BOUND
        approx_en        <= 1'b1;
        prune_level      <= 2'd2;             // aggressive
        skip_noncritical <= 1'b1;
      end else if (throttle_q16 < 16'hC000) begin
        // Even in FREE, if throttle is already reduced, start approximating
        approx_en   <= 1'b1;
        prune_level <= 2'd1;
      end
    end
  end

endmodule : pruning_controller
