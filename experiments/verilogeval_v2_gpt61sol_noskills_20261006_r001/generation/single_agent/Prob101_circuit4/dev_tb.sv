`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire q;
    integer i;
    integer checks = 0;
    // Expected outputs for input words abcd = 0000 through 1111,
    // transcribed directly from the original waveform.
    localparam [15:0] EXPECTED = 16'b1111110011111100;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    task check_row(input [3:0] inputs);
        begin
            {a, b, c, d} = inputs;
            // Sample after combinational delta-cycle settling at the same timestamp.
            #0;
            if (q !== EXPECTED[inputs])
                $fatal(1, "At %0t: abcd=%b, expected q=%b, got %b",
                       $time, inputs, EXPECTED[inputs], q);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_row(4'b0000);        // 0 ns
        #5; check_row(4'b0000);    // 5 ns
        #5; check_row(4'b0000);    // 10 ns
        #5; check_row(4'b0000);    // 15 ns
        for (i = 1; i < 16; i = i + 1) begin
            #5; check_row(i[3:0]); // 20 through 90 ns
        end
        if (checks != 19 || $time != 90)
            $fatal(1, "Incomplete waveform replay");
        $display("PASS: all 19 original waveform rows checked at their original times");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
