`timescale 1ns/1ps
module dev_tb;
    logic clk, x;
    logic [2:0] y;
    wire Y0, z;
    logic [2:0] expected_next;
    logic expected_z;
    integer phase, state_index, input_index;
    integer checks = 0;
    TopModule dut (.clk(clk), .x(x), .y(y), .Y0(Y0), .z(z));

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end

    initial begin
        clk = 1'b0;
        x = 1'b0;
        y = 3'b000;
        for (phase = 0; phase < 4; phase = phase + 1) begin
            clk = phase % 2;
            for (state_index = 0; state_index < 5; state_index = state_index + 1) begin
                for (input_index = 0; input_index < 2; input_index = input_index + 1) begin
                    y = state_index;
                    x = input_index;
                    // Oracle records the full next-state entries in the original table.
                    case (state_index)
                        0: begin
                            if (input_index == 0) expected_next = 3'b000;
                            else expected_next = 3'b001;
                            expected_z = 1'b0;
                        end
                        1: begin
                            if (input_index == 0) expected_next = 3'b001;
                            else expected_next = 3'b100;
                            expected_z = 1'b0;
                        end
                        2: begin
                            if (input_index == 0) expected_next = 3'b010;
                            else expected_next = 3'b001;
                            expected_z = 1'b0;
                        end
                        3: begin
                            if (input_index == 0) expected_next = 3'b001;
                            else expected_next = 3'b010;
                            expected_z = 1'b1;
                        end
                        4: begin
                            if (input_index == 0) expected_next = 3'b011;
                            else expected_next = 3'b100;
                            expected_z = 1'b1;
                        end
                    endcase
                    #2;
                    if (Y0 !== expected_next[0] || z !== expected_z)
                        $fatal(1, "Mismatch clk=%b y=%b x=%b got Y0=%b z=%b expected Y0=%b z=%b", clk, y, x, Y0, z, expected_next[0], expected_z);
                    checks = checks + 1;
                end
            end
        end
        $display("PASS checked %0d combinational table cases", checks);
        $finish;
    end
endmodule
