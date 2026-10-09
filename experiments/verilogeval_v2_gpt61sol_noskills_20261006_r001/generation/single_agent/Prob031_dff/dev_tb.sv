`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg d = 0;
    wire q;
    reg expected = 1'bx;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .d(d), .q(q));

    task check_q;
        begin
            if (q !== expected)
                $fatal(1, "q mismatch at %0t: expected %b, got %b", $time, expected, q);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg sampled, input reg between_edges);
        begin
            d = sampled;
            #2;
            check_q(); // Changing data while clock is low must not capture it.
            clk = 1;
            expected = sampled;
            #1; // Observe after the nonblocking update.
            check_q();
            d = between_edges;
            #1;
            check_q(); // Data changes while clock is high must be ignored.
            clk = 0;
            #1;
            check_q(); // Falling edges must preserve state.
        end
    endtask

    initial begin
        #1;
        check_q(); // No reset or initialization: q starts unknown.
        cycle(0, 1);
        cycle(1, 0);
        cycle(1, 0);
        cycle(0, 1);
        cycle(0, 0);
        cycle(1, 1);
        cycle(1'bx, 0);
        cycle(0, 1'bx);
        cycle(1'bz, 1);
        cycle(1, 1'bz);
        for (i = 0; i < 32; i = i + 1)
            cycle((i % 3) == 0, (i % 2) == 0);
        $display("PASS: %0d D flip-flop checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
