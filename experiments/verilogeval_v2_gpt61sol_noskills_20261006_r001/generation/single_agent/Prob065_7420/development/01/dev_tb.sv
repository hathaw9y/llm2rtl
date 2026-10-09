`timescale 1ns/1ps
module dev_tb;
    reg [7:0] inputs;
    wire p1y, p2y;
    reg expected1, expected2;
    integer i;
    TopModule dut (
        .p1a(inputs[0]), .p1b(inputs[1]),
        .p1c(inputs[2]), .p1d(inputs[3]),
        .p2a(inputs[4]), .p2b(inputs[5]),
        .p2c(inputs[6]), .p2d(inputs[7]),
        .p1y(p1y), .p2y(p2y)
    );
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            inputs = i;
            // Truth-table oracle: only the all-high combination gives low.
            expected1 = (i % 16 == 15) ? 1'b0 : 1'b1;
            expected2 = (i / 16 == 15) ? 1'b0 : 1'b1;
            #1;
            if (p1y !== expected1 || p2y !== expected2)
                $fatal(1, "NAND mismatch at inputs=%b: got %b,%b expected %b,%b",
                       inputs, p1y, p2y, expected1, expected2);
        end
        $display("PASS: all 256 input combinations verified");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
