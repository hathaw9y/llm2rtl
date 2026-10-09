`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg x = 0;
    wire z;
    reg seen_one;
    integer checks = 0;
    integer i;
    TopModule dut(.clk(clk), .areset(areset), .x(x), .z(z));
    always #5 clk = ~clk;

    // The serial complement copies bits through the first one, then inverts.
    always @(posedge clk or posedge areset) begin
        if (areset) seen_one <= 0;
        else if (x) seen_one <= 1;
    end

    task check_output;
        reg expected;
        begin
            expected = seen_one ? ~x : x;
            if (z !== expected)
                $fatal(1, "Output mismatch t=%0t x=%b seen_one=%b z=%b expected=%b",
                       $time, x, seen_one, z, expected);
            checks = checks + 1;
        end
    endtask

    task bit_cycle(input reg value);
        begin
            @(negedge clk);
            x = value;
            #1; check_output();
            @(posedge clk);
            #1; check_output();
        end
    endtask

    initial begin
        // No behavior is specified before the first reset.
        #2; areset = 1;
        #1; check_output();
        x = 1;
        #1; check_output();
        #2; check_output(); // positive clock edge while reset is held
        areset = 0;
        bit_cycle(0);
        bit_cycle(0);
        bit_cycle(1); // output changes as A transitions into B
        bit_cycle(1);
        bit_cycle(0);
        bit_cycle(0);
        bit_cycle(1);
        // Reset between clock edges must immediately restore copying.
        @(negedge clk);
        #2; areset = 1;
        #1; check_output();
        x = 0;
        #1; check_output();
        #3; check_output();
        areset = 0;
        for (i = 0; i < 16; i = i + 1) bit_cycle(0);
        bit_cycle(1);
        for (i = 0; i < 32; i = i + 1) bit_cycle((i % 3) == 0);
        @(negedge clk);
        x = 0;
        #1; check_output();
        areset = 1;
        #1; check_output();
        areset = 0;
        #1; check_output();
        bit_cycle(1);
        bit_cycle(0);
        $display("PASS: %0d output checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
