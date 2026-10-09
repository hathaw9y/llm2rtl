`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0, data = 0, done_counting = 0, ack = 0;
    wire shift_ena, counting, done;
    TopModule dut(.*);
    always #5 clk = ~clk;

    // Oracle uses full recent serial history, not the DUT's prefix states.
    integer phase = 0; // search, shift, count, notification
    integer remaining = 0;
    integer history_length = 0;
    reg [3:0] history = 0;
    reg valid_model = 0;
    integer cycles = 0;
    integer word_value, bit_index, trial;
    reg [31:0] rng = 32'h42671abc;

    task check_outputs;
        reg [2:0] expected;
        begin
            if (valid_model) begin
                expected = {phase == 1, phase == 2, phase == 3};
                if ({shift_ena, counting, done} !== expected)
                    $fatal(1, "cycle %0d phase %0d remaining %0d: expected %b got %b",
                           cycles, phase, remaining, expected, {shift_ena,counting,done});
            end
        end
    endtask

    task tick(input reg rst, input reg bit_data, input reg complete, input reg acknowledge);
        begin
            @(negedge clk);
            reset = rst;
            data = bit_data;
            done_counting = complete;
            ack = acknowledge;
            #1;
            // Inputs, including reset, must not alter Moore outputs between edges.
            check_outputs;
            @(posedge clk);
            cycles = cycles + 1;
            if (reset) begin
                valid_model = 1;
                phase = 0;
                remaining = 0;
                history = 0;
                history_length = 0;
            end else if (valid_model) begin
                case (phase)
                    0: begin
                        history = {history[2:0], data};
                        if (history_length < 4) history_length = history_length + 1;
                        if (history_length == 4 && history == 4'b1101) begin
                            phase = 1;
                            remaining = 4;
                        end
                    end
                    1: begin
                        remaining = remaining - 1;
                        if (remaining == 0) phase = 2;
                    end
                    2: if (done_counting) phase = 3;
                    3: if (ack) begin
                        phase = 0;
                        history = 0;
                        history_length = 0;
                    end
                endcase
            end
            #1;
            check_outputs;
        end
    endtask

    task start_pattern;
        begin
            tick(0,1,1,1);
            tick(0,1,1,1);
            tick(0,0,1,1);
            tick(0,1,1,1);
        end
    endtask

    initial begin
        tick(1,1,1,1);
        // Extra leading ones exercise the overlapping 11 prefix.
        tick(0,1,0,0);
        tick(0,1,0,0);
        start_pattern;
        repeat (4) tick(0,1,1,1);
        tick(0,0,1,1); // done must still occupy a full notification cycle
        tick(0,1,1,1); // acknowledgment discards current data
        tick(0,1,0,0);
        tick(0,0,0,0);
        tick(0,1,0,0); // insufficient new bits for 1101
        tick(1,0,0,0);
        start_pattern;
        repeat (4) tick(0,0,0,0);
        repeat (7) tick(0,1,0,1);
        tick(0,0,1,0);
        repeat (7) tick(0,1,0,0);
        tick(0,0,0,1);
        // Reset from each shift position, counting, and notification.
        for (trial = 0; trial < 6; trial = trial + 1) begin
            tick(1,0,0,0);
            start_pattern;
            for (bit_index = 0; bit_index < trial; bit_index = bit_index + 1)
                tick(0,bit_index[0],1,0);
            tick(1,1,1,1);
            tick(0,0,0,0);
        end
        // Exhaust every 12-bit serial stream from reset.
        for (word_value = 0; word_value < 4096; word_value = word_value + 1) begin
            tick(1,0,0,0);
            for (bit_index = 11; bit_index >= 0; bit_index = bit_index - 1)
                tick(0,(word_value >> bit_index) & 1,0,0);
            repeat (5) tick(0,0,0,0);
            tick(0,0,1,0);
            tick(0,0,0,1);
        end
        for (trial = 0; trial < 5000; trial = trial + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            tick(rng[7:0] == 0, rng[8], rng[9], rng[10]);
        end
        $display("PASS: independent timer FSM checks (%0d cycles)",cycles);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1,"Timeout");
    end
endmodule
