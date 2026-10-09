module dev_tb;
    logic [99:0] a, b;
    logic sel;
    wire [99:0] out;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task automatic check_select;
        begin
            sel = 1'b0;
            #1;
            if (out !== a) $fatal(1, "sel=0 mismatch");
            checks = checks + 1;
            sel = 1'b1;
            #1;
            if (out !== b) $fatal(1, "sel=1 mismatch");
            checks = checks + 1;
        end
    endtask

    initial begin
        a = '0; b = '1; check_select();
        a = '1; b = '0; check_select();
        for (integer bit_index = 0; bit_index < 100; bit_index = bit_index + 1) begin
            a = '0; a[bit_index] = 1'b1;
            b = ~a;
            check_select();
        end
        for (integer trial = 0; trial < 1000; trial = trial + 1) begin
            a = {$urandom, $urandom, $urandom, $urandom};
            b = {$urandom, $urandom, $urandom, $urandom};
            check_select();
        end
        $display("PASS: %0d mux comparisons", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "development test timeout");
    end
endmodule
