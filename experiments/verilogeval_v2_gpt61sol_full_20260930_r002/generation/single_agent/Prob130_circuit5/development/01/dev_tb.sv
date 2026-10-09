`timescale 1ns/1ps
module dev_tb;
    logic [3:0] a, b, c, d, e;
    wire [3:0] q;
    integer selector, av, bv, dv, ev;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .q(q));

    task automatic check(input logic [3:0] expected);
        begin
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: a=%h b=%h c=%h d=%h e=%h q=%h expected=%h",
                       $time, a, b, c, d, e, q, expected);
            checks = checks + 1;
        end
    endtask

    // Independent indexed table for the selector ordering inferred from the waveform.
    task automatic check_known;
        logic [15:0] choices;
        logic [3:0] expected;
        begin
            choices = {d, a, e, b};
            expected = 4'hf;
            if (c < 4) expected = choices[4*c +: 4];
            check(expected);
        end
    endtask

    initial begin
        // Sample after combinational settling at the original timestamps.
        #0.001; check(4'hx);
        #4.999; check(4'hx);
        #5; check(4'hx);
        #5;
        a = 4'ha; b = 4'hb; c = 0; d = 4'hd; e = 4'he;
        #0.001; check(4'hb);
        for (selector = 1; selector < 16; selector = selector + 1) begin
            #4.999; c = selector;
            #0.001; check_known();
        end
        // Exhaust every known input combination, including all data boundaries.
        for (selector = 0; selector < 16; selector = selector + 1)
            for (av = 0; av < 16; av = av + 1)
                for (bv = 0; bv < 16; bv = bv + 1)
                    for (dv = 0; dv < 16; dv = dv + 1)
                        for (ev = 0; ev < 16; ev = ev + 1) begin
                            c = selector; a = av; b = bv; d = dv; e = ev;
                            #0.001; check_known();
                        end
        // Selected unknown payloads must propagate; unused payloads do not matter.
        a = 'x; b = 'x; d = 'x; e = 'x;
        for (selector = 0; selector < 16; selector = selector + 1) begin
            c = selector;
            #0.001;
            if (selector < 4) check(4'hx);
            else check(4'hf);
        end
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
