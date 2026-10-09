`timescale 1ns/1ps
module dev_tb;
    reg [254:0] in;
    wire [7:0] out;
    reg [254:0] pattern;
    integer i, j, k;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    // Count by clearing one set bit at a time, independently of DUT's sum.
    function automatic integer population(input reg [254:0] value);
        reg [254:0] remaining;
        begin
            remaining = value;
            population = 0;
            while (remaining != 255'd0) begin
                remaining = remaining & (remaining - 255'd1);
                population = population + 1;
            end
        end
    endfunction

    task automatic check(input reg [254:0] value);
        integer expected;
        begin
            expected = population(value);
            in = value;
            #1;
            if (out !== expected[7:0])
                $fatal(1, "Mismatch input=%h expected=%0d actual=%0d", value, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(255'd0);
        check({255{1'b1}});
        for (i = 0; i < 255; i = i + 1) begin
            pattern = 255'd0;
            pattern[i] = 1'b1;
            check(pattern);
            check(~pattern);
        end
        // Exercise each output count, including both numerical boundaries.
        pattern = 255'd0;
        check(pattern);
        for (i = 0; i < 255; i = i + 1) begin
            pattern[i] = 1'b1;
            check(pattern);
        end
        for (i = 0; i < 255; i = i + 1)
            pattern[i] = (i % 2 == 0);
        check(pattern);
        check(~pattern);
        for (j = 0; j < 1000; j = j + 1) begin
            for (k = 0; k < 255; k = k + 1)
                pattern[k] = $urandom_range(0, 1);
            check(pattern);
        end
        check(255'd0);
        $display("PASS population count: %0d checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
