`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    wire opposite_clk = ~clk;
    reg d = 0;
    wire q, opposite_q;
    reg expected;
    reg armed = 0;
    integer edges = 0;
    integer i;

    TopModule dut(.clk(clk), .d(d), .q(q));
    TopModule opposite_dut(.clk(opposite_clk), .d(d), .q(opposite_q));

    // A dual-edge flip-flop samples the input at either clock transition.
    // This model does not depend on the DUT's internal storage or clock mux.
    always @(posedge clk or negedge clk) begin
        if (armed) begin
            expected = d;
            edges = edges + 1;
        end
    end

    task check_outputs;
        begin
            if (q !== expected)
                $fatal(1, "Main output mismatch at %0t: got %b expected %b", $time, q, expected);
            if (opposite_q !== expected)
                $fatal(1, "Opposite clock output mismatch at %0t: got %b expected %b", $time, opposite_q, expected);
        end
    endtask

    task sample_and_hold(input reg value);
        begin
            d = value;
            #2;
            if (edges > 0) check_outputs();
            clk = ~clk;
            #1;
            check_outputs();
            // Input changes during this clock phase must not propagate.
            d = ~value;
            #1;
            check_outputs();
            d = value;
            #1;
            check_outputs();
        end
    endtask

    initial begin
        // The problem has no reset or specified power-up value.
        // Begin checks only after an intentional edge.
        #1;
        armed = 1;
        sample_and_hold(0);
        sample_and_hold(1);
        sample_and_hold(1);
        sample_and_hold(0);
        sample_and_hold(0);
        sample_and_hold(1);
        for (i = 0; i < 128; i = i + 1)
            sample_and_hold(((i * 13 + i / 3) % 7) < 3);
        if (edges != 134) $fatal(1, "Incorrect stimulus edge count: %0d", edges);
        $display("PASS: dual-edge capture and between-edge hold, both first-edge polarities, %0d edges", edges);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
