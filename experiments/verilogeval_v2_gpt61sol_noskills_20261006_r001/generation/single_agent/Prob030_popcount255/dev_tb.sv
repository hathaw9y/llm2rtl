`timescale 1ns/1ps
module dev_tb;
    reg [254:0] in;
    wire [7:0] out;
    integer n, j, trial;
    integer checks = 0;
    reg [254:0] vector;
    TopModule dut(.in(in), .out(out));

    // Independent oracle: clear one set bit per iteration.
    function automatic integer population(input reg [254:0] value);
        reg [254:0] remaining;
        integer count;
        begin
            remaining = value;
            count = 0;
            while (remaining != 255'd0) begin
                remaining = remaining & (remaining - 255'd1);
                count = count + 1;
            end
            population = count;
        end
    endfunction

    task automatic check(input reg [254:0] value, input integer expected);
        begin
            in = value;
            #1;
            if (out !== expected[7:0])
                $fatal(1, "count mismatch: input=%h expected=%0d got=%0d", value, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(255'd0, 0);
        check({255{1'b1}}, 255);
        for (j = 0; j < 255; j = j + 1) begin
            vector = 255'd1 << j;
            check(vector, 1);
            check(~vector, 254);
        end
        // Every possible population, including both endpoints.
        vector = 0;
        for (n = 0; n <= 255; n = n + 1) begin
            check(vector, n);
            if (n < 255) vector[n] = 1'b1;
        end
        for (j = 0; j < 255; j = j + 1)
            vector[j] = (j % 2 == 0);
        check(vector, 128);
        check(~vector, 127);
        for (trial = 0; trial < 1000; trial = trial + 1) begin
            for (j = 0; j < 255; j = j + 1)
                vector[j] = $random;
            check(vector, population(vector));
        end
        $display("PASS: %0d population-count checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
