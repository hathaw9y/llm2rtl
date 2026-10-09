`timescale 1ns/1ps
module dev_tb;
    logic x3, x2, x1;
    logic f;
    localparam logic [7:0] EXPECTED = 8'b10101100;
    integer checks = 0;
    TopModule dut (.x3(x3), .x2(x2), .x1(x1), .f(f));

    task automatic check_input(input logic [2:0] value);
        {x3, x2, x1} = value;
        #1;
        if (f !== EXPECTED[value])
            $fatal(1, "FAIL inputs=%b expected=%b actual=%b", value, EXPECTED[value], f);
        checks = checks + 1;
    endtask

    initial begin
        for (integer i = 0; i < 8; i = i + 1)
            check_input(i[2:0]);
        for (integer source = 0; source < 8; source = source + 1)
            for (integer destination = 0; destination < 8; destination = destination + 1) begin
                check_input(source[2:0]);
                check_input(destination[2:0]);
            end
        $display("PASS: all 8 truth-table rows and 64 ordered transitions; %0d output checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
