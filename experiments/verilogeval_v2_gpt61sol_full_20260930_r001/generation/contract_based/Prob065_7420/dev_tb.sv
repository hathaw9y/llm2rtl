`timescale 1ns/1ps
module dev_tb;
    logic [7:0] inputs;
    wire p1y, p2y;
    logic expected_p1y, expected_p2y;
    integer vector_index;
    TopModule dut (
        .p1a(inputs[7]), .p1b(inputs[6]),
        .p1c(inputs[5]), .p1d(inputs[4]),
        .p2a(inputs[3]), .p2b(inputs[2]),
        .p2c(inputs[1]), .p2d(inputs[0]),
        .p1y(p1y), .p2y(p2y)
    );
    initial begin
        for (vector_index = 0; vector_index < 256; vector_index = vector_index + 1) begin
            inputs = 8'(vector_index);
            expected_p1y = (inputs[7:4] != 4'd15);
            expected_p2y = (inputs[3:0] != 4'd15);
            #1;
            if (p1y !== expected_p1y || p2y !== expected_p2y)
                $fatal(1, "FAIL vector=%0h actual=%b%b expected=%b%b", inputs, p1y, p2y, expected_p1y, expected_p2y);
        end
        $display("PASS: all 256 binary input combinations, both independent NAND outputs");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
