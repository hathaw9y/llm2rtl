`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire out, out_n;
    integer i;
    reg expected;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out), .out_n(out_n));

    task check;
        input [3:0] stimulus;
        input expected_out;
        input expected_inverse;
        begin
            {a,b,c,d} = stimulus;
            #1;
            if (out !== expected_out || out_n !== expected_inverse)
                $fatal(1, "Inputs %b: got %b/%b expected %b/%b",
                       stimulus, out, out_n, expected_out, expected_inverse);
        end
    endtask

    initial begin
        // Truth table derived from the original two-AND/one-OR circuit.
        for (i = 0; i < 16; i = i + 1) begin
            case (i)
                3, 7, 11, 12, 13, 14, 15: expected = 1'b1;
                default: expected = 1'b0;
            endcase
            check(i[3:0], expected, !expected);
        end
        // Gate masking and four-state propagation, with explicit expected values.
        check(4'bx000, 1'b0, 1'b1);
        check(4'b0z00, 1'b0, 1'b1);
        check(4'b00x0, 1'b0, 1'b1);
        check(4'b000z, 1'b0, 1'b1);
        check(4'bx100, 1'bx, 1'bx);
        check(4'b001z, 1'bx, 1'bx);
        check(4'bxx11, 1'b1, 1'b0);
        check(4'b11zz, 1'b1, 1'b0);
        check(4'bxxxx, 1'bx, 1'bx);
        $display("PASS: all 16 binary combinations and 9 four-state gate cases");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
