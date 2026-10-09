`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic in = 0;
    wire out;
    integer model = 0;
    integer checks = 0;
    integer transitions [0:3][0:1];
    integer old_model;
    integer pattern;
    integer bit_index;
    integer s;
    integer b;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk = ~clk;

    task automatic check_output;
        begin
            if (out !== (model == 3))
                $fatal(1, "Mismatch state=%0d expected=%0d actual=%b", model, (model == 3), out);
            checks = checks + 1;
        end
    endtask

    // Drive between edges, check Moore stability before the edge, then sample
    // after nonblocking state updates have settled.
    task automatic step(input logic rst_value, input logic input_value);
        begin
            @(negedge clk);
            reset = rst_value;
            in = input_value;
            #1;
            check_output();
            @(posedge clk);
            old_model = model;
            if (reset) model = 0;
            else begin
                transitions[old_model][in] = transitions[old_model][in] + 1;
                case (model)
                    0: if (in) model = 1; else model = 0;
                    1: if (in) model = 1; else model = 2;
                    2: if (in) model = 3; else model = 0;
                    3: if (in) model = 1; else model = 2;
                endcase
            end
            #1;
            check_output();
        end
    endtask

    initial begin
        for (s = 0; s < 4; s = s + 1)
            for (b = 0; b < 2; b = b + 1) transitions[s][b] = 0;
        // Establish state only through the specified synchronous reset.
        reset = 1;
        @(posedge clk);
        #1;
        model = 0;
        check_output();
        // Exhaust all 8-bit input sequences from reset, including every edge.
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            step(1, pattern[0]);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                step(0, (pattern >> bit_index) & 1);
        end
        // Reset in each reachable state; reset while D must remain high
        // until the active clock edge, as checked inside step.
        step(1, 0);
        step(0, 1);
        step(1, 1);
        step(0, 1);
        step(0, 0);
        step(1, 1);
        step(0, 1);
        step(0, 0);
        step(0, 1);
        step(1, 1);
        step(1, 0);
        for (s = 0; s < 4; s = s + 1)
            for (b = 0; b < 2; b = b + 1)
                if (transitions[s][b] == 0)
                    $fatal(1, "Missing transition state=%0d input=%0d", s, b);
        $display("PASS: Moore FSM transitions, synchronous reset, and output stability (%0d checks)", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
