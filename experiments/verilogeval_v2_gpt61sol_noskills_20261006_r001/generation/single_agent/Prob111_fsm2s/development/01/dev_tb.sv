`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg j = 0;
    reg k = 0;
    wire out;
    reg expected;
    integer checks = 0;
    integer s, bits_in, n;
    TopModule dut(.clk(clk), .reset(reset), .j(j), .k(k), .out(out));

    task check_output;
        begin
            if (out !== expected)
                $fatal(1, "Mismatch at time %0t: expected %b got %b", $time, expected, out);
            checks = checks + 1;
        end
    endtask

    // Drive inputs with clock low and compare before and after the rising edge.
    task cycle(input reg r, input reg ji, input reg ki);
        begin
            clk = 0;
            reset = r;
            j = ji;
            k = ki;
            #2;
            check_output();
            clk = 1;
            if (r) expected = 0;
            else begin
                case (expected)
                    1'b0: if (ji == 1'b1) expected = 1;
                    1'b1: if (ki == 1'b1) expected = 0;
                    default: $fatal(1, "Oracle used before reset");
                endcase
            end
            #1;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        // No power-up state is specified: establish state with synchronous reset.
        reset = 1;
        j = 1;
        k = 1;
        #2;
        clk = 1;
        expected = 0;
        #1;
        check_output();
        clk = 0;
        #1;

        // Every input pair from each known state.
        for (s = 0; s < 2; s = s + 1) begin
            for (bits_in = 0; bits_in < 4; bits_in = bits_in + 1) begin
                cycle(1, 1, 1);
                if (s == 1) cycle(0, 1, 0);
                cycle(0, (bits_in >> 1) & 1, bits_in & 1);
            end
        end

        // Reset overrides every input pair while ON; pre-edge checks ensure
        // asserting reset has no asynchronous effect.
        for (bits_in = 0; bits_in < 4; bits_in = bits_in + 1) begin
            cycle(0, 1, 0);
            cycle(1, (bits_in >> 1) & 1, bits_in & 1);
        end
        // Both inputs high repeatedly toggle, exercising successive cycles.
        for (n = 0; n < 16; n = n + 1) cycle(0, 1, 1);
        // Long holds and input irrelevance in each state.
        cycle(1, 0, 0);
        for (n = 0; n < 8; n = n + 1) cycle(0, 0, n % 2);
        cycle(0, 1, 0);
        for (n = 0; n < 8; n = n + 1) cycle(0, n % 2, 0);
        $display("PASS: %0d Moore FSM checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
