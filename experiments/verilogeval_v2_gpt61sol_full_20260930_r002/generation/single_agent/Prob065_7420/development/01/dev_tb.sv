`timescale 1ns/1ps
module dev_tb;
    logic [3:0] gate1, gate2;
    wire p1y, p2y;
    logic expected1, expected2;
    integer a, b;

    TopModule dut (
        .p1a(gate1[3]), .p1b(gate1[2]),
        .p1c(gate1[1]), .p1d(gate1[0]),
        .p2a(gate2[3]), .p2b(gate2[2]),
        .p2c(gate2[1]), .p2d(gate2[0]),
        .p1y(p1y), .p2y(p2y)
    );

    initial begin
        for (a = 0; a < 16; a = a + 1) begin
            for (b = 0; b < 16; b = b + 1) begin
                gate1 = a[3:0];
                gate2 = b[3:0];
                // NAND truth table: only the all-high row outputs zero.
                expected1 = (a == 15) ? 1'b0 : 1'b1;
                expected2 = (b == 15) ? 1'b0 : 1'b1;
                #1;
                if (p1y !== expected1 || p2y !== expected2)
                    $fatal(1, "NAND mismatch: inputs %b/%b outputs %b/%b expected %b/%b",
                           gate1, gate2, p1y, p2y, expected1, expected2);
            end
        end
        $display("PASS: all 256 input combinations checked");
        $finish;
    end

    initial begin
        #300;
        $fatal(1, "Timeout");
    end
endmodule
