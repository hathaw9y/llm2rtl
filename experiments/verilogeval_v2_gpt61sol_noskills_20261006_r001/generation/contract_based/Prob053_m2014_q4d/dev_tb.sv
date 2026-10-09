`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg in = 0;
    wire out;
    reg expected = 1'bx;
    integer checks = 0;
    integer seed;
    integer i;

    TopModule dut (.clk(clk), .in(in), .out(out));

    task check_output;
        begin
            if (out !== expected)
                $fatal(1, "Mismatch at %0t: expected %b, got %b", $time, expected, out);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg stimulus);
        begin
            // Input changes while clock is low must not alter stored output.
            in = stimulus;
            #2;
            check_output;
            // Original circuit: D is the XOR of input and prior Q.
            expected = expected ^ stimulus;
            clk = 1;
            #1;
            check_output;
            // Input changes while clock is high must also leave Q unchanged.
            in = ~stimulus;
            #1;
            check_output;
            clk = 0;
            #1;
            check_output;
        end
    endtask

    initial begin
        #1;
        check_output;
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'b0);
        cycle(1'b1);

        // Verification-only deposits: hardware has no reset or initialization.
        // Exercise both possible binary stored states without changing the DUT.
        for (seed = 0; seed < 2; seed = seed + 1) begin
            dut.out = seed[0];
            expected = seed[0];
            #1;
            check_output;
            cycle(1'b0);
            cycle(1'b0);
            cycle(1'b1);
            cycle(1'b1);
            cycle(1'b0);
            for (i = 0; i < 16; i = i + 1)
                cycle(i[0] ^ i[2]);
        end

        dut.out = 1'b0;
        expected = 1'b0;
        #1;
        check_output;
        cycle(1'bx);
        cycle(1'b0);
        dut.out = 1'b1;
        expected = 1'b1;
        #1;
        check_output;
        cycle(1'bz);
        cycle(1'b1);

        $display("PASS: %0d circuit and edge checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
