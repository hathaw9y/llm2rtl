`timescale 1ns/1ps
module dev_tb;
    logic [9:0] inputs;
    wire p1y, p2y;
    logic expected_p1y, expected_p2y;
    integer i;
    TopModule dut (
        .p1a(inputs[9]), .p1b(inputs[8]), .p1c(inputs[7]),
        .p1d(inputs[6]), .p1e(inputs[5]), .p1f(inputs[4]),
        .p2a(inputs[3]), .p2b(inputs[2]),
        .p2c(inputs[1]), .p2d(inputs[0]),
        .p1y(p1y), .p2y(p2y)
    );
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            inputs = 10'(i);
            expected_p1y = (inputs[9:7] == 3'b111) || (inputs[6:4] == 3'b111);
            expected_p2y = (inputs[3:2] == 2'b11) || (inputs[1:0] == 2'b11);
            #1;
            if (p1y !== expected_p1y || p2y !== expected_p2y)
                $fatal(1, "FAIL input=%b actual=%b%b expected=%b%b", inputs, p1y, p2y, expected_p1y, expected_p2y);
        end
        $display("PASS: all 1024 binary input combinations");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
