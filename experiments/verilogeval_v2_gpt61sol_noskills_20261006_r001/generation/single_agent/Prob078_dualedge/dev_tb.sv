`timescale 1ns/1ps
module dev_tb;
    reg clk;
    reg d;
    wire q;
    reg expected;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task check_output;
        begin
            if (q !== expected)
                $fatal(1, "At %0t clk=%b d=%b expected q=%b observed q=%b",
                       $time, clk, d, expected, q);
            checks = checks + 1;
        end
    endtask

    // Independent behavioral oracle: retain the data sampled at any clock edge.
    always @(posedge clk or negedge clk) begin
        expected = d;
        #0.001;
        check_output;
    end

    task sample_edge(input reg value);
        begin
            d = value;
            #2;
            check_output;
            clk = ~clk;
            #1;
            check_output;
            // Changes to data within each clock phase must not change q.
            d = ~value;
            #1;
            check_output;
            d = value;
            #1;
            check_output;
        end
    endtask

    initial begin
        d = 0;
        clk = 0;
        #1;
        // Establish the first rising-edge sample before exercising hold checks.
        d = 1;
        #1;
        clk = 1;
        #1;
        check_output;
        sample_edge(0);
        sample_edge(1);
        sample_edge(1);
        sample_edge(0);
        sample_edge(0);
        sample_edge(1);
        // Both polarities, repeated bits, alternating bits, and varied runs.
        for (i = 0; i < 128; i = i + 1)
            sample_edge(((i * 13) ^ (i >> 2) ^ (i >> 4)) & 1);
        // Unknown data must also propagate when sampled and remain held.
        sample_edge(1'bx);
        sample_edge(0);
        sample_edge(1'bx);
        sample_edge(1);
        $display("PASS: dual-edge capture and between-edge hold (%0d checks)", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
