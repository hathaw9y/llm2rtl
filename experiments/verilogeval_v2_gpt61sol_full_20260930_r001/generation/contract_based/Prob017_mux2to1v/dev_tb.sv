`timescale 1ns/1ps
module dev_tb;
    logic [99:0] a, b;
    logic sel;
    wire [99:0] out;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task automatic check_output;
        #1;
        for (integer bit_index = 0; bit_index < 100; bit_index = bit_index + 1) begin
            if (sel == 1'b0) begin
                if (out[bit_index] !== a[bit_index])
                    $fatal(1, "FAIL a selection bit %0d", bit_index);
            end else begin
                if (out[bit_index] !== b[bit_index])
                    $fatal(1, "FAIL b selection bit %0d", bit_index);
            end
        end
        checks = checks + 1;
    endtask

    task automatic check_both;
        sel = 1'b0;
        check_output();
        sel = 1'b1;
        check_output();
    endtask

    initial begin
        a = '0; b = '0; check_both();
        a = '1; b = '1; check_both();
        a = '0; b = '1; check_both();
        a = '1; b = '0; check_both();
        a = {50{2'b01}}; b = {50{2'b10}}; check_both();
        for (integer i = 0; i < 100; i = i + 1) begin
            a = '0; a[i] = 1'b1; b = ~a; check_both();
            a = ~a; b = ~a; check_both();
        end
        for (integer trial = 0; trial < 1000; trial = trial + 1) begin
            for (integer i = 0; i < 100; i = i + 1) begin
                a[i] = $urandom_range(0, 1);
                b[i] = $urandom_range(0, 1);
            end
            check_both();
            a = ~a; b = ~b; check_output();
            sel = 1'b0; check_output();
            a = ~a; b = ~b; check_output();
        end
        $display("PASS: %0d vector checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
