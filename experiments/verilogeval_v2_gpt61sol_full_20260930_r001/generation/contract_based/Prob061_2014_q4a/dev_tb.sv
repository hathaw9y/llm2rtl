`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic w = 0, R = 0, E = 0, L = 0;
    wire Q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .w(w), .R(R), .E(E), .L(L), .Q(Q));

    task automatic check_q(input logic value);
        if (Q !== value)
            $fatal(1, "FAIL check %0d: Q=%b expected=%b", checks, Q, value);
        checks = checks + 1;
    endtask

    task automatic cycle(input logic l_in, e_in, r_in, w_in);
        L = l_in; E = e_in; R = r_in; w = w_in;
        #2;
        check_q(expected);
        case ({l_in, e_in})
            2'b00: expected = expected;
            2'b01: expected = w_in;
            2'b10, 2'b11: expected = r_in;
        endcase
        clk = 1;
        #1;
        check_q(expected);
        clk = 0;
        #1;
        check_q(expected);
    endtask

    initial begin
        // Establish known state solely through the specified synchronous load.
        L = 1; R = 0;
        #2; clk = 1; #1;
        expected = 0;
        check_q(expected);
        clk = 0; #1;
        for (integer prior = 0; prior < 2; prior = prior + 1) begin
            for (integer inputs = 0; inputs < 16; inputs = inputs + 1) begin
                cycle(1, 0, prior[0], 0);
                cycle(inputs[3], inputs[2], inputs[1], inputs[0]);
            end
        end
        // Hold while unused data changes, then shift and load repeatedly.
        for (integer i = 0; i < 8; i = i + 1) begin
            cycle(0, 0, i[0], ~i[0]);
            cycle(0, 1, ~i[0], i[0]);
            cycle(1, 1, ~i[0], i[0]);
        end
        $display("PASS: %0d state/timing checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: simulation watchdog timeout");
    end
endmodule
