`timescale 1ns/1ps
module dev_tb;
    reg clock;
    reg a;
    wire p, q;
    integer checks = 0;
    TopModule dut (.clock(clock), .a(a), .p(p), .q(q));

    task check(input reg ep, input reg eq);
        begin
            if (p !== ep || q !== eq)
                $fatal(1, "At %0t: p=%b q=%b expected p=%b q=%b", $time, p, q, ep, eq);
            checks = checks + 1;
        end
    endtask

    initial begin
        #500;
        $fatal(1, "Timeout");
    end

    initial begin
        {clock, a} = 2'b00;
        #0.001; check(1'bx, 1'bx); // 0ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'bx, 1'bx); // 5ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'bx, 1'bx); // 10ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'bx, 1'bx); // 15ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'bx, 1'bx); // 20ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'bx); // 25ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'bx); // 30ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'bx); // 35ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'bx); // 40ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'bx); // 45ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'bx); // 50ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b0, 1'b0); // 55ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b0, 1'b0); // 60ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b0, 1'b0); // 65ns
        #4.999; {clock, a} = 2'b01;
        #0.001; check(1'b0, 1'b0); // 70ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b0, 1'b0); // 75ns
        #4.999; {clock, a} = 2'b01;
        #0.001; check(1'b0, 1'b0); // 80ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'b0); // 85ns
        #4.999; {clock, a} = 2'b11;
        #0.001; check(1'b1, 1'b0); // 90ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'b0); // 95ns
        #4.999; {clock, a} = 2'b11;
        #0.001; check(1'b1, 1'b0); // 100ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'b0); // 105ns
        #4.999; {clock, a} = 2'b11;
        #0.001; check(1'b1, 1'b0); // 110ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b1, 1'b1); // 115ns
        #4.999; {clock, a} = 2'b01;
        #0.001; check(1'b1, 1'b1); // 120ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b1, 1'b1); // 125ns
        #4.999; {clock, a} = 2'b01;
        #0.001; check(1'b1, 1'b1); // 130ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b1, 1'b1); // 135ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b1, 1'b1); // 140ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'b1); // 145ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'b1); // 150ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'b1); // 155ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'b1); // 160ns
        #4.999; {clock, a} = 2'b11;
        #0.001; check(1'b1, 1'b1); // 165ns
        #4.999; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'b1); // 170ns
        #4.999; {clock, a} = 2'b01;
        #0.001; check(1'b0, 1'b0); // 175ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b0, 1'b0); // 180ns
        #4.999; {clock, a} = 2'b01;
        #0.001; check(1'b0, 1'b0); // 185ns
        #4.999; {clock, a} = 2'b00;
        #0.001; check(1'b0, 1'b0); // 190ns

        // Additional phase and boundary checks after the original trace.
        #4.999; a = 1;
        #0.001; check(1'b0, 1'b0);
        #4.999; clock = 1;
        #0.001; check(1'b1, 1'b0);
        #1; a = 0;
        #0.001; check(1'b0, 1'b0);
        #1; a = 1;
        #0.001; check(1'b1, 1'b0);
        #1; {clock, a} = 2'b00;
        #0.001; check(1'b1, 1'b1);
        #1; a = 1;
        #0.001; check(1'b1, 1'b1);
        #1; {clock, a} = 2'b10;
        #0.001; check(1'b0, 1'b1);
        #1; {clock, a} = 2'b01;
        #0.001; check(1'b0, 1'b0);
        $display("PASS: %0d waveform and boundary checks", checks);
        $finish;
    end
endmodule
