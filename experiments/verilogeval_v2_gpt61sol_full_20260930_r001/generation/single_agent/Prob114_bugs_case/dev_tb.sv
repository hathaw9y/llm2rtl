module dev_tb;
    logic [7:0] code;
    wire [3:0] out;
    wire valid;
    logic [7:0] scancodes [0:9];
    logic [3:0] expected_out;
    logic expected_valid;
    integer i, j;
    TopModule dut (.code(code), .out(out), .valid(valid));
    initial begin
        scancodes[0] = 8'h45;
        scancodes[1] = 8'h16;
        scancodes[2] = 8'h1e;
        scancodes[3] = 8'h26;
        scancodes[4] = 8'h25;
        scancodes[5] = 8'h2e;
        scancodes[6] = 8'h36;
        scancodes[7] = 8'h3d;
        scancodes[8] = 8'h3e;
        scancodes[9] = 8'h46;
        for (i = 0; i < 256; i = i + 1) begin
            code = i[7:0];
            expected_out = 4'd0;
            expected_valid = 1'b0;
            for (j = 0; j < 10; j = j + 1) begin
                if (code == scancodes[j]) begin
                    expected_out = j[3:0];
                    expected_valid = 1'b1;
                end
            end
            #1;
            if ({valid, out} !== {expected_valid, expected_out})
                $fatal(1, "FAIL code=%h actual=%b/%h expected=%b/%h", code, valid, out, expected_valid, expected_out);
        end
        $display("PASS: all 256 binary scancodes checked");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
