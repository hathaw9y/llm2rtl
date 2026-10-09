`timescale 1ns/1ps
module dev_tb;
    logic clk, x;
    logic [2:0] y;
    wire Y0, z;
    logic [2:0] expected_next;
    logic expected_z;
    integer s, b, c;
    integer checks = 0;
    TopModule dut (.clk(clk), .x(x), .y(y), .Y0(Y0), .z(z));
    initial begin
        for (s = 0; s < 8; s = s + 1) begin
            for (b = 0; b < 2; b = b + 1) begin
                for (c = 0; c < 2; c = c + 1) begin
                    y = s[2:0]; x = b[0]; clk = c[0];
                    expected_next = 3'b000;
                    expected_z = 1'b0;
                    case (s)
                        0: expected_next = b ? 3'b001 : 3'b000;
                        1: expected_next = b ? 3'b100 : 3'b001;
                        2: expected_next = b ? 3'b001 : 3'b010;
                        3: begin
                            expected_next = b ? 3'b010 : 3'b001;
                            expected_z = 1'b1;
                        end
                        4: begin
                            expected_next = b ? 3'b100 : 3'b011;
                            expected_z = 1'b1;
                        end
                    endcase
                    #1;
                    if (Y0 !== expected_next[0] || z !== expected_z)
                        $fatal(1, "FAIL y=%b x=%b clk=%b Y0=%b z=%b", y, x, clk, Y0, z);
                    checks = checks + 1;
                end
            end
        end
        $display("PASS: %0d combinations checked", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL timeout");
    end
endmodule
