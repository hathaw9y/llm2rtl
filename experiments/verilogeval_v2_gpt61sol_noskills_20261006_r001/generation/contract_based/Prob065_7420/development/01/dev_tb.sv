`timescale 1ns/1ps
module dev_tb;
    reg [7:0] stimulus;
    wire p1y, p2y;
    reg expected1, expected2;
    integer vector_index;
    TopModule dut (
        .p1a(stimulus[7]), .p1b(stimulus[6]),
        .p1c(stimulus[5]), .p1d(stimulus[4]),
        .p2a(stimulus[3]), .p2b(stimulus[2]),
        .p2c(stimulus[1]), .p2d(stimulus[0]),
        .p1y(p1y), .p2y(p2y)
    );
    initial begin
        for (vector_index = 0; vector_index < 256; vector_index = vector_index + 1) begin
            stimulus = vector_index;
            expected1 = (stimulus[7:4] == 4'b1111) ? 1'b0 : 1'b1;
            expected2 = (stimulus[3:0] == 4'b1111) ? 1'b0 : 1'b1;
            #1;
            if (p1y !== expected1 || p2y !== expected2)
                $fatal(1, "NAND mismatch inputs=%b actual=%b%b expected=%b%b",
                       stimulus, p1y, p2y, expected1, expected2);
        end
        $display("PASS: all 256 binary input combinations checked");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
