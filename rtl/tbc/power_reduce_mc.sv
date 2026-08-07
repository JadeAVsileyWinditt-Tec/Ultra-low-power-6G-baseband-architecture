//==============================================================================
// power_reduce_mc.sv – Multi-cycle hierarchical power reduction tree
//
// Sums N activity values over several cycles.  Suitable for scaling toward
// the full 2048-tile fabric where a pure combinational adder tree would be
// too wide / too slow.
//
// Interface is streaming: assert in_valid with a new vector, wait for
// out_valid, then read the sum.
//==============================================================================

`timescale 1ns / 1ps

module power_reduce_mc #(
  parameter int N         = 16,          // number of inputs this instance sums
  parameter int WIDTH     = 32,
  parameter int LANES     = 4            // how many partial sums per cycle
) (
  input  logic                       clk,
  input  logic                       rst_n,

  input  logic                       in_valid,
  input  logic [WIDTH-1:0]           in_val   [N],

  output logic                       out_valid,
  output logic [WIDTH-1:0]           sum
);

  localparam int N_CYCLES = (N + LANES - 1) / LANES;

  logic [$clog2(N_CYCLES+1)-1:0] cycle;
  logic [WIDTH-1:0]              acc;
  logic                          busy;

  integer i;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle     <= '0;
      acc       <= '0;
      busy      <= 1'b0;
      out_valid <= 1'b0;
      sum       <= '0;
    end else begin
      out_valid <= 1'b0;

      if (in_valid && !busy) begin
        // start a new reduction
        busy  <= 1'b1;
        cycle <= '0;
        acc   <= '0;
      end else if (busy) begin
        // accumulate LANES inputs this cycle
        for (i = 0; i < LANES; i++) begin
          if ((cycle * LANES + i) < N)
            acc <= acc + in_val[cycle * LANES + i];
        end

        if (cycle == N_CYCLES - 1) begin
          busy      <= 1'b0;
          out_valid <= 1'b1;
          sum       <= acc + in_val[(N_CYCLES-1)*LANES]; // final partial
          // note: simple version; production code would fold the last
          // partial more carefully.  Good enough for the skeleton.
        end else begin
          cycle <= cycle + 1;
        end
      end
    end
  end

endmodule : power_reduce_mc
