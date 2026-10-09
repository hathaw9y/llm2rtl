module dev_tb;
    logic [2:0] a, b;
    wire [2:0] out_or_bitwise;
    wire out_or_logical;
    wire [5:0] out_not;
    logic [2:0] expected_or;
    logic [5:0] expected_not;
    logic expected_logical;
    integer ai, bi, bit_index;
    TopModule dut (.*);
    initial begin
        for (ai = 0; ai < 8; ai = ai + 1) begin
            for (bi = 0; bi < 8; bi = bi + 1) begin
                a = ai[2:0];
                b = bi[2:0];
                for (bit_index = 0; bit_index < 3; bit_index = bit_index + 1) begin
                    expected_or[bit_index] = a[bit_index] | b[bit_index];
                    expected_not[bit_index] = !a[bit_index];
                    expected_not[bit_index + 3] = !b[bit_index];
                end
                expected_logical = (ai != 0) || (bi != 0);
                #1;
                if (out_or_bitwise !== expected_or ||
                    out_or_logical !== expected_logical ||
                    out_not !== expected_not)
                    $fatal(1, "FAIL a=%b b=%b", a, b);
            end
        end
        $display("PASS: all 64 binary input pairs");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
