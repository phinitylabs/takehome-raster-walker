// raster_walker -- variant: abort_emits_done
`timescale 1ns/1ps
//
// raster_walker -- GOLDEN reference implementation (validation and grading
// only; never shipped on any agent-visible or public branch).
//
// Closest-lattice-point line walk from (0,0) to (dx,dy), dy <= dx, emitted
// as dx unit steps (E / NE) over a stalling step_valid/step_ready handshake.
// Error-accumulator derivation of y_k = floor((2*k*dy + dx) / (2*dx)):
//   acc := dx; per step: acc += 2*dy; NE iff acc >= 2*dx, then acc -= 2*dx.
// Equality (the equidistant case) steps NE, i.e. ties resolve to the upper
// lattice point as the spec requires.
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

    logic             busy_q;
    logic             valid_q;
    logic             dir_q;
    logic             done_q;
    logic [W-1:0]     cnt_q;    // remaining steps, including the offered one
    logic [W+1:0]     acc_q;    // accumulator AFTER computing the offered step
    logic [W+1:0]     dx2_q;    // 2*dx of the traversal in flight
    logic [W+1:0]     dy2_q;    // 2*dy

    wire legal  = (dy <= dx);
    wire accept = start && !busy_q && legal;   // reset priority handled below
    wire take   = valid_q && step_ready;
    wire last   = (cnt_q == 1);

    // One step of the walk: from post-step accumulator a, the next step is
    // NE iff a + 2*dy >= 2*dx (equality steps NE), consuming 2*dx if taken.
    function automatic logic step_ne(input logic [W+1:0] a,
                                     input logic [W+1:0] ddy2,
                                     input logic [W+1:0] ddx2);
        step_ne = (a + ddy2 >= ddx2);
    endfunction

    function automatic logic [W+1:0] step_acc(input logic [W+1:0] a,
                                              input logic [W+1:0] ddy2,
                                              input logic [W+1:0] ddx2);
        step_acc = step_ne(a, ddy2, ddx2) ? (a + ddy2 - ddx2) : (a + ddy2);
    endfunction

    wire [W+1:0] dx2_in   = {1'b0, dx, 1'b0};
    wire [W+1:0] dy2_in   = {1'b0, dy, 1'b0};
    wire [W+1:0] acc_seed = dx;

    wire         ne_first  = step_ne (acc_seed, dy2_in, dx2_in);
    wire [W+1:0] acc_first = step_acc(acc_seed, dy2_in, dx2_in);
    wire         ne_next   = step_ne (acc_q, dy2_q, dx2_q);
    wire [W+1:0] acc_next  = step_acc(acc_q, dy2_q, dx2_q);

    always_ff @(posedge clk) begin
        if (rst) begin
            busy_q  <= 1'b0;
            valid_q <= 1'b0;
            dir_q   <= 1'b0;
            done_q  <= busy_q;
            cnt_q   <= '0;
            acc_q   <= '0;
            dx2_q   <= '0;
            dy2_q   <= '0;
        end else begin
            done_q <= 1'b0;   // done is a one-cycle pulse
            if (accept) begin
                if (dx == '0) begin
                    // Zero-length traversal: no steps, done in the next cycle.
                    done_q <= 1'b1;
                end else begin
                    busy_q  <= 1'b1;
                    valid_q <= 1'b1;
                    dir_q   <= ne_first;
                    acc_q   <= acc_first;
                    cnt_q   <= dx;
                    dx2_q   <= dx2_in;
                    dy2_q   <= dy2_in;
                end
            end else if (take) begin
                if (last) begin
                    busy_q  <= 1'b0;
                    valid_q <= 1'b0;   // dir_q holds its last value
                    done_q  <= 1'b1;
                    cnt_q   <= '0;
                end else begin
                    dir_q <= ne_next;
                    acc_q <= acc_next;
                    cnt_q <= cnt_q - 1'b1;
                end
            end
        end
    end

    assign busy       = busy_q;
    assign done       = done_q;
    assign step_valid = valid_q;
    assign step_dir   = dir_q;

endmodule
