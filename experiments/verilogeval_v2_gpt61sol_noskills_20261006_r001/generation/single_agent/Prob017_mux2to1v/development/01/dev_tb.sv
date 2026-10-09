`timescale 1ns/1ps
module dev_tb;
    reg [99:0] a, b;
    reg sel;
    wire [99:0] out;
    integer checks = 0;
    integer i, j;
    TopModule dut (.a(a), .b(b), .sel(sel), .out(out));

    task check_selected;
        reg [99:0] expected;
        begin
            #1;
            if (sel == 1'b0) expected = a;
            else expected = b;
            if (out !== expected)
                $fatal(1, "Mismatch: sel=%b a=%h b=%h out=%h expected=%h", sel, a, b, out, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        a = 0; b = {100{1'b1}}; sel = 0; check_selected;
        sel = 1; check_selected;
        a = {100{1'b1}}; b = 0; check_selected;
        sel = 0; check_selected;
        a = 0; b = 0; check_selected;
        sel = 1; check_selected;
        a = {100{1'b1}}; b = {100{1'b1}}; check_selected;
        sel = 0; check_selected;
        // Exercise each bit, including both vector boundaries.
        for (i = 0; i < 100; i = i + 1) begin
            a = 0; a[i] = 1; b = ~a;
            sel = 0; check_selected;
            sel = 1; check_selected;
        end
        // Independently vary selected and unselected inputs under both selections.
        for (i = 0; i < 200; i = i + 1) begin
            for (j = 0; j < 100; j = j + 1) begin
                a[j] = $random;
                b[j] = $random;
            end
            sel = 0; check_selected;
            sel = 1; check_selected;
            b = ~b; check_selected;
            sel = 0; check_selected;
            a = ~a; check_selected;
        end
        // Known select must pass through four-state data without contamination
        // from an unknown unselected input.
        a = {100{1'bx}}; b = {100{1'bz}};
        sel = 0; check_selected;
        sel = 1; check_selected;
        a = 0; sel = 0; check_selected;
        b = {100{1'b1}}; sel = 1; check_selected;
        $display("PASS: %0d mux checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
