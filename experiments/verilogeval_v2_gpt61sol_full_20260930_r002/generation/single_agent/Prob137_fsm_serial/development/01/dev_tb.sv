`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 1;
    wire done;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    // remaining=-1: ready; -2: seeking recovery high;
    // 8..1: data bits remaining; 0: next sample must be stop.
    integer remaining = -1;
    integer checks = 0;
    reg expected = 0;
    integer b, value, trial;
    reg previous;

    task step(input reg serial_bit, input reg rst);
        begin
            @(negedge clk);
            previous = done;
            in = serial_bit;
            reset = rst;
            #1;
            if (done !== previous)
                $fatal(1, "Output changed before positive clock edge");
            @(posedge clk);
            expected = 0;
            if (rst) remaining = -1;
            else if (remaining == -1) begin
                if (!serial_bit) remaining = 8;
            end else if (remaining == -2) begin
                if (serial_bit) remaining = -1;
            end else if (remaining > 0) remaining = remaining - 1;
            else begin
                if (serial_bit) begin
                    expected = 1;
                    remaining = -1;
                end else remaining = -2;
            end
            #1;
            checks = checks + 1;
            if (done !== expected)
                $fatal(1, "Check %0d: expected done=%b got=%b", checks, expected, done);
        end
    endtask

    task frame(input reg [7:0] payload, input reg good_stop);
        integer j;
        begin
            step(0, 0);
            for (j=0; j<8; j=j+1) step(payload[j], 0);
            step(good_stop, 0);
        end
    endtask

    initial begin
        step(1, 1);
        repeat (4) step(1, 0);
        // All byte patterns, including immediate back-to-back starts.
        for (value=0; value<256; value=value+1) frame(value[7:0], 1);
        step(1, 0);
        frame(8'hff, 0);
        repeat (20) step(0, 0);
        step(1, 0); // Recovery is not completion.
        frame(8'h00, 1);
        frame(8'ha5, 0);
        step(0, 1); // Reset overrides invalid-frame recovery.
        frame(8'h5a, 1);
        // Reset at every position in a partial frame.
        for (b=0; b<10; b=b+1) begin
            step(1, 1);
            step(0, 0);
            for (trial=0; trial<b; trial=trial+1) step(0, 0);
            step(0, 1);
            frame(8'h81, 1);
        end
        // Deterministic randomized serial streams and reset interruptions.
        for (trial=0; trial<2000; trial=trial+1)
            step(($random & 1), ((trial % 137) == 0));
        step(1, 1);
        frame(8'h42, 1);
        step(1, 1); // Reset clears completion at the following edge.
        $display("PASS serial receiver: %0d checked clock samples", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
