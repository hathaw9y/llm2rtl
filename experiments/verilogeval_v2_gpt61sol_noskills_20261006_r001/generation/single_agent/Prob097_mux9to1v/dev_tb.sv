`timescale 1ns/1ps
module dev_tb;
    reg [15:0] inputs [0:8];
    reg [3:0] sel;
    wire [15:0] out;
    integer pattern, choice, lane;
    integer checks = 0;
    reg [15:0] expected;
    TopModule dut (
        .a(inputs[0]), .b(inputs[1]), .c(inputs[2]),
        .d(inputs[3]), .e(inputs[4]), .f(inputs[5]),
        .g(inputs[6]), .h(inputs[7]), .i(inputs[8]),
        .sel(sel), .out(out)
    );
    task check_output;
        begin
            #1;
            if (sel < 9) expected = inputs[sel];
            else expected = 16'hffff;
            if (out !== expected)
                $fatal(1, "sel=%0d expected=%h got=%h", sel, expected, out);
            checks = checks + 1;
        end
    endtask
    initial begin
        for (pattern = 0; pattern < 100; pattern = pattern + 1) begin
            for (lane = 0; lane < 9; lane = lane + 1) begin
                case (pattern)
                    0: inputs[lane] = 16'h0000;
                    1: inputs[lane] = 16'hffff;
                    2: inputs[lane] = 16'h0001 << lane;
                    3: inputs[lane] = 16'h8000 >> lane;
                    4: inputs[lane] = (lane % 2) ? 16'haaaa : 16'h5555;
                    default: inputs[lane] = $random;
                endcase
            end
            for (choice = 0; choice < 16; choice = choice + 1) begin
                sel = choice;
                check_output;
                // Also exercise data changes with selection held constant.
                for (lane = 0; lane < 9; lane = lane + 1)
                    inputs[lane] = ~inputs[lane];
                check_output;
            end
        end
        $display("PASS: %0d mux checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
