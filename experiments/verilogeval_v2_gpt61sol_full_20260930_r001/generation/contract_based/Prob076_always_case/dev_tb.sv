module dev_tb;
    logic [2:0] sel;
    logic [3:0] data [0:5];
    wire [3:0] out;
    integer checks = 0;
    TopModule dut (.sel(sel), .data0(data[0]), .data1(data[1]),
                   .data2(data[2]), .data3(data[3]), .data4(data[4]),
                   .data5(data[5]), .out(out));
    task automatic check_output(input integer selector);
        logic [3:0] expected;
        begin
            #1;
            expected = 4'd0;
            if (selector < 6) expected = data[selector];
            if (out !== expected)
                $fatal(1, "FAIL sel=%0d expected=%h actual=%h", selector, expected, out);
            checks = checks + 1;
        end
    endtask
    initial begin
        for (integer s = 0; s < 8; s = s + 1) begin
            sel = s;
            for (integer lane = 0; lane < 6; lane = lane + 1) begin
                for (integer value = 0; value < 16; value = value + 1) begin
                    for (integer k = 0; k < 6; k = k + 1)
                        data[k] = (k * 3 + 1) % 16;
                    data[lane] = value;
                    check_output(s);
                end
            end
            for (integer k = 0; k < 6; k = k + 1) data[k] = 4'd0;
            check_output(s);
            for (integer k = 0; k < 6; k = k + 1) data[k] = 4'hf;
            check_output(s);
        end
        $display("PASS: %0d independent mux checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
