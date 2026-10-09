`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    integer checks = 0;
    top_module dut (.x(x), .y(y), .z(z));

    task automatic check_input(input logic [1:0] pair);
        logic expected;
        begin
            {x,y} = pair;
            case (pair)
                2'b00: expected = 1'b1;
                2'b01: expected = 1'b0;
                2'b10: expected = 1'b1;
                2'b11: expected = 1'b1;
            endcase
            #1;
            if (z !== expected)
                $fatal(1, "FAIL x=%b y=%b z=%b expected=%b", x,y,z,expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer i=0; i<4; i=i+1) check_input(i[1:0]);
        for (integer i=0; i<4; i=i+1)
            for (integer j=0; j<4; j=j+1) begin
                check_input(i[1:0]);
                check_input(j[1:0]);
            end
        check_input(2'b00); check_input(2'b00); check_input(2'b00);
        check_input(2'b00); check_input(2'b00); check_input(2'b10);
        check_input(2'b10); check_input(2'b01); check_input(2'b01);
        check_input(2'b11); check_input(2'b11); check_input(2'b00);
        check_input(2'b01); check_input(2'b01); check_input(2'b11);
        check_input(2'b01); check_input(2'b01); check_input(2'b01);
        check_input(2'b10);
        $display("PASS: %0d checks; all binary combinations and ordered transitions plus waveform input replay", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL watchdog timeout");
    end
endmodule
