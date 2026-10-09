`timescale 1ns/1ps
module dev_tb;
    reg [2:0] sel;
    reg [3:0] data [0:5];
    wire [3:0] out;
    reg [3:0] expected;
    integer s, lane, value, i;
    integer checks = 0;

    TopModule dut (.sel(sel), .data0(data[0]), .data1(data[1]),
        .data2(data[2]), .data3(data[3]), .data4(data[4]),
        .data5(data[5]), .out(out));

    task check_output;
        begin
            #1;
            if (sel < 6) expected = data[sel];
            else expected = 4'd0;
            if (out !== expected)
                $fatal(1, "sel=%0d expected=%h observed=%h", sel, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        sel = 0;
        for (i = 0; i < 6; i = i + 1) data[i] = i + 1;
        for (s = 0; s < 8; s = s + 1) begin
            sel = s;
            check_output;
        end
        // Sweep every data value on each lane with each selector fixed.
        for (s = 0; s < 8; s = s + 1) begin
            sel = s;
            for (lane = 0; lane < 6; lane = lane + 1) begin
                for (i = 0; i < 6; i = i + 1) data[i] = 15 - i;
                for (value = 0; value < 16; value = value + 1) begin
                    data[lane] = value;
                    check_output;
                end
            end
        end
        // Selected data retains all four-state bits without transformation.
        for (s = 0; s < 6; s = s + 1) begin
            sel = s;
            data[s] = 4'bx01z;
            check_output;
        end
        sel = 6;
        check_output;
        sel = 7;
        check_output;
        $display("PASS: %0d multiplexer checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Development test timeout");
    end
endmodule
