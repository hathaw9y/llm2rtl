`timescale 1ns/1ps
module dev_tb;
    logic a, b, sel_b1, sel_b2;
    wire out_assign, out_always;
    logic expected;
    integer i;
    integer checks = 0;

    TopModule dut (
        .a(a), .b(b), .sel_b1(sel_b1), .sel_b2(sel_b2),
        .out_assign(out_assign), .out_always(out_always)
    );

    task automatic check_vector(input logic [3:0] vector);
        begin
            {a, b, sel_b1, sel_b2} = vector;
            // Original truth table, expressed separately from the DUT predicate.
            case ({sel_b1, sel_b2})
                2'b00, 2'b01, 2'b10: expected = a;
                2'b11: expected = b;
                default: $fatal(1, "Unexpected nonbinary stimulus");
            endcase
            #1;
            if (out_assign !== expected || out_always !== expected)
                $fatal(1, "vector=%b expected=%b assign=%b always=%b",
                       vector, expected, out_assign, out_always);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 16; i = i + 1)
            check_vector(i[3:0]);
        for (i = 15; i >= 0; i = i - 1)
            check_vector(i[3:0]);
        $display("PASS all %0d combinational truth-table checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
