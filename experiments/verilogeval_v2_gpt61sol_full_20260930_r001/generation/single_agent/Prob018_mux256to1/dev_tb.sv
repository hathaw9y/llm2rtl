`timescale 1ns/1ps
module dev_tb;
    logic [255:0] in;
    logic [7:0] sel;
    logic out;
    integer checks = 0;
    TopModule dut (.in(in), .sel(sel), .out(out));

    task automatic check(input logic expected);
        #1;
        if (out !== expected)
            $fatal(1, "FAIL sel=%0d expected=%b actual=%b", sel, expected, out);
        checks = checks + 1;
    endtask

    initial begin
        for (integer hot = 0; hot < 256; hot = hot + 1) begin
            in = '0;
            in[hot] = 1'b1;
            for (integer idx = 0; idx < 256; idx = idx + 1) begin
                sel = 8'(idx);
                check(idx == hot);
            end
            in = ~in;
            for (integer idx = 0; idx < 256; idx = idx + 1) begin
                sel = 8'(idx);
                check(idx != hot);
            end
        end
        $display("PASS: %0d exhaustive one-hot/one-cold selection checks", checks);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "FAIL simulation timeout");
    end
endmodule
