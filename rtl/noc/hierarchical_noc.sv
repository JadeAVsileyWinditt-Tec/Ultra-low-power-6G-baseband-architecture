//==============================================================================
// hierarchical_noc.sv – Skeleton of the 64-bit hierarchical Network-on-Chip
//
// Supports the ~10¹⁸ combinatorial path claim from the architecture spec.
// This is a behavioural skeleton only – routing tables, virtual channels
// and flow-control will be filled in later.
//==============================================================================

`timescale 1ns / 1ps

import tbu_params_pkg::*;

module hierarchical_noc #(
  parameter int N_TILES      = tbu_params_pkg::N_TILES,
  parameter int ADDR_WIDTH   = tbu_params_pkg::NOC_ADDR_WIDTH,  // 64
  parameter int DATA_WIDTH   = tbu_params_pkg::NOC_DATA_WIDTH,  // 256
  parameter int TILE_X       = tbu_params_pkg::TILES_X,         // 64
  parameter int TILE_Y       = tbu_params_pkg::TILES_Y          // 32
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // Per-tile injection ports (simplified – one request port per tile)
  input  logic [N_TILES-1:0]         tile_req_valid,
  input  logic [ADDR_WIDTH-1:0]      tile_req_addr  [N_TILES],
  input  logic [DATA_WIDTH-1:0]      tile_req_data  [N_TILES],
  output logic [N_TILES-1:0]         tile_req_ready,

  // Per-tile delivery ports
  output logic [N_TILES-1:0]         tile_rsp_valid,
  output logic [DATA_WIDTH-1:0]      tile_rsp_data  [N_TILES],
  input  logic [N_TILES-1:0]         tile_rsp_ready
);

  //--------------------------------------------------------------------------
  // Hierarchy levels (example)
  //   Level 0 : local mesh (4-neighbour)
  //   Level 1 : quadrant routers
  //   Level 2 : global crossbar / torus
  //--------------------------------------------------------------------------
  localparam int N_QUADRANTS = 4;

  // Placeholder: for now just a pass-through identity mapping
  // so the rest of the fabric can compile and simulate.
  genvar t;
  generate
    for (t = 0; t < N_TILES; t++) begin : g_passthrough
      assign tile_req_ready[t] = tile_rsp_ready[t];
      assign tile_rsp_valid[t] = tile_req_valid[t];
      assign tile_rsp_data[t]  = tile_req_data[t];
    end
  endgenerate

  // TODO:
  //  - Coordinate → hierarchical address decode
  //  - Dimension-order or adaptive routing
  //  - Virtual-channel allocation
  //  - Credit-based flow control
  //  - Link power gating coordinated with TBCU throttle

endmodule : hierarchical_noc
