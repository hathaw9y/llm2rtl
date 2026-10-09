`timescale 1ns/1ps
module dev_tb;
    reg [2:0] sel;
    reg [3:0] data0, data1, data2, data3, data4, data5;
    wire [3:0] out;
    reg [3:0] inputs [0:5];
    reg [3:0] expected;
    integer s, d, v, round, i;
    integer checks = 0;
    TopModule dut (.sel(sel), .data0(data0), .data1(data1),
                   .data2(data2), .data3(data3), .data4(data4),
                   .data5(data5), .out(out));

    task apply_and_check;
        begin
            data0 = inputs[0]; data1 = inputs[1]; data2 = inputs[2];
            data3 = inputs[3]; data4 = inputs[4]; data5 = inputs[5];
            if (s < 6) expected = inputs[s];
            else expected = 4'd0;
            sel = s;
            #1;
            if (out !== expected)
                $fatal(1, "sel=%0d expected=%h got=%h", s, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Exhaust each input's sixteen values with every selector, including
        // invalid selectors, while the other inputs have distinct values.
        for (d = 0; d < 6; d = d + 1) begin
            for (v = 0; v < 16; v = v + 1) begin
                for (i = 0; i < 6; i = i + 1) inputs[i] = i + 8;
                inputs[d] = v;
                for (s = 0; s < 8; s = s + 1) apply_and_check;
            end
        end
        // Change data with selector held fixed to exercise combinational updates.
        for (s = 0; s < 8; s = s + 1) begin
            for (round = 0; round < 32; round = round + 1) begin
                for (i = 0; i < 6; i = i + 1)
                    inputs[i] = (round * (i + 1) + i) % 16;
                apply_and_check;
            end
        end
        $display("PASS: %0d multiplexer checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
