`timescale 1ns/1ps
module dev_tb;
    logic [2:0] sel;
    logic [3:0] data0, data1, data2, data3, data4, data5;
    wire [3:0] out;
    logic [3:0] expected;
    integer s, d, v, checks;
    TopModule dut (.*);
    initial begin
        checks = 0;
        for (s = 0; s < 8; s = s + 1) begin
            for (d = 0; d < 6; d = d + 1) begin
                for (v = 0; v < 16; v = v + 1) begin
                    sel = s;
                    data0 = 4'd1; data1 = 4'd3; data2 = 4'd5;
                    data3 = 4'd7; data4 = 4'd9; data5 = 4'd11;
                    case (d)
                        0: data0 = v;
                        1: data1 = v;
                        2: data2 = v;
                        3: data3 = v;
                        4: data4 = v;
                        5: data5 = v;
                    endcase
                    case (s)
                        0: expected = data0;
                        1: expected = data1;
                        2: expected = data2;
                        3: expected = data3;
                        4: expected = data4;
                        5: expected = data5;
                        default: expected = 4'd0;
                    endcase
                    #1;
                    if (out !== expected)
                        $fatal(1, "FAIL sel=%0d input=%0d value=%0d expected=%0h actual=%0h", s, d, v, expected, out);
                    checks = checks + 1;
                end
            end
        end
        $display("PASS: %0d mux checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL: development timeout");
    end
endmodule
