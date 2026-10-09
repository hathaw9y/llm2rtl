`timescale 1ns/1ps
module dev_tb;
    logic a, b, sel_b1, sel_b2;
    wire out_assign, out_always;
    logic expected;
    integer i;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sel_b1(sel_b1), .sel_b2(sel_b2),
                   .out_assign(out_assign), .out_always(out_always));
    task automatic check_inputs(input integer pattern);
        begin
            {a, b, sel_b1, sel_b2} = pattern[3:0];
            case ({sel_b1, sel_b2})
                2'b11: expected = b;
                default: expected = a;
            endcase
            #1;
            if (out_assign !== expected || out_always !== expected)
                $fatal(1, "FAIL pattern=%b expected=%b assign=%b always=%b",
                       {a,b,sel_b1,sel_b2}, expected, out_assign, out_always);
            checks = checks + 1;
        end
    endtask
    initial begin
        for (i = 0; i < 16; i = i + 1) check_inputs(i);
        for (i = 15; i >= 0; i = i - 1) check_inputs(i);
        $display("PASS: %0d checks; all 16 binary combinations in both directions", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
