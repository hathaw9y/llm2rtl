`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic a = 1;
    logic b = 1'bx;
    wire q, state;
    integer checks = 0;
    integer s, pair;
    logic expected_q, expected_state;
    TopModule dut (.clk(clk), .a(a), .b(b), .q(q), .state(state));

    task automatic check(input logic es, input logic eq);
        begin
            if (state !== es || q !== eq)
                $fatal(1, "Mismatch at %0t: state=%b expected=%b q=%b expected=%b", $time, state, es, q, eq);
            checks = checks + 1;
        end
    endtask

    // Explicit truth table independently records the eight observed combinations.
    function automatic logic truth_q(input logic st, aa, bb);
        case ({st,aa,bb})
            3'b000: truth_q = 0;
            3'b001: truth_q = 1;
            3'b010: truth_q = 1;
            3'b011: truth_q = 0;
            3'b100: truth_q = 1;
            3'b101: truth_q = 0;
            3'b110: truth_q = 0;
            3'b111: truth_q = 1;
            default: truth_q = 1'bx;
        endcase
    endfunction

    initial begin
        clk = 1'b0;
        #0.001;
        a = 1'b1; b = 1'bx;
        #0; check(1'bx, 1'bx); // Original row 0ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b1; b = 1'bx;
        #0; check(1'bx, 1'bx); // Original row 5ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'bx, 1'bx); // Original row 10ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 15ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 20ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 25ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 30ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 35ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 40ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b1;
        #0; check(1'b0, 1'b1); // Original row 45ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b1;
        #0; check(1'b0, 1'b1); // Original row 50ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b1; b = 1'b0;
        #0; check(1'b0, 1'b1); // Original row 55ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b1; b = 1'b0;
        #0; check(1'b0, 1'b1); // Original row 60ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b1; b = 1'b1;
        #0; check(1'b0, 1'b0); // Original row 65ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b1; b = 1'b1;
        #0; check(1'b0, 1'b0); // Original row 70ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b1, 1'b1); // Original row 75ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b1, 1'b1); // Original row 80ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b1; b = 1'b1;
        #0; check(1'b0, 1'b0); // Original row 85ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b1; b = 1'b1;
        #0; check(1'b0, 1'b0); // Original row 90ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b1; b = 1'b1;
        #0; check(1'b1, 1'b1); // Original row 95ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b1; b = 1'b1;
        #0; check(1'b1, 1'b1); // Original row 100ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b1; b = 1'b1;
        #0; check(1'b1, 1'b1); // Original row 105ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b1; b = 1'b1;
        #0; check(1'b1, 1'b1); // Original row 110ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b1; b = 1'b0;
        #0; check(1'b1, 1'b0); // Original row 115ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b1; b = 1'b0;
        #0; check(1'b1, 1'b0); // Original row 120ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b1;
        #0; check(1'b1, 1'b0); // Original row 125ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b1;
        #0; check(1'b1, 1'b0); // Original row 130ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b1, 1'b1); // Original row 135ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b1, 1'b1); // Original row 140ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 145ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 150ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 155ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 160ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 165ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 170ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 175ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 180ns
        #4.999;
        clk = 1'b1;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 185ns
        #4.999;
        clk = 1'b0;
        #0.001;
        a = 1'b0; b = 1'b0;
        #0; check(1'b0, 1'b0); // Original row 190ns

        // Establish each state using external inputs, then exercise every input pair.
        for (s = 0; s < 2; s = s + 1) begin
            for (pair = 0; pair < 4; pair = pair + 1) begin
                clk = 0; a = s[0]; b = s[0];
                #1; clk = 1; #1;
                a = pair[1]; b = pair[0];
                #1; check(s[0], truth_q(s[0], a, b));
                clk = 0; #1;
                check(s[0], truth_q(s[0], a, b));
                // AND's Boolean truth table is one only for input pair 11.
                expected_state = (pair == 3);
                expected_q = truth_q(expected_state, a, b);
                clk = 1; #1; check(expected_state, expected_q);
                clk = 0; #1; check(expected_state, expected_q);
            end
        end
        $display("PASS: %0d checks (original waveform, exhaustive truth table, edge sampling and hold)", checks);
        $finish;
    end
    initial begin
        #1000; $fatal(1, "Testbench timeout");
    end
endmodule
