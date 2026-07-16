`timescale 1ns/1ps
//
// raster_walker -- interface placeholder. This file is NOT an implementation
// and is not part of the deliverable. You may implement the module here
// locally to exercise your testbench (see prompt.txt).
//
module raster_walker #(
    parameter int W = 8
) (
    input  logic         clk,
    input  logic         rst,        // synchronous, active-high

    input  logic         start,
    input  logic [W-1:0] dx,
    input  logic [W-1:0] dy,

    output logic         busy,
    output logic         done,

    output logic         step_valid,
    output logic         step_dir,   // 0 = E, 1 = NE
    input  logic         step_ready
);

    // Stub: constant zeros so the testbench compiles and runs out of the box.
    assign busy       = 1'b0;
    assign done       = 1'b0;
    assign step_valid = 1'b0;
    assign step_dir   = 1'b0;

endmodule
