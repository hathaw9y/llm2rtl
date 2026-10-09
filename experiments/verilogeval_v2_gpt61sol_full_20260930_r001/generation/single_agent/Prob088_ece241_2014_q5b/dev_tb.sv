`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic x = 0;
    wire z;
    bit seen_one;
    integer checks = 0;
    TopModule dut (.clk(clk), .areset(areset), .x(x), .z(z));
    always #5 clk = ~clk;

    task automatic check_output;
        logic expected;
        begin
            expected = seen_one ? ~x : x;
            if (z !== expected)
                $fatal(1, "Output mismatch: x=%b seen_one=%b z=%b expected=%b", x, seen_one, z, expected);
            if (dut.state_r !== (seen_one ? 2'b10 : 2'b01))
                $fatal(1, "One-hot state mismatch: %b", dut.state_r);
            checks = checks + 1;
        end
    endtask

    initial begin
        seen_one = 0;
        // Enumerate every eight-bit input sequence with off-edge resets.
        for (integer pattern = 0; pattern < 256; pattern = pattern + 1) begin
            @(negedge clk);
            #1 areset = 1;
            seen_one = 0;
            x = pattern[0];
            #1 check_output();
            #1 areset = 0;
            for (integer index = 0; index < 8; index = index + 1) begin
                @(negedge clk);
                x = pattern[index];
                #1 check_output();
                @(posedge clk);
                seen_one = seen_one | x;
                #1 check_output();
                // Change input between clocks to exercise Mealy response.
                #1 x = ~x;
                #1 check_output();
            end
        end
        $display("PASS: %0d output and one-hot state checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
