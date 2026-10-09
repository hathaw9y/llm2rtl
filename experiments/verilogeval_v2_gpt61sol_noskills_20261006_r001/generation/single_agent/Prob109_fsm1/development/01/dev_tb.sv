`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg in = 1;
    wire out;
    reg expected;
    integer i;
    TopModule dut(.clk(clk), .areset(areset), .in(in), .out(out));

    task check;
        begin
            if (out !== expected)
                $fatal(1, "Mismatch at %0t: expected %b, got %b", $time, expected, out);
        end
    endtask

    task cycle(input reg value);
        begin
            clk = 0;
            in = value;
            #2; check; // Input alone cannot change a Moore output.
            clk = 1;
            if (areset) expected = 1;
            else begin
                // Oracle follows the two rows in the original diagram.
                case (expected)
                    1'b1: if (value == 0) expected = 0;
                    1'b0: if (value == 0) expected = 1;
                endcase
            end
            #1; check;
            clk = 0;
            #1; check;
        end
    endtask

    initial begin
        #2;
        areset = 1; expected = 1;
        #1; check; // Reset assertion occurs without a rising clock.
        cycle(0);
        cycle(1);
        areset = 0;
        #1; check;
        cycle(1); // B holds on 1.
        cycle(0); // B -> A.
        cycle(1); // A holds on 1.
        cycle(0); // A -> B.
        for (i = 0; i < 16; i = i + 1) cycle(0);
        cycle(0); // Reach A before another asynchronous reset.
        #2; areset = 1; expected = 1;
        #1; check;
        areset = 0;
        #1; check; // Deassertion alone must preserve B.
        for (i = 0; i < 64; i = i + 1) cycle((i % 3) != 0);
        $display("PASS: asynchronous reset and all FSM transitions verified");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
