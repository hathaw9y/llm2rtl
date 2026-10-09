`timescale 1ns/1ps
module dev_tb;
    reg clock;
    reg a;
    wire p, q;
    integer checks = 0;
    TopModule dut(.clock(clock), .a(a), .p(p), .q(q));

    // Absolute timestamps preserve all original simultaneous changes.
    // One picosecond of settling allows nonblocking assignments to finish.
    task automatic sample(input integer timestamp,
                          input reg next_clock, next_a, expected_p, expected_q);
        begin
            #(timestamp - $realtime);
            {clock, a} = {next_clock, next_a};
            #0.001;
            if (p !== expected_p || q !== expected_q)
                $fatal(1, "At %0d ns: p=%b q=%b, expected p=%b q=%b",
                       timestamp, p, q, expected_p, expected_q);
            checks = checks + 1;
        end
    endtask

    initial begin
        sample(0, 1'b0, 1'b0, 1'bx, 1'bx);
        sample(5, 1'b0, 1'b0, 1'bx, 1'bx);
        sample(10, 1'b0, 1'b0, 1'bx, 1'bx);
        sample(15, 1'b0, 1'b0, 1'bx, 1'bx);
        sample(20, 1'b0, 1'b0, 1'bx, 1'bx);
        sample(25, 1'b1, 1'b0, 1'b0, 1'bx);
        sample(30, 1'b1, 1'b0, 1'b0, 1'bx);
        sample(35, 1'b1, 1'b0, 1'b0, 1'bx);
        sample(40, 1'b1, 1'b0, 1'b0, 1'bx);
        sample(45, 1'b1, 1'b0, 1'b0, 1'bx);
        sample(50, 1'b1, 1'b0, 1'b0, 1'bx);
        sample(55, 1'b0, 1'b0, 1'b0, 1'b0);
        sample(60, 1'b0, 1'b0, 1'b0, 1'b0);
        sample(65, 1'b0, 1'b0, 1'b0, 1'b0);
        sample(70, 1'b0, 1'b1, 1'b0, 1'b0);
        sample(75, 1'b0, 1'b0, 1'b0, 1'b0);
        sample(80, 1'b0, 1'b1, 1'b0, 1'b0);
        sample(85, 1'b1, 1'b0, 1'b0, 1'b0);
        sample(90, 1'b1, 1'b1, 1'b1, 1'b0);
        sample(95, 1'b1, 1'b0, 1'b0, 1'b0);
        sample(100, 1'b1, 1'b1, 1'b1, 1'b0);
        sample(105, 1'b1, 1'b0, 1'b0, 1'b0);
        sample(110, 1'b1, 1'b1, 1'b1, 1'b0);
        sample(115, 1'b0, 1'b0, 1'b1, 1'b1);
        sample(120, 1'b0, 1'b1, 1'b1, 1'b1);
        sample(125, 1'b0, 1'b0, 1'b1, 1'b1);
        sample(130, 1'b0, 1'b1, 1'b1, 1'b1);
        sample(135, 1'b0, 1'b0, 1'b1, 1'b1);
        sample(140, 1'b0, 1'b0, 1'b1, 1'b1);
        sample(145, 1'b1, 1'b0, 1'b0, 1'b1);
        sample(150, 1'b1, 1'b0, 1'b0, 1'b1);
        sample(155, 1'b1, 1'b0, 1'b0, 1'b1);
        sample(160, 1'b1, 1'b0, 1'b0, 1'b1);
        sample(165, 1'b1, 1'b1, 1'b1, 1'b1);
        sample(170, 1'b1, 1'b0, 1'b0, 1'b1);
        sample(175, 1'b0, 1'b1, 1'b0, 1'b0);
        sample(180, 1'b0, 1'b0, 1'b0, 1'b0);
        sample(185, 1'b0, 1'b1, 1'b0, 1'b0);
        sample(190, 1'b0, 1'b0, 1'b0, 1'b0);
        // Additional directed cases use the same phase rules inferred
        // from the original table, including opposite simultaneous changes.
        sample(195, 1'b0, 1'b1, 1'b0, 1'b0);
        sample(200, 1'b1, 1'b1, 1'b1, 1'b0);
        sample(205, 1'b1, 1'b0, 1'b0, 1'b0);
        sample(210, 1'b1, 1'b1, 1'b1, 1'b0);
        sample(215, 1'b0, 1'b0, 1'b1, 1'b1);
        sample(220, 1'b0, 1'b1, 1'b1, 1'b1);
        sample(225, 1'b0, 1'b0, 1'b1, 1'b1);
        sample(230, 1'b1, 1'b0, 1'b0, 1'b1);
        sample(235, 1'b0, 1'b1, 1'b0, 1'b0);
        sample(240, 1'b0, 1'b0, 1'b0, 1'b0);
        sample(245, 1'b1, 1'b1, 1'b1, 1'b0);
        sample(250, 1'b0, 1'b1, 1'b1, 1'b1);
        sample(255, 1'b0, 1'b0, 1'b1, 1'b1);
        $display("PASS: %0d original waveform and directed checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
