`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 0;
    wire out;
    reg expected;
    reg known = 0;
    integer checks = 0;
    integer sequence_number;
    integer bit_number;

    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));

    task check_output;
        begin
            if (known) begin
                if (out !== expected)
                    $fatal(1, "Mismatch at %0t: expected %b, got %b", $time, expected, out);
                checks = checks + 1;
            end
        end
    endtask

    // Oracle: reset selects B; input zero changes state; input one holds.
    task cycle(input reg reset_value, input reg input_value);
        begin
            reset = reset_value;
            in = input_value;
            #2;
            check_output(); // Input and reset changes must not affect output yet.
            clk = 1;
            if (reset_value) begin
                expected = 1;
                known = 1;
            end else if (known && !input_value)
                expected = !expected;
            #1;
            check_output(); // Observe after nonblocking updates.
            #2;
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        // No initial state is specified; establish one with a clocked reset.
        cycle(1, 0);
        cycle(0, 1); // B holds.
        cycle(0, 0); // B -> A.
        cycle(0, 1); // A holds.
        // A reset pulse without a rising clock must leave A unchanged.
        reset = 1;
        #2;
        check_output();
        reset = 0;
        #2;
        check_output();
        cycle(0, 1);
        cycle(1, 1); // Reset A -> B even with hold input.
        cycle(0, 0);
        cycle(1, 0); // Reset overrides toggle from A.
        cycle(1, 0); // Reset overrides toggle from B.
        cycle(1, 1);
        for (sequence_number = 0; sequence_number < 256; sequence_number = sequence_number + 1) begin
            cycle(1, sequence_number[0]);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                cycle(0, (sequence_number >> bit_number) & 1);
        end
        $display("PASS Moore transitions and synchronous reset: %0d checks", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
