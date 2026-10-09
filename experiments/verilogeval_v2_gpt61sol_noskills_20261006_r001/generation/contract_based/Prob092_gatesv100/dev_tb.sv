`timescale 1ns/1ps
module dev_tb;
    reg [99:0] in;
    wire [99:0] out_both, out_any, out_different;
    reg [99:0] stimulus;
    reg [31:0] rng;
    integer i, j, pair_value, trial;
    integer checks = 0;

    TopModule dut (.in(in), .out_both(out_both), .out_any(out_any),
                   .out_different(out_different));

    task check_vector(input reg [99:0] value);
        reg [99:0] expected_both, expected_any, expected_different;
        integer bit_index;
        begin
            in = value;
            for (bit_index = 0; bit_index < 100; bit_index = bit_index + 1) begin
                if (bit_index == 99)
                    expected_both[bit_index] = 1'b0;
                else
                    expected_both[bit_index] = value[bit_index] & value[bit_index+1];
                if (bit_index == 0)
                    expected_any[bit_index] = 1'b0;
                else
                    expected_any[bit_index] = value[bit_index] | value[bit_index-1];
                if (bit_index == 99)
                    expected_different[bit_index] = value[99] ^ value[0];
                else
                    expected_different[bit_index] = value[bit_index] ^ value[bit_index+1];
            end
            #1;
            if (out_both !== expected_both)
                $fatal(1, "out_both mismatch check=%0d input=%h actual=%h expected=%h",
                       checks, value, out_both, expected_both);
            if (out_any !== expected_any)
                $fatal(1, "out_any mismatch check=%0d input=%h actual=%h expected=%h",
                       checks, value, out_any, expected_any);
            if (out_different !== expected_different)
                $fatal(1, "out_different mismatch check=%0d input=%h actual=%h expected=%h",
                       checks, value, out_different, expected_different);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector(100'b0);
        check_vector({100{1'b1}});
        for (i = 0; i < 100; i = i + 1)
            stimulus[i] = i % 2;
        check_vector(stimulus);
        check_vector(~stimulus);
        for (i = 0; i < 100; i = i + 1) begin
            stimulus = 0;
            stimulus[i] = 1;
            check_vector(stimulus);
            check_vector(~stimulus);
        end
        // Exhaust each adjacent pair, including the wrap pair 99/0.
        for (i = 0; i < 100; i = i + 1) begin
            for (pair_value = 0; pair_value < 4; pair_value = pair_value + 1) begin
                stimulus = 0;
                stimulus[i] = pair_value[0];
                stimulus[(i+1)%100] = pair_value[1];
                check_vector(stimulus);
                check_vector(~stimulus);
            end
        end
        rng = 32'h357ab129;
        for (trial = 0; trial < 500; trial = trial + 1) begin
            for (j = 0; j < 100; j = j + 1) begin
                rng = rng ^ (rng << 13);
                rng = rng ^ (rng >> 17);
                rng = rng ^ (rng << 5);
                stimulus[j] = rng[0];
            end
            check_vector(stimulus);
        end
        // Supplemental ordinary gate propagation checks; X/Z are unspecified.
        check_vector({100{1'bx}});
        check_vector({100{1'bz}});
        stimulus = 0;
        stimulus[99] = 1'bx;
        stimulus[0] = 1'bz;
        check_vector(stimulus);
        $display("PASS checked %0d input vectors", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Bounded timeout");
    end
endmodule
