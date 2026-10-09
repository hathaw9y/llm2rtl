`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 1;
    wire done;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .done(done));
    always #5 clk = ~clk;

    // phase: -1 seeking start, 0..7 data positions, 8 stop, 9 recovery.
    integer phase = -1;
    integer samples = 0;
    integer completions = 0;
    reg expected_done = 0;
    reg established = 0;
    integer value, bit_index, position, repeat_index;
    reg [31:0] random_state = 32'h91234567;

    task automatic step(input reg serial_bit, input reg reset_bit);
        begin
            @(negedge clk);
            in = serial_bit;
            reset = reset_bit;
            #1;
            if (established && done !== expected_done)
                $fatal(1, "Output changed without rising edge at sample %0d", samples);
            @(posedge clk);
            if (reset_bit) begin
                phase = -1;
                expected_done = 0;
                established = 1;
            end else begin
                expected_done = 0;
                if (phase == -1) begin
                    if (serial_bit == 0) phase = 0;
                end else if (phase < 8) begin
                    phase = phase + 1;
                end else if (phase == 8) begin
                    if (serial_bit == 1) begin
                        expected_done = 1;
                        phase = -1;
                        completions = completions + 1;
                    end else phase = 9;
                end else begin
                    if (serial_bit == 1) phase = -1;
                end
            end
            #1;
            samples = samples + 1;
            if (done !== expected_done)
                $fatal(1, "Mismatch sample %0d bit=%b reset=%b phase=%0d expected=%b actual=%b",
                       samples, serial_bit, reset_bit, phase, expected_done, done);
        end
    endtask

    task automatic frame(input reg [7:0] payload, input reg stop_bit);
        integer b;
        begin
            step(0, 0);
            for (b = 0; b < 8; b = b + 1) step(payload[b], 0);
            step(stop_bit, 0);
        end
    endtask

    initial begin
        step(1, 1);
        repeat (8) step(1, 0);
        // Every payload, including zeros and ones, with no idle gaps.
        for (value = 0; value < 256; value = value + 1)
            frame(value[7:0], 1);
        step(1, 0);
        if (completions != 256) $fatal(1, "Directed valid frame count wrong");

        for (repeat_index = 0; repeat_index < 16; repeat_index = repeat_index + 1) begin
            frame(8'hA5, 0);
            repeat (repeat_index) step(0, 0);
            step(1, 0); // Recovery delimiter must not complete the failed frame.
            frame(8'h3C, 1);
        end
        step(1, 0);
        if (completions != 272) $fatal(1, "Recovery frame count wrong");
        repeat (100) step(0, 0);
        step(1, 0);
        frame(8'h00, 1);

        // Synchronous reset at each point from start through completion.
        for (position = 0; position <= 10; position = position + 1) begin
            step(1, 1);
            step(0, 0);
            for (bit_index = 0; bit_index < position; bit_index = bit_index + 1)
                step(1, 0);
            step(0, 1);
            step(1, 0);
            frame(8'h81, 1);
        end
        frame(8'hFF, 0);
        repeat (4) step(0, 0);
        step(0, 1); // Reset while waiting for recovery.
        step(1, 0);
        frame(8'hFF, 1);
        step(1, 1);
        step(0, 1);
        step(1, 0);

        for (value = 0; value < 3000; value = value + 1) begin
            random_state = {random_state[30:0],
                            random_state[31] ^ random_state[21] ^ random_state[1] ^ random_state[0]};
            step(random_state[0], random_state[12:8] == 5'd0);
        end
        step(1, 1);
        step(1, 0);
        $display("PASS serial framing: %0d samples, %0d completed frames", samples, completions);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
