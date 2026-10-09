`timescale 1ns/1ps
module dev_tb;
    reg in1, in2, in3;
    wire out;
    reg expected;
    integer vector;
    TopModule dut (.in1(in1), .in2(in2), .in3(in3), .out(out));

    initial begin
        for (vector = 0; vector < 8; vector = vector + 1) begin
            {in1, in2, in3} = vector[2:0];
            // Independent truth table of the specified XNOR followed by XOR.
            case (vector)
                0: expected = 1'b1;
                1: expected = 1'b0;
                2: expected = 1'b0;
                3: expected = 1'b1;
                4: expected = 1'b0;
                5: expected = 1'b1;
                6: expected = 1'b1;
                7: expected = 1'b0;
            endcase
            #1;
            if (out !== expected)
                $fatal(1, "Inputs %b%b%b: expected %b, got %b", in1, in2, in3, expected, out);
        end
        $display("PASS: all eight input combinations");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
