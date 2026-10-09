`timescale 1ns/1ps
module dev_tb;
    reg [255:0] in;
    reg [7:0] sel;
    wire out;
    integer i, j;
    integer checks = 0;
    TopModule dut (.in(in), .sel(sel), .out(out));

    task check_selection;
        integer k;
        reg expected;
        begin
            expected = 1'bx;
            for (k = 0; k < 256; k = k + 1)
                if (sel == k) expected = in[k];
            #1;
            if (out !== expected)
                $fatal(1, "Selection %0d: expected %b, got %b", sel, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            sel = i;
            in = 256'b0;
            check_selection;
            in = {256{1'b1}};
            check_selection;
        end
        // Every input bit is exercised both as selected and unselected.
        for (i = 0; i < 256; i = i + 1) begin
            in = 256'b0;
            in[i] = 1'b1;
            for (j = 0; j < 256; j = j + 1) begin
                sel = j;
                check_selection;
            end
            in = ~in;
            for (j = 0; j < 256; j = j + 1) begin
                sel = j;
                check_selection;
            end
        end
        for (i = 0; i < 256; i = i + 1) begin
            sel = i;
            in = {128{2'b10}};
            check_selection;
            in = {128{2'b01}};
            check_selection;
            in[i] = 1'bx;
            check_selection;
            in[i] = 1'bz;
            check_selection;
        end
        $display("PASS: %0d mux checks", checks);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Bounded test timeout");
    end
endmodule
