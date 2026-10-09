`timescale 1ns/1ps
module dev_tb;
    logic [2:0] in;
    logic [1:0] out;
    integer source_value;
    integer target_value;
    integer checks;
    TopModule dut (.in(in), .out(out));

    function automatic logic [1:0] expected(input logic [2:0] value);
        case (value)
            3'b000: expected = 2'd0;
            3'b001: expected = 2'd1;
            3'b010: expected = 2'd1;
            3'b011: expected = 2'd2;
            3'b100: expected = 2'd1;
            3'b101: expected = 2'd2;
            3'b110: expected = 2'd2;
            3'b111: expected = 2'd3;
            default: expected = 2'bxx;
        endcase
    endfunction

    task automatic check_output;
        if (out !== expected(in))
            $fatal(1, "FAIL: in=%b out=%b expected=%b", in, out, expected(in));
        checks = checks + 1;
    endtask

    initial begin
        checks = 0;
        for (source_value = 0; source_value < 8; source_value = source_value + 1) begin
            for (target_value = 0; target_value < 8; target_value = target_value + 1) begin
                in = source_value[2:0];
                #1;
                check_output();
                in = target_value[2:0];
                #1;
                check_output();
            end
        end
        $display("PASS: all 8 input values and 64 ordered transitions; %0d output checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
