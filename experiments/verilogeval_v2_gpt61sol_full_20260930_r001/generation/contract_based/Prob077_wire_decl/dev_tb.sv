`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out, out_n;
    logic expected;
    integer index;
    integer pass_index;
    integer checks = 0;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out), .out_n(out_n));

    initial begin
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (integer step = 0; step < 16; step = step + 1) begin
                index = pass_index == 0 ? step : 15 - step;
                {a,b,c,d} = index[3:0];
                case (index)
                    3, 7, 11, 12, 13, 14, 15: expected = 1'b1;
                    default: expected = 1'b0;
                endcase
                #1;
                if (out !== expected || out_n !== ~expected)
                    $fatal(1, "FAIL inputs=%b out=%b out_n=%b expected=%b", {a,b,c,d}, out, out_n, expected);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d checks, all 16 binary inputs in both orders", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
