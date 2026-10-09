module dev_tb;
    logic [99:0] in;
    wire [99:0] out_both, out_any, out_different;
    integer checks = 0;
    TopModule dut (.in(in), .out_both(out_both), .out_any(out_any), .out_different(out_different));

    task automatic check_vector(input logic [99:0] vector);
        logic expected_both, expected_any, expected_different;
        begin
            in = vector;
            #1;
            for (integer bit_index = 0; bit_index < 100; bit_index = bit_index + 1) begin
                if (bit_index == 99) expected_both = 1'b0;
                else expected_both = vector[bit_index] & vector[bit_index + 1];
                if (bit_index == 0) expected_any = 1'b0;
                else expected_any = vector[bit_index] | vector[bit_index - 1];
                if (bit_index == 99) expected_different = vector[99] ^ vector[0];
                else expected_different = vector[bit_index] ^ vector[bit_index + 1];
                if (out_both[bit_index] !== expected_both ||
                    out_any[bit_index] !== expected_any ||
                    out_different[bit_index] !== expected_different)
                    $fatal(1, "FAIL vector=%h bit=%0d", vector, bit_index);
            end
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector('0);
        check_vector('1);
        check_vector({50{2'b01}});
        check_vector({50{2'b10}});
        for (integer position = 0; position < 100; position = position + 1) begin
            check_vector(100'b1 << position);
            check_vector(~(100'b1 << position));
        end
        for (integer trial = 0; trial < 1000; trial = trial + 1)
            check_vector({$urandom, $urandom, $urandom, $urandom});
        $display("PASS: %0d vectors, all 300 output bits checked per vector", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
