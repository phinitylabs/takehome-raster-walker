`timescale 1ns/1ps
//
// tb_raster_walker -- self-checking testbench for raster_walker.
//
// Complete this testbench according to prompt.txt and docs/spec.md.
// Verdict contract:
//   - print a line containing TB_PASS and call $finish if and only if
//     every check passed;
//   - print a line containing TB_FAIL and terminate with $fatal(1) on the
//     first failed check.
// Judge the DUT against docs/spec.md alone; rely on nothing else.
//
module tb_raster_walker;

    localparam int W = 8;

    logic         clk = 1'b0;
    logic         rst = 1'b1;
    logic         start = 1'b0;
    logic [W-1:0] dx = '0;
    logic [W-1:0] dy = '0;
    logic         step_ready = 1'b0;
    wire          busy, done, step_valid, step_dir;

    raster_walker #(.W(W)) dut (
        .clk        (clk),
        .rst        (rst),
        .start      (start),
        .dx         (dx),
        .dy         (dy),
        .busy       (busy),
        .done       (done),
        .step_valid (step_valid),
        .step_dir   (step_dir),
        .step_ready (step_ready)
    );

    always #5 clk = ~clk;

    initial begin
        // TODO: implement the testbench.
        $display("TB_FAIL: testbench not implemented");
        $fatal(1);
    end

endmodule
