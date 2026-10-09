`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic x;
    logic [2:0] y;
    wire Y0, z;
    logic [2:0] expected_next [0:4][0:1];
    logic expected_z [0:4];
    integer state_index, input_index, repetition;
    integer checks = 0;
    TopModule dut (.clk(clk), .x(x), .y(y), .Y0(Y0), .z(z));

    task automatic check_output(input integer s, input integer b);
        begin
            if (Y0 !== expected_next[s][b][0] || z !== expected_z[s])
                $fatal(1, "Mismatch y=%b x=%b clk=%b: got Y0=%b z=%b expected Y0=%b z=%b",
                       y, x, clk, Y0, z, expected_next[s][b][0], expected_z[s]);
            checks = checks + 1;
        end
    endtask

    initial begin
        expected_next[0][0] = 3'b000; expected_next[0][1] = 3'b001;
        expected_next[1][0] = 3'b001; expected_next[1][1] = 3'b100;
        expected_next[2][0] = 3'b010; expected_next[2][1] = 3'b001;
        expected_next[3][0] = 3'b001; expected_next[3][1] = 3'b010;
        expected_next[4][0] = 3'b011; expected_next[4][1] = 3'b100;
        expected_z[0] = 0; expected_z[1] = 0; expected_z[2] = 0;
        expected_z[3] = 1; expected_z[4] = 1;
        // Changes occur with clock held, proving absence of edge latency.
        // Repeat in both state traversal directions and both clock phases.
        for (repetition = 0; repetition < 4; repetition = repetition + 1) begin
            for (state_index = 0; state_index < 5; state_index = state_index + 1) begin
                for (input_index = 0; input_index < 2; input_index = input_index + 1) begin
                    if (repetition % 2 == 0) y = state_index;
                    else y = 4 - state_index;
                    x = input_index;
                    #1;
                    check_output(y, input_index);
                    clk = ~clk;
                    #1;
                    check_output(y, input_index);
                end
            end
        end
        $display("PASS: %0d checks covering all specified rows and clock independence", checks);
        $finish;
    end
    initial begin
        #500;
        $fatal(1, "Timeout");
    end
endmodule
