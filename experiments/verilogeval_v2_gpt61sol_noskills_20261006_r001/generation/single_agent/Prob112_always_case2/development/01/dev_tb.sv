`timescale 1ns/1ps
module dev_tb;
    reg [3:0] in;
    wire [1:0] pos;
    integer vector;
    reg [1:0] expected;
    TopModule dut (.in(in), .pos(pos));

    // Truth table from the specification: lowest numbered set bit wins.
    function automatic [1:0] oracle(input [3:0] value);
        case (value)
            4'd0, 4'd1, 4'd3, 4'd5, 4'd7,
            4'd9, 4'd11, 4'd13, 4'd15: oracle = 2'd0;
            4'd2, 4'd6, 4'd10, 4'd14: oracle = 2'd1;
            4'd4, 4'd12: oracle = 2'd2;
            4'd8: oracle = 2'd3;
            default: oracle = 2'bxx;
        endcase
    endfunction

    initial begin
        for (vector = 0; vector < 16; vector = vector + 1) begin
            in = vector[3:0];
            expected = oracle(in);
            #1;
            if (pos !== expected)
                $fatal(1, "in=%b expected=%d actual=%b", in, expected, pos);
        end
        // Reverse traversal checks combinational updates back to zero.
        for (vector = 15; vector >= 0; vector = vector - 1) begin
            in = vector[3:0];
            expected = oracle(in);
            #1;
            if (pos !== expected)
                $fatal(1, "reverse in=%b expected=%d actual=%b", in, expected, pos);
        end
        $display("PASS: all 16 inputs checked in both traversal directions");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
