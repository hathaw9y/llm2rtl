`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg x = 0;
    wire z;
    integer a = 0;
    integer b = 0;
    integer c = 0;
    integer next_a, next_b, next_c;
    integer sequence_number, bit_number;
    integer cycles = 0;
    TopModule dut (.clk(clk), .x(x), .z(z));

    task check_output;
        reg expected_z;
        begin
            expected_z = (a == 0 && b == 0 && c == 0);
            if (z !== expected_z)
                $fatal(1, "cycle %0d: expected z=%b, got %b (model %0d%0d%0d)",
                       cycles, expected_z, z, a, b, c);
        end
    endtask

    task step;
        input reg value;
        begin
            x = value;
            #2;
            check_output(); // Input changes must not change stored state.
            if (value != a) next_a = 1; else next_a = 0;
            if (value == 1 && b == 0) next_b = 1; else next_b = 0;
            if (value == 1 || c == 0) next_c = 1; else next_c = 0;
            clk = 1;
            a = next_a;
            b = next_b;
            c = next_c;
            cycles = cycles + 1;
            #1;
            check_output(); // Sample after nonblocking assignments settle.
            x = ~value;
            #1;
            check_output();
            clk = 0;
            #1;
            check_output(); // Falling edges must preserve state.
        end
    endtask

    initial begin
        #1;
        check_output(); // All three flip-flops initially zero, so z is one.
        repeat (16) step(0);
        repeat (16) step(1);
        repeat (16) begin step(0); step(1); end
        for (sequence_number = 0; sequence_number < 256; sequence_number = sequence_number + 1)
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1)
                step((sequence_number >> bit_number) & 1);
        $display("PASS: initialization and %0d clock cycles checked", cycles);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "bounded timeout exceeded");
    end
endmodule
