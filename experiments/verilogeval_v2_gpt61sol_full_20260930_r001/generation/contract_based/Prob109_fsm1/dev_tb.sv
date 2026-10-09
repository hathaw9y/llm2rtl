`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic in = 0;
    wire out;
    integer expected_state;
    integer checks = 0;
    integer sequence_id;
    integer bit_id;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));

    task automatic check_output;
        begin
            checks = checks + 1;
            if (out !== (expected_state == 1))
                $fatal(1, "Mismatch check=%0d out=%b expected=%0d", checks, out, expected_state);
        end
    endtask

    task automatic reset_machine;
        begin
            clk = 0;
            #2;
            areset = 1;
            expected_state = 1;
            #1;
            check_output();
            in = 0;
            clk = 1;
            #1;
            check_output();
            clk = 0;
            in = 1;
            #1;
            clk = 1;
            #1;
            check_output();
            clk = 0;
            areset = 0;
            #1;
            check_output();
        end
    endtask

    task automatic step(input logic stimulus);
        begin
            clk = 0;
            in = stimulus;
            #1;
            check_output();
            clk = 1;
            // Symbolic transition table rather than DUT toggle expression.
            case (expected_state)
                0: if (stimulus == 0) expected_state = 1;
                1: if (stimulus == 0) expected_state = 0;
                default: $fatal(1, "Invalid oracle state");
            endcase
            #1;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        reset_machine();
        step(1); // B -> B
        step(0); // B -> A
        step(1); // A -> A
        reset_machine(); // Asynchronous reset during A
        step(0);
        step(0); // A -> B
        for (sequence_id = 0; sequence_id < 256; sequence_id = sequence_id + 1) begin
            reset_machine();
            for (bit_id = 0; bit_id < 8; bit_id = bit_id + 1)
                step((sequence_id >> bit_id) & 1);
        end
        $display("PASS: %0d output checks, all 256 eight-input sequences and reset cases", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Development simulation timeout");
    end
endmodule
