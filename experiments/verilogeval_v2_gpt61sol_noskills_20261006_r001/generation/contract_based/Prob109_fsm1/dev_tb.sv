`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg in = 0;
    wire out;
    reg expected;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));

    task check_output;
        begin
            checks = checks + 1;
            if (out !== expected)
                $fatal(1, "Mismatch at %0t: expected %b got %b", $time, expected, out);
        end
    endtask

    // Oracle follows the original diagram with B represented by one.
    task rising_edge;
        begin
            if (areset) expected = 1;
            else if (expected == 1) begin
                if (in == 0) expected = 0;
                else expected = 1;
            end else begin
                if (in == 0) expected = 1;
                else expected = 0;
            end
            clk = 1;
            #1;
            check_output;
        end
    endtask

    task cycle(input reg value);
        begin
            clk = 0;
            #1;
            check_output;
            in = value;
            #1;
            check_output;
            rising_edge;
        end
    endtask

    initial begin
        // No specified pre-reset state: first assert reset away from a clk edge.
        #2;
        areset = 1;
        expected = 1;
        #1;
        check_output;
        rising_edge; // Reset dominates even with in=0.
        clk = 0;
        #1;
        check_output;
        areset = 0;
        #1;
        check_output;

        cycle(1); // B -> B
        cycle(0); // B -> A
        cycle(1); // A -> A
        cycle(0); // A -> B
        cycle(0); // B -> A

        // Assert reset while clk remains high in A: no clock event needed.
        #2;
        areset = 1;
        expected = 1;
        #1;
        check_output;
        in = 1;
        #1;
        check_output;
        areset = 0;
        #1;
        check_output;
        cycle(1);

        // Hold reset across multiple edges with both input values.
        clk = 0;
        #1;
        areset = 1;
        expected = 1;
        #1;
        check_output;
        cycle(0);
        cycle(1);
        cycle(0);
        clk = 0;
        #1;
        areset = 0;
        #1;
        check_output;

        for (i = 0; i < 128; i = i + 1)
            cycle(((i % 7) == 0) || ((i % 5) == 2) || ((i % 3) == 1));
        $display("PASS: Moore FSM directed and mixed sequence checks (%0d)", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
