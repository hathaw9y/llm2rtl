`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg in = 1;
    reg reset = 0;
    wire [7:0] out_byte;
    wire done;
    TopModule dut (.clk(clk), .in(in), .reset(reset),
                   .out_byte(out_byte), .done(done));

    // Protocol oracle: -1 means awaiting start, 0..7 data positions,
    // 8 expected stop, and 9 waiting to resynchronize after a bad stop.
    integer position = -1;
    reg [7:0] expected_byte = 0;
    reg expected_done;
    integer cycles = 0;
    integer received = 0;
    integer n, j, k;
    reg [31:0] rng = 32'h417ac392;

    task tick(input reg serial_bit, input reg rst);
        begin
            clk = 0;
            in = serial_bit;
            reset = rst;
            #4;
            expected_done = 0;
            if (rst) begin
                position = -1;
                expected_byte = 0;
            end else if (position == -1) begin
                if (serial_bit == 0) begin
                    position = 0;
                    expected_byte = 0;
                end
            end else if (position < 8) begin
                if (serial_bit)
                    expected_byte = expected_byte | (8'b1 << position);
                position = position + 1;
            end else if (position == 8) begin
                if (serial_bit) begin
                    expected_done = 1;
                    position = -1;
                end else position = 9;
            end else if (serial_bit) position = -1;
            clk = 1;
            #1;
            cycles = cycles + 1;
            if (done !== expected_done)
                $fatal(1, "cycle %0d done=%b expected=%b", cycles, done, expected_done);
            if (expected_done) begin
                if (out_byte !== expected_byte)
                    $fatal(1, "cycle %0d byte=%h expected=%h", cycles, out_byte, expected_byte);
                received = received + 1;
            end
            #4;
            clk = 0;
            #1;
        end
    endtask

    task frame(input reg [7:0] value, input reg stop_value);
        integer b;
        begin
            tick(0, 0);
            for (b = 0; b < 8; b = b + 1) tick(value[b], 0);
            tick(stop_value, 0);
        end
    endtask

    initial begin
        tick(1, 1);
        repeat (5) tick(1, 0);
        // All bytes, without idle gaps, exercise LSB order and immediate restart.
        for (n = 0; n < 256; n = n + 1) frame(n[7:0], 1);
        // Invalid frames must not be reported, even upon a delayed high bit.
        frame(8'ha6, 0);
        repeat (20) tick(0, 0);
        tick(1, 0);
        frame(8'h81, 1);
        frame(8'hff, 0);
        tick(1, 0);
        frame(8'h3c, 1);
        // Reset at every position, including expected stop and recovery.
        for (j = 0; j <= 10; j = j + 1) begin
            tick(1, 1);
            tick(0, 0);
            for (k = 0; k < j; k = k + 1) tick(0, 0);
            tick(0, 1);
            tick(1, 0);
            frame(8'h96, 1);
        end
        // Arbitrary bit streams and occasional synchronous resets.
        for (n = 0; n < 3000; n = n + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            tick(rng[0], (rng[9:2] == 0));
        end
        tick(1, 1);
        frame(8'h5a, 1);
        repeat (3) tick(1, 0);
        if (received < 270) $fatal(1, "Insufficient valid frames");
        $display("PASS: %0d cycles, %0d valid frames", cycles, received);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
