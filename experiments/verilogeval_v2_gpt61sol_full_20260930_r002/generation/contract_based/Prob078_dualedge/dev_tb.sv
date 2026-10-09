`timescale 1ns/1ps
module dev_tb;
    logic clk;
    logic d;
    wire q;
    logic expected;
    integer checks = 0;
    integer rising_edges = 0;
    integer falling_edges = 0;
    integer i;
    logic [15:0] sequence_r = 16'hb6d3;

    TopModule dut (.clk(clk), .d(d), .q(q));

    task automatic check_output;
        begin
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: clk=%b d=%b q=%b expected=%b", $time, clk, d, q, expected);
            checks = checks + 1;
        end
    endtask

    // Behavioral oracle: the most recent clock edge samples the current d.
    task automatic clock_edge;
        begin
            expected = d;
            clk = ~clk;
            if (clk) rising_edges = rising_edges + 1;
            else falling_edges = falling_edges + 1;
            #1;
            check_output();
        end
    endtask

    task automatic change_data_and_check_hold(input logic value);
        begin
            d = value;
            #1;
            check_output();
        end
    endtask

    initial begin
        clk = 1'b0;
        d = 1'b0;
        expected = 1'bx;
        // No assertion about the unspecified power-up value.
        #3;
        clock_edge();
        change_data_and_check_hold(1'b1);
        #2;
        clock_edge();
        change_data_and_check_hold(1'b0);
        #3;
        clock_edge();
        #2;
        clock_edge(); // Repeated zero on the opposite edge.
        change_data_and_check_hold(1'b1);
        #2;
        clock_edge();
        #4;
        clock_edge(); // Repeated one on the opposite edge.

        for (i = 0; i < 256; i = i + 1) begin
            sequence_r = {sequence_r[14:0], sequence_r[15] ^ sequence_r[13] ^ sequence_r[12] ^ sequence_r[10]};
            change_data_and_check_hold(sequence_r[0]);
            #(1 + (i % 5));
            clock_edge();
            change_data_and_check_hold(~sequence_r[0]);
            change_data_and_check_hold(sequence_r[0]);
        end

        // Sample an unknown on each polarity, then restore known state.
        change_data_and_check_hold(1'bx);
        #2;
        clock_edge();
        change_data_and_check_hold(1'b1);
        #2;
        clock_edge();
        change_data_and_check_hold(1'bx);
        #2;
        clock_edge();
        change_data_and_check_hold(1'b0);
        #2;
        clock_edge();
        #3;
        check_output();
        if (rising_edges == 0 || falling_edges == 0)
            $fatal(1, "Missing edge coverage");
        $display("PASS dual-edge capture and hold: %0d checks, %0d rising and %0d falling edges", checks, rising_edges, falling_edges);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
