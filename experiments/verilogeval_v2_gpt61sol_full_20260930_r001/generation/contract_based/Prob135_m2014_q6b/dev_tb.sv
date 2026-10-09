module dev_tb;
    logic [2:0] y;
    logic w;
    wire Y1;
    logic [2:0] destination [0:11];
    logic expected;
    integer pass_index, index, state_index, input_index;
    integer checks = 0;
    TopModule dut (.y(y), .w(w), .Y1(Y1));
    initial begin
        destination[0] = 3'b001; destination[1] = 3'b000;
        destination[2] = 3'b010; destination[3] = 3'b011;
        destination[4] = 3'b100; destination[5] = 3'b011;
        destination[6] = 3'b101; destination[7] = 3'b000;
        destination[8] = 3'b100; destination[9] = 3'b011;
        destination[10] = 3'b010; destination[11] = 3'b011;
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (index = 0; index < 16; index = index + 1) begin
                state_index = pass_index == 0 ? index / 2 : 7 - index / 2;
                input_index = pass_index == 0 ? index % 2 : 1 - index % 2;
                y = 3'(state_index);
                w = 1'(input_index);
                if (state_index < 6)
                    expected = destination[2*state_index + input_index][1];
                else
                    expected = 1'b0;
                #1;
                if (Y1 !== expected)
                    $fatal(1, "FAIL y=%b w=%b expected=%b actual=%b", y, w, expected, Y1);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d comparisons; all 12 legal combinations and implementation defaults, forward and reverse", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
