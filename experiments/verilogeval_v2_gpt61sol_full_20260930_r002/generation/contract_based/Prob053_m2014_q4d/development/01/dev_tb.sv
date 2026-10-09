`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic in = 1'b0;
    wire out;
    logic expected = 1'bx;
    integer checks = 0;
    TopModule dut (.clk(clk), .in(in), .out(out));

    task automatic check_output;
        begin
            checks = checks + 1;
            if (out !== expected)
                $fatal(1, "Mismatch at %0t: expected %b, got %b", $time, expected, out);
        end
    endtask

    // Drive away from rising edges, check retention, then sample after NBA.
    // Truth-table oracle expresses the original XOR feedback circuit.
    task automatic cycle(input logic value);
        begin
            in = value;
            #2;
            check_output();
            case (value)
                1'b0: expected = expected;
                1'b1: expected = ~expected;
                default: expected = 1'bx;
            endcase
            clk = 1'b1;
            #1;
            check_output();
            in = ~value;
            #2;
            check_output();
            clk = 1'b0;
            #1;
            check_output();
        end
    endtask

    initial begin
        #1;
        check_output();
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'b0);
        // Simulation-only deposit, with clock low; no reset in the DUT.
        dut.out = 1'b0;
        expected = 1'b0;
        #1;
        check_output();
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'b0);
        cycle(1'b1);
        repeat (8) cycle(1'b1);
        repeat (4) cycle(1'b0);
        dut.out = 1'b1;
        expected = 1'b1;
        #1;
        check_output();
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'b1);
        cycle(1'b0);
        cycle(1'bx);
        cycle(1'b1);
        dut.out = 1'b0;
        expected = 1'b0;
        #1;
        check_output();
        cycle(1'bz);
        cycle(1'b0);
        $display("PASS: XOR feedback flip-flop, %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
