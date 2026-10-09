`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg ena = 0;
    reg [1:0] amount = 0;
    reg [63:0] data = 0;
    wire [63:0] q;
    reg [63:0] expected;
    reg [63:0] previous;
    reg [63:0] patterns [0:7];
    integer checks = 0;
    integer i, j, k;
    TopModule dut (.clk(clk), .load(load), .ena(ena),
                   .amount(amount), .data(data), .q(q));
    always #5 clk = ~clk;

    // Bit-by-bit oracle: vacated high bits replicate the old sign on right shifts.
    function automatic [63:0] shifted(input [63:0] value, input [1:0] mode);
        integer bit_index, distance;
        begin
            distance = mode[0] ? 8 : 1;
            for (bit_index = 0; bit_index < 64; bit_index = bit_index + 1) begin
                if (mode[1]) begin
                    if (bit_index + distance < 64)
                        shifted[bit_index] = value[bit_index + distance];
                    else
                        shifted[bit_index] = value[63];
                end else begin
                    if (bit_index >= distance)
                        shifted[bit_index] = value[bit_index - distance];
                    else
                        shifted[bit_index] = 1'b0;
                end
            end
        end
    endfunction

    task automatic step(input reg ld, input reg en, input reg [1:0] mode,
                        input reg [63:0] value);
        begin
            @(negedge clk);
            previous = expected;
            load = ld; ena = en; amount = mode; data = value;
            #1;
            if (q !== previous)
                $fatal(1, "Output changed before rising edge: q=%h previous=%h", q, previous);
            if (ld) expected = value;
            else if (en) expected = shifted(expected, mode);
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (q !== expected)
                $fatal(1, "Check %0d: load=%b ena=%b amount=%b q=%h expected=%h",
                       checks, ld, en, mode, q, expected);
        end
    endtask

    initial begin
        expected = {64{1'bx}};
        #1;
        if (q !== expected) $fatal(1, "Unexpected initial state");
        step(0, 0, 0, 0);
        patterns[0] = 64'h0000000000000000;
        patterns[1] = 64'hffffffffffffffff;
        patterns[2] = 64'h8000000000000000;
        patterns[3] = 64'h7fffffffffffffff;
        patterns[4] = 64'h0000000000000001;
        patterns[5] = 64'h0123456789abcdef;
        patterns[6] = 64'hfedcba9876543210;
        patterns[7] = 64'haa55aa55aa55aa55;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                step(1, 1, j, patterns[i]); // Load overrides enabled shift.
                step(0, 0, j, ~patterns[i]);
                for (k = 0; k < 65; k = k + 1)
                    step(0, 1, j, ~patterns[i]);
                step(0, 0, j, patterns[i]);
            end
        end
        step(1, 0, 3, 64'h8000000000000001);
        for (i = 0; i < 400; i = i + 1)
            step(($urandom_range(0, 9) == 0), $urandom_range(0, 1),
                 $urandom_range(0, 3), {$urandom, $urandom});
        $display("PASS %0d sequential checks", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Bounded timeout expired");
    end
endmodule
