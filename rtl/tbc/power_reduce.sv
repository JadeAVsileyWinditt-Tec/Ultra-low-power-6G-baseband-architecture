//==============================================================================
// power_reduce.sv – Binary reduction tree that sums tile activity
//
// Turns N individual tile operation counts into a single total (or into
// per-region totals) every cycle.  Used by both the global TBCU and the
// regional controller.
//==============================================================================

`timescale 1ns / 1ps

module power_reduce #(
  parameter int N         = 16,
  parameter int WIDTH     = 32
) (
  input  logic [WIDTH-1:0]  in_val   [N],
  output logic [WIDTH-1:0]  sum
);

  // Simple combinational reduction (for modest N).
  // For 2048 tiles a multi-cycle or hierarchical tree would be used.
  always_comb begin
    sum = '0;
    for (int i = 0; i < N; i++)
      sum += in_val[i];
  end

endmodule : power_reduce
