//==============================================================================
// soft_demap.sv – Soft demapper (QPSK LLR stub)
//
// For QPSK symbol X = x_re + j x_im:
//   LLR_b0 ≈ x_re
//   LLR_b1 ≈ x_im
//
// Under approx_en, LSBs are truncated to cut switching.  Real designs use
// scaled channel-reliability weighting; this stub keeps the control loop honest.
//==============================================================================

`timescale 1ns / 1ps

module soft_demap #(
  parameter int WIDTH = 16,
  parameter int N_SC  = 8,
  parameter int TRUNC = 2
) (
  input  logic                       clk,
  input  logic                       rst_n,

  input  logic                       approx_en,
  input  logic                       in_valid,

  input  logic [WIDTH-1:0]           x_re [N_SC],
  input  logic [WIDTH-1:0]           x_im [N_SC],

  output logic                       out_valid,
  // 2 LLRs per subcarrier (QPSK)
  output logic [WIDTH-1:0]           llr0 [N_SC],
  output logic [WIDTH-1:0]           llr1 [N_SC]
);

  genvar i;
  generate
    for (i = 0; i < N_SC; i++) begin : g_demap
      logic [WIDTH-1:0] re_q, im_q;
      assign re_q = approx_en ? {x_re[i][WIDTH-1:TRUNC], {TRUNC{1'b0}}} : x_re[i];
      assign im_q = approx_en ? {x_im[i][WIDTH-1:TRUNC], {TRUNC{1'b0}}} : x_im[i];

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          llr0[i] <= '0;
          llr1[i] <= '0;
        end else if (in_valid) begin
          llr0[i] <= re_q;   // bit 0 soft value
          llr1[i] <= im_q;   // bit 1 soft value
        end
      end
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'b0;
    else        out_valid <= in_valid;
  end

endmodule : soft_demap
