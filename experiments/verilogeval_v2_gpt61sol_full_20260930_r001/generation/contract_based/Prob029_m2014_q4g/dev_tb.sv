`timescale 1ns/1ps
module dev_tb;
    logic in1, in2, in3;
    wire out;
    localparam logic [7:0] EXPECTED = 8'b01101001;
    integer index;
    integer checks = 0;
    TopModule dut (.in1(in1), .in2(in2), .in3(in3), .out(out));

    task automatic check_input(input integer vector_index);
        begin
            {in1, in2, in3} = vector_index[2:0];
            #1;
            if (out !== EXPECTED[vector_index])
                $fatal(1, "FAIL inputs=%b%b%b expected=%b actual=%b",
                       in1, in2, in3, EXPECTED[vector_index], out);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (index = 0; index < 8; index = index + 1)
            check_input(index);
        for (index = 7; index >= 0; index = index - 1)
            check_input(index);
        $display("PASS: %0d checks, all eight binary combinations in both orders", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL watchdog timeout");
    end
endmodule
