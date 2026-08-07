//==============================================================================
// constellation_map.sv – QPSK constellation mapper
//
// Maps bit pairs → complex symbols.
//   00 → (+1, +1),  01 → (-1, +1),  11 → (-1, -1),  10 → (+1, -1)
// Scaled into fixed-point WIDTH.
//==============================================================================

`timescale 1ns / 1ps

module constellation_map #(
  parameter int WIDTH = 16,
  parameter int N_SC  = 8,
  parameter int AMP   = 16'h0100          // constellation amplitude
) (
  input  logic                       clk,
  input  logic                       rst_n,
  input  logic                       approx_en,
  input  logic                       in_valid,
  input  logic [1:0]                 bits [N_SC],   // 2 bits per subcarrier

  output logic                       out_valid,
  output logic [WIDTH-1:0]           s_re [N_SC],
  output logic [WIDTH-1:0]           s_im [N_SC]
);

  genvar i;
  generate
    for (i = 0; i < N_SC; i++) begin : g_map
      logic [WIDTH-1:0] re_v, im_v;
      always_comb begin
        case (bits[i])
          2'b00: begin re_v = AMP;              im_v = AMP;              end
          2'b01: begin re_v = -AMP;             im_v = AMP;              end
          2'b11: begin re_v = -AMP;             im_v = -AMP;             end
          2'b10: begin re_v = AMP;              im_v = -AMP;             end
          default: begin re_v = '0; im_v = '0; end
        endcase
        // approx: quantise amplitude slightly
        if (approx_en) begin
          re_v = {re_v[WIDTH-1:2], 2'b00};
          im_v = {im_v[WIDTH-1:2], 2'b00};
        end
      end

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          s_re[i] <= '0; s_im[i] <= '0;
        end else if (in_valid) begin
          s_re[i] <= re_v; s_im[i] <= im_v;
        end
      end
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'b0;
    else        out_valid <= in_valid;
  end

endmodule : constellation_map
