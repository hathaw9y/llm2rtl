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

    // Original transitions: B records that a one was sampled since reset.
    always @(posedge clk or posedge areset) begin
        if (areset) seen_one <= 0;
        else if (x) seen_one <= 1;
    end

    task check_output;
        reg expected;
        begin
            expected = seen_one ^ x;
            if (z !== expected)
                $fatal(1, "Output mismatch time=%0t history=%b x=%b expected=%b got=%b", $time, seen_one, x, expected, z);
            checks = checks + 1;
        end
    endtask

    task sample_bit(input reg value);
        begin
            clk = 0;
            x = value;
            #2; check_output(); // Mealy value before sampling this bit.
            clk = 1;
            #1; check_output(); // Updated state after positive edge.
            clk = 0;
            #1; check_output(); // Negative edge has no state effect.
        end
    endtask

    initial begin
        #1; areset = 1;
        #1; check_output();
        x = 1;
        #1; check_output(); // Reset A still produces z=x.
        clk = 1;
        #1; check_output(); // Reset dominates x=1 at positive edge.
        clk = 0;
        areset = 0;
        #1; check_output(); // Reset release does not advance state.
        x = 0;
        #1; check_output();
        sample_bit(0);
        sample_bit(0);
        sample_bit(1);
        sample_bit(1);
        sample_bit(0);
        // Toggle x repeatedly without a positive clock edge in B.
        x = 1; #1; check_output();
        x = 0; #1; check_output();
        x = 1; #1; check_output();
        areset = 1; #1; check_output(); // Asynchronous B to A with clk low.
        areset = 0; #1; check_output();
        x = 0; #1; check_output(); // No x=1 was clocked after reset.
        for (i = 0; i < 32; i = i + 1) begin
            sample_bit(i % 2);
        end
        x = 0;
        #1; check_output();
        clk = 1;
        #1; check_output();
        areset = 1;
        #1; check_output(); // Async reset while clock remains high.
        x = 1;
        #1; check_output();
        areset = 0;
        #1; check_output();
        clk = 0;
        #1; check_output();
        sample_bit(1);
        sample_bit(0);
        $display("PASS: original Mealy FSM checks completed (%0d checks)", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
