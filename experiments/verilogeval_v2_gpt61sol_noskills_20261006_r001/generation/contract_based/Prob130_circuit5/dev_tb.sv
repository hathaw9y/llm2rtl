`timescale 1ns/1ps
module dev_tb;
    logic [3:0] a, b, c, d, e;
    wire [3:0] q;
    integer s, v, port_index;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .q(q));

    task automatic check(input logic [3:0] expected);
        if (q !== expected)
            $fatal(1, "At %0t c=%h a=%h b=%h d=%h e=%h q=%h expected=%h",
                   $time, c, a, b, d, e, q, expected);
    endtask

    // Oracle derives directly from the four waveform selection rows.
    task automatic check_known_selector;
        logic [3:0] expected;
        begin
            expected = 4'hf;
            if (c == 0) expected = b;
            if (c == 1) expected = e;
            if (c == 2) expected = a;
            if (c == 3) expected = d;
            check(expected);
        end
    endtask

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end

    initial begin
        a = 4'hx; b = 4'hx; c = 4'hx; d = 4'hx; e = 4'hx;
        #0; check(4'hx);
        #5; check(4'hx);
        #5; check(4'hx);
        #5; a = 4'ha; b = 4'hb; c = 0; d = 4'hd; e = 4'he;
        #0; check(4'hb);
        #5; c = 1; #0; check(4'he);
        #5; c = 2; #0; check(4'ha);
        #5; c = 3; #0; check(4'hd);
        for (s = 4; s < 16; s = s + 1) begin
            #5; c = s; #0; check(4'hf);
        end
        // Every selector and every value on each independently varied data port.
        for (s = 0; s < 16; s = s + 1)
            for (port_index = 0; port_index < 4; port_index = port_index + 1)
                for (v = 0; v < 16; v = v + 1) begin
                    c = s; a = 1; b = 4; d = 8; e = 12;
                    case (port_index)
                        0: a = v;
                        1: b = v;
                        2: d = v;
                        3: e = v;
                    endcase
                    #1; check_known_selector();
                end
        // Unknown selected data must pass through; invalid known selectors stay f.
        a = 4'hx; b = 4'hx; d = 4'hx; e = 4'hx;
        for (s = 0; s < 16; s = s + 1) begin
            c = s; #1;
            if (s < 4) check(4'hx);
            else check(4'hf);
        end
        $display("PASS waveform replay and 1040 additional data/selector cases");
        $finish;
    end
endmodule
