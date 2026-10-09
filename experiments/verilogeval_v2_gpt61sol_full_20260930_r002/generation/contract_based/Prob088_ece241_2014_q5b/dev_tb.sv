`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic x = 0;
    wire z;
    bit seen_one = 0;
    integer checks = 0;
    integer pattern, i;
    TopModule dut (.clk(clk), .areset(areset), .x(x), .z(z));

    // Independent history oracle: complement after the first sampled one.
    task automatic check_output;
        logic expected;
        begin
            expected = x ^ seen_one;
            if (z !== expected)
                $fatal(1, "Output mismatch at %0t x=%b seen_one=%b z=%b expected=%b", $time, x, seen_one, z, expected);
            checks = checks + 1;
        end
    endtask

    task automatic reset_between_edges;
        begin
            clk = 0;
            #2;
            areset = 1;
            seen_one = 0;
            #1;
            check_output();
            x = 0;
            #1;
            check_output();
            x = 1;
            #1;
            check_output();
            clk = 1;
            #1;
            check_output();
            clk = 0;
            #1;
            areset = 0;
            #1;
            check_output();
        end
    endtask

    task automatic sample_bit(input bit value);
        begin
            clk = 0;
            x = value;
            #2;
            check_output();
            clk = 1;
            if (areset) seen_one = 0;
            else if (x) seen_one = 1;
            #1;
            check_output();
            // Mealy response must track input without a clock edge.
            x = ~value;
            #1;
            check_output();
            x = value;
            #1;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        #1;
        reset_between_edges();
        sample_bit(0);
        sample_bit(0);
        sample_bit(1);
        sample_bit(0);
        sample_bit(1);
        reset_between_edges();
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            reset_between_edges();
            for (i = 0; i < 8; i = i + 1)
                sample_bit((pattern >> i) & 1);
        end
        $display("PASS: %0d Mealy output checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
