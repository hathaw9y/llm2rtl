`timescale 1ns/1ps
module dev_tb;
    logic [7:0] inputs;
    wire p1y, p2y;
    TopModule dut (
        .p1a(inputs[0]), .p1b(inputs[1]),
        .p1c(inputs[2]), .p1d(inputs[3]),
        .p2a(inputs[4]), .p2b(inputs[5]),
        .p2c(inputs[6]), .p2d(inputs[7]),
        .p1y(p1y), .p2y(p2y)
    );
    initial begin
        for (int i = 0; i < 256; i++) begin
            inputs = 8'(i);
            #1;
            if (p1y !== (inputs[3:0] != 4'hf) ||
                p2y !== (inputs[7:4] != 4'hf))
                $fatal(1, "FAIL input=%h outputs=%b%b", inputs, p2y, p1y);
        end
        $display("PASS: all 256 binary input combinations");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
