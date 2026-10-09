`timescale 1ns/1ps
module dev_tb;
    reg clk, x;
    reg [2:0] y;
    wire Y0, z;
    integer checks = 0;
    integer c, s, v;
    TopModule dut (.clk(clk), .x(x), .y(y), .Y0(Y0), .z(z));

    // Each pair is {Y[0], z}, transcribed from the original table.
    task check_row(input [2:0] state_value, input x_value,
                   input [1:0] expected);
        begin
            y = state_value;
            x = x_value;
            #1;
            if ({Y0, z} !== expected)
                $fatal(1, "state=%b x=%b clk=%b expected=%b actual=%b",
                       y, x, clk, expected, {Y0, z});
            checks = checks + 1;
        end
    endtask

    task table_check(input integer row, input integer bit_value);
        begin
            case (row)
                0: if (bit_value == 0) check_row(3'b000, 0, 2'b00);
                   else check_row(3'b000, 1, 2'b10);
                1: if (bit_value == 0) check_row(3'b001, 0, 2'b10);
                   else check_row(3'b001, 1, 2'b00);
                2: if (bit_value == 0) check_row(3'b010, 0, 2'b00);
                   else check_row(3'b010, 1, 2'b10);
                3: if (bit_value == 0) check_row(3'b011, 0, 2'b11);
                   else check_row(3'b011, 1, 2'b01);
                4: if (bit_value == 0) check_row(3'b100, 0, 2'b11);
                   else check_row(3'b100, 1, 2'b01);
            endcase
        end
    endtask

    initial begin
        clk = 0;
        for (c = 0; c < 2; c = c + 1) begin
            clk = c;
            for (s = 0; s < 5; s = s + 1)
                for (v = 0; v < 2; v = v + 1)
                    table_check(s, v);
        end
        // Reverse order with falling/rising clock transitions for each row.
        for (s = 4; s >= 0; s = s - 1) begin
            clk = 0;
            table_check(s, 1);
            clk = 1;
            table_check(s, 1);
            table_check(s, 0);
            clk = 0;
            table_check(s, 0);
        end
        $display("PASS all %0d table and clock-independence checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
