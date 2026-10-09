`timescale 1ns/1ps
module dev_tb;
    logic c, d;
    logic [3:0] mux_in;
    logic [3:0] expected;
    integer cd_index, ab_index, repetition;

    TopModule dut (.c(c), .d(d), .mux_in(mux_in));

    // Literal rows from the original K-map, reordered into binary ab order.
    function automatic logic kmap(input integer cd, input integer ab);
        begin
            case (cd)
                0: case (ab)
                    0: kmap = 0; 1: kmap = 0;
                    2: kmap = 1; 3: kmap = 0;
                    default: kmap = 1'bx;
                endcase
                1: case (ab)
                    0: kmap = 1; 1: kmap = 0;
                    2: kmap = 0; 3: kmap = 0;
                    default: kmap = 1'bx;
                endcase
                2: case (ab)
                    0: kmap = 1; 1: kmap = 0;
                    2: kmap = 1; 3: kmap = 0;
                    default: kmap = 1'bx;
                endcase
                3: case (ab)
                    0: kmap = 1; 1: kmap = 0;
                    2: kmap = 1; 3: kmap = 1;
                    default: kmap = 1'bx;
                endcase
                default: kmap = 1'bx;
            endcase
        end
    endfunction

    initial begin
        for (repetition = 0; repetition < 2; repetition = repetition + 1) begin
            for (cd_index = 0; cd_index < 4; cd_index = cd_index + 1) begin
                {c,d} = cd_index[1:0];
                #1;
                for (ab_index = 0; ab_index < 4; ab_index = ab_index + 1) begin
                    expected[ab_index] = kmap(cd_index, ab_index);
                    if (mux_in[ab_index] !== expected[ab_index])
                        $fatal(1, "K-map mismatch cd=%b%b ab=%0d expected=%b actual=%b",
                               c, d, ab_index, expected[ab_index], mux_in[ab_index]);
                end
                if (mux_in !== expected)
                    $fatal(1, "Vector mismatch expected=%b actual=%b", expected, mux_in);
            end
        end
        $display("PASS: all K-map entries and repeated combinational transitions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
