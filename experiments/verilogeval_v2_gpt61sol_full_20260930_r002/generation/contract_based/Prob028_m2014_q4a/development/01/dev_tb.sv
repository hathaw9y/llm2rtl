`timescale 1ns/1ps
module dev_tb;
    logic d;
    logic ena;
    wire q;
    integer checks = 0;

    TopModule dut (.d(d), .ena(ena), .q(q));

    task automatic drive_check(
        input logic next_d,
        input logic next_ena,
        input logic expected_q
    );
        begin
            d = next_d;
            ena = next_ena;
            #1;
            if (q !== expected_q)
                $fatal(1, "Mismatch at %0t: d=%b ena=%b expected=%b observed=%b",
                       $time, d, ena, expected_q, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No reset or initialization is present in the original interface.
        drive_check(1'b0, 1'b0, 1'bx);
        drive_check(1'b1, 1'b0, 1'bx);
        drive_check(1'b0, 1'b0, 1'bx);
        // Opening the latch transfers the current input.
        drive_check(1'b0, 1'b1, 1'b0);
        // Both input transitions must propagate without an enable edge.
        drive_check(1'b1, 1'b1, 1'b1);
        drive_check(1'b0, 1'b1, 1'b0);
        drive_check(1'b0, 1'b1, 1'b0);
        // Closing holds zero, including coincident data/enable changes.
        drive_check(1'b1, 1'b0, 1'b0);
        drive_check(1'b0, 1'b0, 1'b0);
        drive_check(1'b1, 1'b0, 1'b0);
        drive_check(1'b1, 1'b1, 1'b1);
        // Closing holds one while data changes.
        drive_check(1'b0, 1'b0, 1'b1);
        drive_check(1'b1, 1'b0, 1'b1);
        drive_check(1'b0, 1'b0, 1'b1);
        // Reopening with zero and simultaneous data/enable transitions.
        drive_check(1'b0, 1'b1, 1'b0);
        drive_check(1'b0, 1'b0, 1'b0);
        drive_check(1'b1, 1'b1, 1'b1);
        drive_check(1'b1, 1'b0, 1'b1);
        drive_check(1'b0, 1'b1, 1'b0);
        drive_check(1'b1, 1'b1, 1'b1);
        drive_check(1'b1, 1'b0, 1'b1);
        #10;
        if (q !== 1'b1) $fatal(1, "Latch failed long disabled hold");
        checks = checks + 1;
        $display("PASS: D latch passed %0d checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
