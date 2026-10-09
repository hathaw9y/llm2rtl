`timescale 1ns/1ps
module dev_tb;
    logic [3:0] in;
    wire [1:0] pos;
    integer vector;
    integer checks = 0;
    TopModule dut (.in(in), .pos(pos));

    function automatic [1:0] expected(input logic [3:0] bits);
        case (bits)
            4'd0: expected = 2'd0;
            4'd1: expected = 2'd0;
            4'd2: expected = 2'd1;
            4'd3: expected = 2'd0;
            4'd4: expected = 2'd2;
            4'd5: expected = 2'd0;
            4'd6: expected = 2'd1;
            4'd7: expected = 2'd0;
            4'd8: expected = 2'd3;
            4'd9: expected = 2'd0;
            4'd10: expected = 2'd1;
            4'd11: expected = 2'd0;
            4'd12: expected = 2'd2;
            4'd13: expected = 2'd0;
            4'd14: expected = 2'd1;
            4'd15: expected = 2'd0;
            default: expected = 2'bxx;
        endcase
    endfunction

    task automatic check(input logic [3:0] bits);
        in = bits;
        #1;
        if (pos !== expected(bits))
            $fatal(1, "in=%b expected=%d actual=%b", bits, expected(bits), pos);
        checks = checks + 1;
    endtask

    initial begin
        for (vector = 0; vector < 16; vector = vector + 1)
            check(vector[3:0]);
        for (vector = 15; vector >= 0; vector = vector - 1)
            check(vector[3:0]);
        $display("PASS exhaustive binary priority encoder: %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
