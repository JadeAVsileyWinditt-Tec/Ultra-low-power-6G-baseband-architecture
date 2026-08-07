//==============================================================================
// approx_alu.sv – Approximate arithmetic unit for intensity reduction
//
// Part of the 12–15× computational intensity cut claimed by the architecture.
// Uses truncated / approximate adders and multipliers so that many operations
// cost far fewer transitions than exact arithmetic, while still meeting
// baseband error tolerances.
//
// This is a behavioural first cut – bit-width and approximation strength
// will be tuned later against real 6G kernels (FFT, equalisation, MIMO detect).
//==============================================================================

`timescale 1ns / 1ps

module approx_alu #(
  parameter int WIDTH        = 16,
  parameter int TRUNC_BITS   = 2      // LSBs ignored / forced to zero for approx
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Control
  input  logic [2:0]                 opcode,   // 0=ADD, 1=SUB, 2=MUL, 3=AND, 4=OR, …
  input  logic                       approx_en, // 1 = use approximate path

  // Operands
  input  logic [WIDTH-1:0]           op_a,
  input  logic [WIDTH-1:0]           op_b,

  // Result
  output logic [WIDTH-1:0]           result,
  output logic                       result_valid
);

  //--------------------------------------------------------------------------
  // Exact paths
  //--------------------------------------------------------------------------
  logic [WIDTH-1:0] exact_add, exact_sub, exact_mul, exact_and, exact_or;

  assign exact_add = op_a + op_b;
  assign exact_sub = op_a - op_b;
  assign exact_mul = op_a * op_b;          // will be replaced by approx multiplier
  assign exact_and = op_a & op_b;
  assign exact_or  = op_a | op_b;

  //--------------------------------------------------------------------------
  // Approximate paths – simple truncation / broken-array style
  //--------------------------------------------------------------------------
  logic [WIDTH-1:0] a_trunc, b_trunc;
  logic [WIDTH-1:0] approx_add, approx_mul;

  // Force the lowest TRUNC_BITS to zero (reduces switching activity)
  assign a_trunc = {op_a[WIDTH-1:TRUNC_BITS], {TRUNC_BITS{1'b0}}};
  assign b_trunc = {op_b[WIDTH-1:TRUNC_BITS], {TRUNC_BITS{1'b0}}};

  assign approx_add = a_trunc + b_trunc;
  // Very rough approximate multiply: shift-and-add on truncated operands
  assign approx_mul = a_trunc * b_trunc;   // placeholder – real design uses
                                           // broken-array or logarithmic multiplier

  //--------------------------------------------------------------------------
  // Opcode select + approx mux
  //--------------------------------------------------------------------------
  logic [WIDTH-1:0] chosen;

  always_comb begin
    case (opcode)
      3'd0: chosen = approx_en ? approx_add : exact_add;
      3'd1: chosen = exact_sub;                    // keep sub exact for now
      3'd2: chosen = approx_en ? approx_mul : exact_mul;
      3'd3: chosen = exact_and;
      3'd4: chosen = exact_or;
      default: chosen = '0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result       <= '0;
      result_valid <= 1'b0;
    end else begin
      result       <= chosen;
      result_valid <= 1'b1;
    end
  end

endmodule : approx_alu
