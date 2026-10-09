`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    wire shift_ena;
    integer age = 0;
    integer checks = 0;
    reg initialized = 0;
    reg expected;

    TopModule dut (.clk(clk), .reset(reset), .shift_ena(shift_ena));
    always #5 clk = ~clk;

    // Oracle counts elapsed rising edges since reset, independently of DUT state.
    always @(posedge clk) begin
        if (reset) begin
            initialized = 1;
            age = 0;
        end else if (initialized && age < 4) begin
            age = age + 1;
        end
        #1;
        if (initialized) begin
            expected = (age < 4);
            if (shift_ena !== expected)
                $fatal(1, "Mismatch t=%0t age=%0d reset=%b got=%b expected=%b",
                       $time, age, reset, shift_ena, expected);
            checks = checks + 1;
        end
    end

    task cycles(input integer n);
        repeat (n) @(negedge clk);
    endtask

    initial begin
        // Initial unreset edges: original specification leaves these unconstrained.
        cycles(2);
        reset = 1;
        cycles(1);
        reset = 0;
        cycles(12); // Includes fourth-cycle boundary and persistent disabled state.

        // An off-edge pulse must not synchronously reset the FSM.
        #1 reset = 1;
        #2;
        if (shift_ena !== 0) $fatal(1, "Asynchronous reset effect");
        reset = 0;
        cycles(2);

        reset = 1;
        cycles(1);
        reset = 0;
        cycles(2);
        reset = 1; // Restart before the earlier interval completes.
        cycles(1);
        reset = 0;
        cycles(7);

        reset = 1;
        cycles(6); // Every held-reset edge must keep the output enabled.
        reset = 0;
        cycles(10);

        // Pulse between edges while enabled: must not extend the interval.
        reset = 1;
        cycles(1);
        reset = 0;
        cycles(2);
        #1 reset = 1;
        #2;
        if (shift_ena !== 1) $fatal(1, "Enable changed between clock edges");
        reset = 0;
        cycles(8);

        if (checks < 50) $fatal(1, "Insufficient checks");
        $display("PASS four-cycle enable, synchronous reset, restart, and saturation (%0d checks)", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
