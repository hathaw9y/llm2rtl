`timescale 1ns/1ps
module dev_tb;
    logic [3:0] a, b, c, d, e;
    wire [3:0] q;
    integer sel, payload;
    integer checks = 0;
    logic [3:0] expected;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .q(q));

    task automatic check(input logic [3:0] want);
        begin
            if (q !== want)
                $fatal(1, "Mismatch t=%0t a=%h b=%h c=%h d=%h e=%h q=%h expected=%h",
                       $time, a, b, c, d, e, q, want);
            checks = checks + 1;
        end
    endtask

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end

    initial begin
        // Original timestamps; delta-cycle settling leaves physical time unchanged.
        a = 4'hx; b = 4'hx; c = 4'hx; d = 4'hx; e = 4'hx;
        #0; check(4'hx);
        #5; check(4'hx);
        #5; check(4'hx);
        #5; a = 4'ha; b = 4'hb; c = 0; d = 4'hd; e = 4'he;
        #0; check(4'hb);
        #5; c = 1; #0; check(4'he);
        #5; c = 2; #0; check(4'ha);
        #5; c = 3; #0; check(4'hd);
        for (sel = 4; sel < 16; sel = sel + 1) begin
            #5; c = sel[3:0]; #0; check(4'hf);
        end

        // Exhaust all known input combinations, with expected selection written
        // independently as conditions rather than copying the DUT case statement.
        for (sel = 0; sel < 16; sel = sel + 1) begin
            for (payload = 0; payload < 65536; payload = payload + 1) begin
                c = sel[3:0];
                {a,b,d,e} = payload[15:0];
                expected = 4'hf;
                if (sel == 0) expected = payload[11:8];
                if (sel == 1) expected = payload[3:0];
                if (sel == 2) expected = payload[15:12];
                if (sel == 3) expected = payload[7:4];
                #0.001; check(expected);
            end
        end
        // A selected unknown payload propagates, while unselected unknowns
        // cannot disturb a selected known payload or the constant output.
        for (sel = 0; sel < 4; sel = sel + 1) begin
            c = sel[3:0]; a = 4'hx; b = 4'hx; d = 4'hx; e = 4'hx;
            #0.001; check(4'hx);
            if (sel == 0) b = 4'h0;
            if (sel == 1) e = 4'hf;
            if (sel == 2) a = 4'h5;
            if (sel == 3) d = 4'ha;
            #0.001;
            if (sel == 0) check(4'h0);
            if (sel == 1) check(4'hf);
            if (sel == 2) check(4'h5);
            if (sel == 3) check(4'ha);
        end
        for (sel = 4; sel < 16; sel = sel + 1) begin
            c = sel[3:0]; a = 4'hx; b = 4'hx; d = 4'hx; e = 4'hx;
            #0.001; check(4'hf);
        end
        $display("PASS %0d checks", checks);
        $finish;
    end
endmodule
