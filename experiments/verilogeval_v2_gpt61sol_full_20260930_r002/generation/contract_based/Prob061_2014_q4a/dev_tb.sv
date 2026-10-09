`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic w = 1'b0, R = 1'b0, E = 1'b0, L = 1'b0;
    wire Q;
    logic expected;
    integer checks = 0;
    integer state_value, pattern;
    TopModule dut (.clk(clk), .w(w), .R(R), .E(E), .L(L), .Q(Q));

    task automatic check_value(input logic value);
        if (Q !== value)
            $fatal(1, "Mismatch at %0t: Q=%b expected=%b L=%b E=%b R=%b w=%b", $time, Q, value, L, E, R, w);
        checks = checks + 1;
    endtask

    task automatic step(input logic load, enable, data, previous);
        logic next_value;
        L = load;
        E = enable;
        R = data;
        w = previous;
        #2;
        check_value(expected);
        // Oracle: load the supplied R when L is asserted, otherwise shift
        // the previous-stage bit when E is asserted, otherwise retain state.
        case ({load, enable})
            2'b10, 2'b11: next_value = data;
            2'b01: next_value = previous;
            2'b00: next_value = expected;
        endcase
        clk = 1'b1;
        #1;
        expected = next_value;
        check_value(expected);
        #2;
        clk = 1'b0;
        #1;
        check_value(expected);
    endtask

    initial begin
        // Establish a defined state via the specified load operation.
        L = 1'b1;
        R = 1'b0;
        #2;
        clk = 1'b1;
        #1;
        expected = 1'b0;
        check_value(expected);
        clk = 1'b0;
        #1;
        for (state_value = 0; state_value < 2; state_value = state_value + 1) begin
            for (pattern = 0; pattern < 16; pattern = pattern + 1) begin
                step(1'b1, 1'b0, state_value[0], ~state_value[0]);
                step(pattern[3], pattern[2], pattern[1], pattern[0]);
            end
        end
        // Consecutive shifts and a prolonged disabled interval.
        step(0, 1, 0, 1);
        step(0, 1, 1, 0);
        repeat (5) begin
            step(0, 0, 1, 1);
            step(0, 0, 0, 0);
        end
        $display("PASS: %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
