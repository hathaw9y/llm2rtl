`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    integer checks = 0;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    // Expected outputs are transcribed directly from the original waveform.
    // A zero-delay sampling phase lets the continuous assignment settle
    // without moving any stimulus away from its original timestamp.
    task automatic check_row(input logic [3:0] inputs,
                             input logic expected,
                             input integer timestamp_ns);
        begin
            if ($time != timestamp_ns)
                $fatal(1, "Unexpected stimulus timestamp: %0t", $time);
            {a, b, c, d} = inputs;
            #0;
            if (q !== expected)
                $fatal(1, "At %0t inputs=%b expected=%b actual=%b",
                       $time, inputs, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_row(4'b0000, 1'b0, 0);
        #5; check_row(4'b0000, 1'b0, 5);
        #5; check_row(4'b0000, 1'b0, 10);
        #5; check_row(4'b0000, 1'b0, 15);
        #5; check_row(4'b0001, 1'b0, 20);
        #5; check_row(4'b0010, 1'b1, 25);
        #5; check_row(4'b0011, 1'b1, 30);
        #5; check_row(4'b0100, 1'b1, 35);
        #5; check_row(4'b0101, 1'b1, 40);
        #5; check_row(4'b0110, 1'b1, 45);
        #5; check_row(4'b0111, 1'b1, 50);
        #5; check_row(4'b1000, 1'b0, 55);
        #5; check_row(4'b1001, 1'b0, 60);
        #5; check_row(4'b1010, 1'b1, 65);
        #5; check_row(4'b1011, 1'b1, 70);
        #5; check_row(4'b1100, 1'b1, 75);
        #5; check_row(4'b1101, 1'b1, 80);
        #5; check_row(4'b1110, 1'b1, 85);
        #5; check_row(4'b1111, 1'b1, 90);
        if (checks != 19) $fatal(1, "Incomplete waveform checks");
        $display("PASS: all 19 original waveform rows checked");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
