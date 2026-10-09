`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg j = 0;
    reg k = 0;
    wire out;
    reg expected;
    integer checks = 0;
    integer s, inputs, n;
    TopModule dut(.clk(clk), .areset(areset), .j(j), .k(k), .out(out));

    task check_output;
        begin
            if (out !== expected)
                $fatal(1, "Output mismatch at %0t: expected %b got %b", $time, expected, out);
            checks = checks + 1;
        end
    endtask

    task step(input reg new_j, input reg new_k);
        begin
            j = new_j; k = new_k;
            #2; check_output(); // Inputs alone must not change Moore output.
            if (areset) expected = 0;
            else begin
                // Independent transition table indexed by previous output and inputs.
                case ({expected, new_j, new_k})
                    3'b000, 3'b001, 3'b101, 3'b111: expected = 0;
                    3'b010, 3'b011, 3'b100, 3'b110: expected = 1;
                    default: $fatal(1, "Invalid oracle state");
                endcase
            end
            clk = 1;
            #1; check_output();
            clk = 0;
            #1; check_output();
        end
    endtask

    task reset_now;
        begin
            #1; areset = 1; expected = 0;
            #1; check_output();
            areset = 0;
            #1; check_output();
        end
    endtask

    initial begin
        // The specification gives no pre-reset initial state.
        reset_now();
        for (s = 0; s < 2; s = s + 1) begin
            for (inputs = 0; inputs < 4; inputs = inputs + 1) begin
                reset_now();
                if (s == 1) step(1, 0);
                step((inputs >> 1) & 1, inputs & 1);
            end
        end
        // Repeated simultaneous assertions alternate the state on each edge.
        for (n = 0; n < 10; n = n + 1) step(1, 1);
        step(1, 0);
        reset_now(); // Reset asserted between edges while ON.
        step(1, 0);
        #1; areset = 1; expected = 0;
        #1; check_output();
        step(1, 0); // Reset overrides an asserted turn-on input.
        step(1, 1);
        // Deassert reset while clock is high: no state transition until next edge.
        clk = 1;
        #1; check_output();
        areset = 0;
        #1; check_output();
        clk = 0;
        #1; check_output();
        step(1, 0);
        for (n = 0; n < 64; n = n + 1)
            step((n >> 1) & 1, ((n >> 2) ^ n) & 1);
        $display("PASS: %0d Moore FSM checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
