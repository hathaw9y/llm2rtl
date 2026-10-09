`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic x = 0, y = 0;
    wire f, g;
    TopModule dut(.clk(clk), .resetn(resetn), .x(x), .y(y), .f(f), .g(g));

    // Oracle uses the last three input samples and a response countdown,
    // rather than the DUT's prefix states.
    integer mode = 0; // 0 reset, 1 pulse, 2 x sampling, 3 response, 4 terminal
    integer count = 0, remaining = 0, comparisons = 0;
    reg [2:0] history = 0;
    reg expected_f = 0, expected_g = 0;
    reg saved_f, saved_g;
    integer stream, k, response;
    reg [31:0] prng = 32'hca123bad;

    task automatic tick(input bit rn, input bit xv, input bit yv);
        begin
            clk = 0;
            resetn = rn; x = xv; y = yv;
            saved_f = f; saved_g = g;
            #4;
            if (comparisons > 0 && (f !== saved_f || g !== saved_g))
                $fatal(1, "Outputs changed without a rising edge");
            clk = 1;
            if (!rn) begin
                mode = 0; count = 0; history = 0; remaining = 0;
                expected_f = 0; expected_g = 0;
            end else if (mode == 0) begin
                mode = 1; expected_f = 1; expected_g = 0;
            end else if (mode == 1 || mode == 2) begin
                mode = 2; expected_f = 0;
                history = {history[1:0], xv};
                count = count + 1;
                if (count >= 3 && history == 3'b101) begin
                    mode = 3; expected_g = 1; remaining = 2;
                end
            end else if (mode == 3) begin
                if (yv) begin
                    mode = 4; expected_g = 1;
                end else begin
                    remaining = remaining - 1;
                    if (remaining == 0) begin
                        mode = 4; expected_g = 0;
                    end
                end
            end
            #1;
            comparisons = comparisons + 1;
            if (f !== expected_f || g !== expected_g)
                $fatal(1, "Mismatch check=%0d resetn=%b x=%b y=%b got f/g=%b%b expected=%b%b mode=%0d", comparisons, rn, xv, yv, f, g, expected_f, expected_g, mode);
            #1; clk = 0;
        end
    endtask

    initial begin
        tick(0,0,0);
        // Exhaustive short x streams, including all mismatched prefixes.
        for (stream = 0; stream < 256; stream = stream + 1) begin
            for (response = 0; response < 4; response = response + 1) begin
                tick(0,1,1);
                tick(1,1,1); // Inputs in startup edge must be ignored.
                for (k = 0; k < 8; k = k + 1)
                    tick(1, (stream >> k) & 1, (response >> (k % 2)) & 1);
                for (k = 0; k < 5; k = k + 1)
                    tick(1, k % 2, (response >> (k % 2)) & 1);
            end
        end
        // Explicit first, second and too-late y acceptance boundaries.
        for (response = 0; response < 4; response = response + 1) begin
            tick(0,0,0);
            tick(1,0,1);
            tick(1,1,1);
            tick(1,0,1);
            tick(1,1,1); // y high here is before the window.
            tick(1,0,response == 1 || response == 3);
            tick(1,1,response == 2 || response == 3);
            for (k = 0; k < 12; k = k + 1) tick(1,k % 2,1);
            // Check synchronous reset while in a permanent outcome.
            tick(0,1,1);
            tick(1,0,0);
        end
        // Deterministic random reset interruption and terminal persistence.
        for (k = 0; k < 2000; k = k + 1) begin
            prng = {prng[30:0], prng[31] ^ prng[21] ^ prng[1] ^ prng[0]};
            tick(prng[7:3] != 0, prng[12], prng[20]);
        end
        $display("PASS: %0d cycle and between-edge comparisons", comparisons);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1,"Timeout");
    end
endmodule
