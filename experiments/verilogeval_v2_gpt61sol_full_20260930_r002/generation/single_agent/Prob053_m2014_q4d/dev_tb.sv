`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic in = 1'b0;
    wire out;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .in(in), .out(out));

    task automatic check_output;
        begin
            if (out !== expected)
                $fatal(1, "Mismatch at %0t: expected %b observed %b", $time, expected, out);
            checks = checks + 1;
        end
    endtask

    // Oracle from the flip-flop truth table: zero holds, one toggles.
    task automatic cycle(input logic sample);
        begin
            clk = 1'b0;
            in = sample;
            #2; check_output();
            case ({expected, sample})
                2'b00: expected = 1'b0;
                2'b01: expected = 1'b1;
                2'b10: expected = 1'b1;
                2'b11: expected = 1'b0;
                default: expected = 1'bx;
            endcase
            clk = 1'b1;
            #1; check_output();
            in = ~sample;
            #2; check_output();
            clk = 1'b0;
            #1; check_output();
        end
    endtask

    initial begin
        expected = 1'bx;
        #1; check_output();
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'bx);
        // No reset exists. Deposit a hypothetical power-up state solely
        // in simulation to exercise both physical binary starting states.
        $deposit(dut.out, 1'b0);
        expected = 1'b0;
        #1; check_output();
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'b1);
        cycle(1'b1);
        $deposit(dut.out, 1'b1);
        expected = 1'b1;
        #1; check_output();
        cycle(1'b0);
        cycle(1'b1);
        cycle(1'b1);
        cycle(1'b0);
        cycle(1'bx);
        cycle(1'b0);
        $display("PASS: %0d startup, edge, hold, and toggle checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
