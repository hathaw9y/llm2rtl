`timescale 1ns/1ps
module dev_tb;
    logic [99:0] a, b;
    logic sel;
    wire [99:0] out;
    integer checks = 0;
    integer i, j;
    logic [99:0] walking;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task automatic check_output;
        logic [99:0] expected;
        begin
            #1;
            if (sel == 1'b0) expected = a;
            else expected = b;
            if (out !== expected)
                $fatal(1, "Mismatch: sel=%b a=%h b=%h expected=%h out=%h", sel, a, b, expected, out);
            checks = checks + 1;
        end
    endtask

    task automatic check_pair(input logic [99:0] av, bv);
        begin
            a = av; b = bv;
            sel = 1'b0; check_output();
            sel = 1'b1; check_output();
        end
    endtask

    initial begin
        check_pair(100'b0, 100'b0);
        check_pair({100{1'b1}}, {100{1'b1}});
        check_pair(100'b0, {100{1'b1}});
        check_pair({100{1'b1}}, 100'b0);
        check_pair({50{2'b10}}, {50{2'b01}});
        for (i = 0; i < 100; i = i + 1) begin
            walking = 100'b0;
            walking[i] = 1'b1;
            check_pair(walking, ~walking);
            check_pair(~walking, walking);
        end
        for (i = 0; i < 200; i = i + 1) begin
            for (j = 0; j < 100; j = j + 1) begin
                a[j] = $urandom_range(0, 1);
                b[j] = $urandom_range(0, 1);
            end
            sel = 1'b0; check_output();
            a = ~a; check_output();
            b = ~b; check_output();
            sel = 1'b1; check_output();
            b = ~b; check_output();
            a = ~a; check_output();
        end
        $display("PASS: %0d mux checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
