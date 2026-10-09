`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out, out_n;
    logic expected;
    integer vector_index;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out), .out_n(out_n));

    initial begin
        for (vector_index = 0; vector_index < 16; vector_index = vector_index + 1) begin
            {a, b, c, d} = vector_index[3:0];
            // Truth-table entries where either AND gate has both inputs high.
            case (vector_index)
                3, 7, 11, 12, 13, 14, 15: expected = 1'b1;
                default: expected = 1'b0;
            endcase
            #1;
            if (out !== expected || out_n !== ~expected)
                $fatal(1, "Input %b%b%b%b: out=%b out_n=%b expected=%b/%b",
                       a, b, c, d, out, out_n, expected, ~expected);
        end
        $display("PASS: all 16 input combinations and both outputs checked");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
