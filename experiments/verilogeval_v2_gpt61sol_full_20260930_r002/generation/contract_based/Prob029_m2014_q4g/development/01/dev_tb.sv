`timescale 1ns/1ps
module dev_tb;
    logic in1, in2, in3;
    wire out;
    integer checks = 0;
    integer i;
    TopModule dut (.in1(in1), .in2(in2), .in3(in3), .out(out));

    // Explicit table derived from the specified two gates.
    function automatic logic expected_binary(input logic [2:0] inputs);
        case (inputs)
            3'b000: expected_binary = 1'b1;
            3'b001: expected_binary = 1'b0;
            3'b010: expected_binary = 1'b0;
            3'b011: expected_binary = 1'b1;
            3'b100: expected_binary = 1'b0;
            3'b101: expected_binary = 1'b1;
            3'b110: expected_binary = 1'b1;
            3'b111: expected_binary = 1'b0;
            default: expected_binary = 1'bx;
        endcase
    endfunction

    task automatic check_value(input logic a, b, c, expected);
        begin
            {in1,in2,in3} = {a,b,c};
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch inputs=%b%b%b expected=%b actual=%b", a,b,c,expected,out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Supplementary checks of standard gate unknown propagation.
        check_value(1'bx,1'bx,1'bx,1'bx);
        for (i = 0; i < 8; i = i + 1)
            check_value(i[2],i[1],i[0],expected_binary(i[2:0]));
        for (i = 7; i >= 0; i = i - 1)
            check_value(i[2],i[1],i[0],expected_binary(i[2:0]));
        check_value(1'bx,1'b0,1'b0,1'bx);
        check_value(1'b0,1'bx,1'b1,1'bx);
        check_value(1'b1,1'b1,1'bx,1'bx);
        check_value(1'bz,1'b1,1'b0,1'bx);
        check_value(1'b0,1'bz,1'b1,1'bx);
        check_value(1'b0,1'b0,1'bz,1'bx);
        check_value(1'b0,1'b0,1'b0,1'b1);
        $display("PASS: %0d combinational gate checks",checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
