`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire [2:0] pos;
    integer checks = 0;
    TopModule dut (.in(in), .pos(pos));

    function automatic logic [2:0] expected_pos(input logic [7:0] value);
        integer bit_index;
        logic found;
        begin
            expected_pos = 3'd0;
            found = 1'b0;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (!found && value[bit_index] == 1'b1) begin
                    expected_pos = bit_index[2:0];
                    found = 1'b1;
                end
            end
        end
    endfunction

    task automatic check_value(input logic [7:0] value);
        logic [2:0] expected;
        begin
            in = value;
            expected = expected_pos(value);
            #1;
            if (pos !== expected)
                $fatal(1, "in=%b expected=%d actual=%d", value, expected, pos);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_value(8'b10010000);
        check_value(8'h00);
        check_value(8'h80);
        check_value(8'hff);
        for (integer value = 0; value < 256; value = value + 1)
            check_value(value[7:0]);
        for (integer value = 255; value >= 0; value = value - 1)
            check_value(value[7:0]);
        $display("PASS priority encoder: %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
