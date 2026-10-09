`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg w = 0, R = 0, E = 0, L = 0;
    wire Q;
    reg expected = 1'bx;
    integer checks = 0;
    integer state_value, controls;
    TopModule dut(.clk(clk), .w(w), .R(R), .E(E), .L(L), .Q(Q));

    task check_output;
        begin
            if (Q !== expected)
                $fatal(1, "Q mismatch at %0t: expected %b got %b L=%b E=%b R=%b w=%b",
                       $time, expected, Q, L, E, R, w);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg li, ei, ri, wi);
        reg next_expected;
        begin
            L = li; E = ei; R = ri; w = wi;
            #2;
            check_output(); // Input changes cannot update the stored bit.
            if (li) next_expected = ri;
            else if (ei) next_expected = wi;
            else next_expected = expected;
            clk = 1;
            expected = next_expected;
            #1;
            check_output(); // Sample after nonblocking updates.
            // Change data while high; check that only a rising edge captures.
            R = ~ri; w = ~wi;
            #1;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        #1;
        check_output();
        cycle(0, 0, 0, 0); // No reset or initialization: hold unknown initially.
        cycle(0, 0, 1, 1);
        cycle(0, 1, 1, 0);
        cycle(0, 1, 0, 1);
        // Exercise all input combinations from both stored values.
        for (state_value = 0; state_value < 2; state_value = state_value + 1) begin
            for (controls = 0; controls < 16; controls = controls + 1) begin
                cycle(1, 0, state_value != 0, state_value == 0);
                cycle(controls[3], controls[2], controls[1], controls[0]);
            end
        end
        $display("PASS: %0d checks of load priority, shift, hold, and edge timing", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
