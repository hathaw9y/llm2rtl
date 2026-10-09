`timescale 1ns/1ps
module dev_tb;
    logic clk, a, b;
    wire state, q;
    integer s, v;
    logic expected_state;
    TopModule dut (.clk(clk), .a(a), .b(b), .q(q), .state(state));

    task automatic check(input logic es, input logic eq);
        if (state !== es || q !== eq)
            $fatal(1, "At %0t: state=%b q=%b expected state=%b q=%b", $time, state, q, es, eq);
    endtask

    // Inputs change at the listed timestamp, after the clock samples their
    // previous values. Check after nonblocking updates settle.
    task automatic row(input integer t, input logic c, aa, bb, es, eq);
        #(t - $realtime);
        clk = c;
        a <= aa;
        b <= bb;
        #0.001;
        check(es, eq);
    endtask

    // Independent parity truth table; unknown operands yield unknown q.
    function automatic logic expected_q(input logic ss, aa, bb);
        case ({ss, aa, bb})
            3'b000, 3'b011, 3'b101, 3'b110: expected_q = 1'b0;
            3'b001, 3'b010, 3'b100, 3'b111: expected_q = 1'b1;
            default: expected_q = 1'bx;
        endcase
    endfunction

    initial begin
        clk = 0;
        a = 1;
        b = 1'bx;
        #0.001; check(1'bx, 1'bx);
        row(5, 1'b1, 1'b1, 1'bx, 1'bx, 1'bx);
        row(10, 1'b0, 1'b0, 1'b0, 1'bx, 1'bx);
        row(15, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        row(20, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        row(25, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        row(30, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        row(35, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        row(40, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        row(45, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1);
        row(50, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1);
        row(55, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1);
        row(60, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        row(65, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0);
        row(70, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0);
        row(75, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
        row(80, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
        row(85, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0);
        row(90, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0);
        row(95, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1);
        row(100, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1);
        row(105, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1);
        row(110, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1);
        row(115, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0);
        row(120, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0);
        row(125, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0);
        row(130, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
        row(135, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
        row(140, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
        row(145, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        row(150, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        row(155, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        row(160, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        row(165, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        row(170, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        row(175, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        row(180, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        row(185, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        row(190, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);

        // Exhaust all (prior state, a, b) combinations, testing both
        // combinational changes with clk low and the following rising edge.
        for (s = 0; s < 2; s = s + 1) begin
            for (v = 0; v < 4; v = v + 1) begin
                #2; clk = 0; a = s[0]; b = s[0];
                #2; clk = 1;
                #0.001; check(s[0], expected_q(s[0], s[0], s[0]));
                #2; clk = 0; a = v[1]; b = v[0];
                #0.001; check(s[0], expected_q(s[0], v[1], v[0]));
                case (v)
                    0: expected_state = 1'b0;
                    3: expected_state = 1'b1;
                    default: expected_state = s[0];
                endcase
                #2; clk = 1;
                #0.001; check(expected_state, expected_q(expected_state, v[1], v[0]));
            end
        end
        $display("PASS waveform replay and exhaustive binary transitions");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
