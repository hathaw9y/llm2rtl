`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic a = 1;
    logic b = 1'bx;
    wire q, state;
    integer checks = 0;
    TopModule dut (.clk(clk), .a(a), .b(b), .q(q), .state(state));

    task automatic check(input logic expected_state, input logic expected_q);
        begin
            #1;
            if (state !== expected_state || q !== expected_q)
                $fatal(1, "Mismatch: a=%b b=%b state=%b expected=%b q=%b expected=%b",
                       a, b, state, expected_state, q, expected_q);
            checks = checks + 1;
        end
    endtask

    // Establish the state from the preceding interval, then change inputs
    // after the rising edge, as represented by the supplied waveform.
    task automatic row(input logic new_a, input logic new_b,
                       input logic expected_state, input logic expected_q);
        begin
            #4; clk = 1;
            #1; a = new_a; b = new_b;
            check(expected_state, expected_q);
            #4; clk = 0;
        end
    endtask

    initial begin
        check(1'bx, 1'bx);
        row(1, 1'bx, 1'bx, 1'bx);
        a = 0; b = 0;
        row(0, 0, 0, 0);
        row(0, 0, 0, 0);
        row(0, 0, 0, 0);
        row(0, 1, 0, 1);
        row(1, 0, 0, 1);
        row(1, 1, 0, 0);
        row(0, 0, 1, 1);
        row(1, 1, 0, 0);
        row(1, 1, 1, 1);
        row(1, 1, 1, 1);
        row(1, 0, 1, 0);
        row(0, 1, 1, 0);
        row(0, 0, 1, 1);
        repeat (5) row(0, 0, 0, 0);

        // Cover all combinational input combinations for both stored states.
        for (integer s = 0; s < 2; s = s + 1) begin
            a = (s != 0); b = (s != 0);
            #4; clk = 1;
            #1;
            for (integer v = 0; v < 4; v = v + 1) begin
                a = ((v & 2) != 0); b = ((v & 1) != 0);
                check((s != 0), (((v >> 1) ^ v ^ s) & 1) != 0);
            end
            clk = 0;
        end
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Development simulation timeout");
    end
endmodule
