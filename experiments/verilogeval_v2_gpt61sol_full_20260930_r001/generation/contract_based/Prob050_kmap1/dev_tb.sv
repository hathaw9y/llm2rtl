`timescale 1ns/1ps
module dev_tb;
    logic a, b, c;
    wire out;
    logic [7:0] expected_table = 8'b11111110;
    integer index;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .out(out));
    task automatic check_input(input integer value);
        begin
            {a, b, c} = value[2:0];
            #1;
            if (out !== expected_table[value])
                $fatal(1, "FAIL abc=%03b expected=%b actual=%b", {a,b,c}, expected_table[value], out);
            checks = checks + 1;
        end
    endtask
    initial begin
        for (index = 0; index < 8; index = index + 1) check_input(index);
        for (index = 7; index >= 0; index = index - 1) check_input(index);
        $display("PASS: %0d truth-table checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
