`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg x = 0;
    wire z;
    integer model;
    integer count = 0;
    integer coverage [0:4][0:1];
    integer seq, bitidx, stateidx, inputidx, routeidx;
    TopModule dut (.clk(clk), .reset(reset), .x(x), .z(z));

    function integer transition(input integer state, input integer value);
        case (state)
            0: if (value == 0) transition = 0; else transition = 1;
            1: if (value == 0) transition = 1; else transition = 4;
            2: if (value == 0) transition = 2; else transition = 1;
            3: if (value == 0) transition = 1; else transition = 2;
            4: if (value == 0) transition = 3; else transition = 4;
            default: $fatal(1, "Invalid oracle state");
        endcase
    endfunction

    task check_output;
        reg expected;
        begin
            expected = (model == 3 || model == 4);
            if (z !== expected)
                $fatal(1, "Output mismatch step=%0d state=%0d z=%b expected=%b", count, model, z, expected);
        end
    endtask

    task step(input reg reset_value, input reg input_value);
        begin
            // Inputs change with the clock low. Synchronous reset cannot alter z here.
            reset = reset_value;
            x = input_value;
            #2;
            check_output;
            if (reset_value) model = 0;
            else begin
                coverage[model][input_value] = coverage[model][input_value] + 1;
                model = transition(model, input_value);
            end
            clk = 1;
            #1;
            count = count + 1;
            check_output;
            #2;
            clk = 0;
            #1;
            check_output;
        end
    endtask

    initial begin
        for (stateidx = 0; stateidx < 5; stateidx = stateidx + 1)
            for (inputidx = 0; inputidx < 2; inputidx = inputidx + 1)
                coverage[stateidx][inputidx] = 0;
        // No output assumption before the first synchronous reset edge.
        #2; reset = 1; x = 1;
        #2; clk = 1; model = 0;
        #1; check_output;
        #2; clk = 0;
        #1;
        // Paths of lengths 0..4 visit 000,001,100,011,010.
        for (stateidx = 0; stateidx < 5; stateidx = stateidx + 1) begin
            for (inputidx = 0; inputidx < 2; inputidx = inputidx + 1) begin
                step(1, 0);
                for (routeidx = 0; routeidx < stateidx; routeidx = routeidx + 1)
                    step(0, routeidx != 2);
                // Pulse reset entirely between edges: state must remain unchanged.
                reset = 1; #1; check_output;
                reset = 0; #1; check_output;
                step(1, inputidx);
                step(1, inputidx);
            end
        end
        for (seq = 0; seq < 256; seq = seq + 1) begin
            step(1, seq & 1);
            for (bitidx = 7; bitidx >= 0; bitidx = bitidx - 1)
                step(0, (seq >> bitidx) & 1);
        end
        for (stateidx = 0; stateidx < 5; stateidx = stateidx + 1)
            for (inputidx = 0; inputidx < 2; inputidx = inputidx + 1)
                if (coverage[stateidx][inputidx] == 0)
                    $fatal(1, "Missing transition state=%0d x=%0d", stateidx, inputidx);
        $display("PASS all transitions, exhaustive input sequences, synchronous resets; %0d steps", count);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
