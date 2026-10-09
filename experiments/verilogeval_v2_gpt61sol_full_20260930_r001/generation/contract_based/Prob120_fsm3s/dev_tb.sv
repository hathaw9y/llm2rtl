`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 0;
    wire out;
    integer model = 0;
    integer hits [0:7];
    integer checks = 0;
    integer seq, bit_idx, st, input_value, i;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    function automatic integer successor(input integer s, input bit x);
        case (s)
            0: successor = x ? 1 : 0;
            1: successor = x ? 1 : 2;
            2: successor = x ? 3 : 0;
            3: successor = x ? 1 : 2;
            default: $fatal(1, "Invalid oracle state");
        endcase
    endfunction

    task automatic check_output;
        if (out !== (model == 3))
            $fatal(1, "Output mismatch: model=%0d out=%b", model, out);
        checks = checks + 1;
    endtask

    task automatic step(input bit x, input bit rst);
        @(negedge clk);
        in = x;
        reset = rst;
        #1;
        // Input changes and synchronous reset must not change the Moore output.
        check_output();
        @(posedge clk);
        if (rst) model = 0;
        else begin
            hits[model*2 + int'(x)] = hits[model*2 + int'(x)] + 1;
            model = successor(model, x);
        end
        #1;
        check_output();
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1) hits[i] = 0;
        reset = 1;
        @(posedge clk);
        #1;
        check_output();
        for (seq = 0; seq < 256; seq = seq + 1) begin
            step(0, 1);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1)
                step((seq >> bit_idx) & 1, 0);
        end
        // Reach each state independently, then reset with each input polarity.
        for (st = 0; st < 4; st = st + 1) begin
            for (input_value = 0; input_value < 2; input_value = input_value + 1) begin
                step(0, 1);
                if (st >= 1) step(1, 0);
                if (st >= 2) step(0, 0);
                if (st >= 3) step(1, 0);
                if (model != st) $fatal(1, "State setup failed");
                step(input_value != 0, 1);
            end
        end
        for (i = 0; i < 8; i = i + 1)
            if (hits[i] == 0) $fatal(1, "Missing transition %0d", i);
        $display("PASS: %0d output checks; all eight transitions and reset from all states covered", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Watchdog timeout");
    end
endmodule
