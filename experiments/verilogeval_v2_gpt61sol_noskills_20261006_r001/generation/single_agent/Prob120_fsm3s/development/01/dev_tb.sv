`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 0;
    wire out;
    integer model;
    integer sequence_number, bit_number;
    integer checks = 0;
    reg valid = 0;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));

    // Independent table oracle: index = 2*state + input.
    function integer transition(input integer current, input reg value);
        begin
            case (2*current + value)
                0: transition = 0;
                1: transition = 1;
                2: transition = 2;
                3: transition = 1;
                4: transition = 0;
                5: transition = 3;
                6: transition = 2;
                7: transition = 1;
                default: $fatal(1, "Invalid oracle state");
            endcase
        end
    endfunction

    task check_output;
        begin
            if (out !== (model == 3))
                $fatal(1, "Mismatch at time %0t: state=%0d out=%b", $time, model, out);
            checks = checks + 1;
        end
    endtask

    task step(input reg value, input reg rst);
        begin
            in = value;
            reset = rst;
            #2;
            if (valid) check_output(); // Input/reset changes cannot change Moore output.
            #3;
            clk = 1;
            if (rst) model = 0;
            else model = transition(model, value);
            valid = 1;
            #1;
            check_output(); // Sample after sequential nonblocking updates.
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        // No initial-state requirement: establish state with a reset edge first.
        step(0, 1);
        for (sequence_number = 0; sequence_number < 256; sequence_number = sequence_number + 1) begin
            step(1, 1);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                step((sequence_number >> bit_number) & 1, 0);
        end
        // Reset from A, B, C, D, including high output before the reset edge.
        step(0, 1);
        step(1, 0);
        step(1, 1);
        step(1, 0);
        step(0, 0);
        step(0, 1);
        step(1, 0);
        step(0, 0);
        step(1, 0);
        step(1, 1);
        step(0, 1);
        step(0, 0);
        $display("PASS: exhaustive sequences and synchronous reset, %0d output checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
