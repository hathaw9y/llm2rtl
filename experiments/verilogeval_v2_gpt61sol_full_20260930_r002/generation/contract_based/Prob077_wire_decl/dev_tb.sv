`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out, out_n;
    integer i, j, k, l;
    integer checked = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out), .out_n(out_n));

    function automatic logic value4(input integer code);
        case (code)
            0: value4 = 1'b0;
            1: value4 = 1'b1;
            2: value4 = 1'bx;
            3: value4 = 1'bz;
        endcase
    endfunction

    // Truth classification: a zero blocks an AND, two ones assert it.
    function automatic logic and_truth(input logic x, input logic y);
        if ((x === 1'b0) || (y === 1'b0)) and_truth = 1'b0;
        else if ((x === 1'b1) && (y === 1'b1)) and_truth = 1'b1;
        else and_truth = 1'bx;
    endfunction

    task automatic check_outputs;
        logic first_and, second_and, expected, expected_n;
        begin
            first_and = and_truth(a, b);
            second_and = and_truth(c, d);
            if ((first_and === 1'b1) || (second_and === 1'b1)) expected = 1'b1;
            else if ((first_and === 1'b0) && (second_and === 1'b0)) expected = 1'b0;
            else expected = 1'bx;
            case (expected)
                1'b0: expected_n = 1'b1;
                1'b1: expected_n = 1'b0;
                default: expected_n = 1'bx;
            endcase
            if ((out !== expected) || (out_n !== expected_n))
                $fatal(1, "Inputs %b%b%b%b: got %b/%b expected %b/%b", a,b,c,d,out,out_n,expected,expected_n);
            checked = checked + 1;
        end
    endtask

    initial begin
        // Explicit exhaustive binary cases include both endpoints and each path.
        for (i = 0; i < 16; i = i + 1) begin
            {a,b,c,d} = i[3:0];
            #1;
            check_outputs();
        end
        // Verify controlling values and unknown propagation independently.
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                for (k = 0; k < 4; k = k + 1)
                    for (l = 0; l < 4; l = l + 1) begin
                        a = value4(i); b = value4(j);
                        c = value4(k); d = value4(l);
                        #1;
                        check_outputs();
                    end
        $display("PASS: %0d combinational truth-table checks", checked);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
