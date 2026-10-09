`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic reset = 1'b0;
    logic in = 1'b1;
    wire out;
    integer expected_state;
    integer checked_cycles = 0;
    integer i;

    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    task automatic check_output;
        begin
            if (out !== (expected_state == 1))
                $fatal(1, "cycle %0d expected state/output %0d, got %b", checked_cycles, expected_state, out);
        end
    endtask

    // Oracle uses the original state's transition table: 0=A, 1=B.
    task automatic cycle(input logic reset_value, input logic input_value);
        begin
            @(negedge clk);
            reset = reset_value;
            in = input_value;
            #1;
            check_output(); // Neither input nor synchronous reset changes output now.
            @(posedge clk);
            if (reset_value) begin
                expected_state = 1;
            end else begin
                case (expected_state)
                    0: if (input_value == 0) expected_state = 1;
                       else expected_state = 0;
                    1: if (input_value == 0) expected_state = 0;
                       else expected_state = 1;
                    default: $fatal(1, "Invalid testbench state");
                endcase
            end
            #1;
            checked_cycles = checked_cycles + 1;
            check_output();
        end
    endtask

    initial begin
        // Establish B by an actual rising clock with reset asserted.
        reset = 1'b1;
        @(posedge clk);
        expected_state = 1;
        #1;
        check_output();
        cycle(0, 1); // B holds
        cycle(0, 0); // B -> A
        cycle(0, 1); // A holds
        cycle(0, 0); // A -> B
        cycle(0, 0); // B -> A
        cycle(1, 1); // reset A -> B
        cycle(1, 0); // reset overrides B -> A
        cycle(0, 0); // B -> A

        // A reset pulse entirely between rising edges must have no effect.
        @(negedge clk);
        in = 1'b1;
        reset = 1'b1;
        #1;
        check_output();
        reset = 1'b0;
        #1;
        check_output();
        @(posedge clk);
        #1;
        check_output();

        for (i = 0; i < 64; i = i + 1)
            cycle((i % 13) == 0, ((i % 5) == 0) || ((i % 5) == 3));
        $display("PASS: transition table, synchronous reset, reset priority, and Moore output checked");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Testbench timeout");
    end
endmodule
