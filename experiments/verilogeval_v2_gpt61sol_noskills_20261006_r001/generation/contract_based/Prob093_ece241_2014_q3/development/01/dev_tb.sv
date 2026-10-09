`timescale 1ns/1ps
module dev_tb;
    reg c, d;
    wire [3:0] mux_in;
    reg [3:0] expected;
    reg [1:0] ab;
    reg expected_selected;
    integer row, col, repetition;
    integer checks = 0;

    TopModule dut (.c(c), .d(d), .mux_in(mux_in));

    initial begin
        // Replay all original Gray-ordered rows repeatedly to cover transitions.
        for (repetition = 0; repetition < 3; repetition = repetition + 1) begin
            for (row = 0; row < 4; row = row + 1) begin
                case (row)
                    0: begin c = 0; d = 0; expected = 4'b0100; end
                    1: begin c = 0; d = 1; expected = 4'b0001; end
                    2: begin c = 1; d = 1; expected = 4'b1101; end
                    3: begin c = 1; d = 0; expected = 4'b0101; end
                endcase
                #1;
                if (mux_in !== expected)
                    $fatal(1, "cd=%b%b expected=%b observed=%b", c, d, expected, mux_in);
                // Each row's entries are listed in original column order 00,01,11,10.
                for (col = 0; col < 4; col = col + 1) begin
                    case (col)
                        0: ab = 2'b00;
                        1: ab = 2'b01;
                        2: ab = 2'b11;
                        3: ab = 2'b10;
                    endcase
                    case (row)
                        0: case (col)
                            0,1,2: expected_selected = 0;
                            3: expected_selected = 1;
                        endcase
                        1: case (col)
                            0: expected_selected = 1;
                            1,2,3: expected_selected = 0;
                        endcase
                        2: case (col)
                            0,2,3: expected_selected = 1;
                            1: expected_selected = 0;
                        endcase
                        3: case (col)
                            0,3: expected_selected = 1;
                            1,2: expected_selected = 0;
                        endcase
                    endcase
                    if (mux_in[ab] !== expected_selected)
                        $fatal(1, "K-map mismatch cd=%b%b ab=%b", c, d, ab);
                    checks = checks + 1;
                end
            end
        end
        $display("PASS: %0d original K-map entry checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
