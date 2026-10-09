`timescale 1ns/1ps
module dev_tb;
    reg [3:0] a, b, c, d, e;
    wire [3:0] q;
    integer sel, value, port_index;
    reg [3:0] expected;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .q(q));

    task check(input [3:0] want);
        begin
            if (q !== want)
                $fatal(1, "At %0t: a=%h b=%h c=%h d=%h e=%h q=%h expected=%h",
                       $time, a, b, c, d, e, q, want);
        end
    endtask

    initial begin
        // Undriven inputs and output reproduce the initial unknown interval.
        #0;
        check(4'bxxxx);
        #5; check(4'bxxxx);
        #5; check(4'bxxxx);
        #5;
        a = 4'ha; b = 4'hb; c = 0; d = 4'hd; e = 4'he;
        #0; check(4'hb);
        #5; c = 1; #0; check(4'he);
        #5; c = 2; #0; check(4'ha);
        #5; c = 3; #0; check(4'hd);
        for (sel = 4; sel < 16; sel = sel + 1) begin
            #5; c = sel; #0; check(4'hf);
        end

        // Independently vary every data input over its full range for each selector.
        for (sel = 0; sel < 16; sel = sel + 1) begin
            for (port_index = 0; port_index < 4; port_index = port_index + 1) begin
                for (value = 0; value < 16; value = value + 1) begin
                    #1;
                    c = sel;
                    a = 4'h3; b = 4'h6; d = 4'h9; e = 4'hc;
                    case (port_index)
                        0: a = value;
                        1: b = value;
                        2: d = value;
                        3: e = value;
                    endcase
                    // Oracle expressed as selector-indexed source values.
                    expected = 4'hf;
                    if (sel == 0) expected = b;
                    if (sel == 1) expected = e;
                    if (sel == 2) expected = a;
                    if (sel == 3) expected = d;
                    #0; check(expected);
                end
            end
        end
        $display("PASS: original waveform and all selector/data boundary checks");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
