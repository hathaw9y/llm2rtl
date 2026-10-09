`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0, data = 0, done_counting = 0, ack = 0;
    wire shift_ena, counting, done;
    TopModule dut (.*);
    always #5 clk = ~clk;

    // Oracle uses raw bit history rather than the DUT's prefix-state graph.
    integer phase = 0; // 0 search, 1 shift, 2 count, 3 notification
    integer remaining = 0;
    integer valid_bits = 0;
    logic [3:0] history = 0;
    bit initialized = 0;
    integer checks = 0;
    integer seed = 32'h61739215;
    integer random_word;
    integer i, j, k;
    logic [2:0] expected;

    task automatic compare_outputs;
        begin
            expected = {phase == 1, phase == 2, phase == 3};
            if ({shift_ena, counting, done} !== expected)
                $fatal(1, "Mismatch at %0t phase=%0d remaining=%0d expected=%b actual=%b", $time, phase, remaining, expected, {shift_ena, counting, done});
            checks = checks + 1;
        end
    endtask

    task automatic step(input bit r, input bit d, input bit c, input bit a);
        begin
            @(negedge clk);
            reset = r; data = d; done_counting = c; ack = a;
            #1;
            // Reset and inputs must not change the state between clock edges.
            if (initialized) compare_outputs();
            @(posedge clk);
            if (r) begin
                phase = 0; remaining = 0; valid_bits = 0; history = 0;
                initialized = 1;
            end else begin
                case (phase)
                    0: begin
                        history = {history[2:0], d};
                        if (valid_bits < 4) valid_bits = valid_bits + 1;
                        if ((valid_bits == 4) && (history == 4'b1101)) begin
                            phase = 1;
                            remaining = 4;
                        end
                    end
                    1: begin
                        remaining = remaining - 1;
                        if (remaining == 0) phase = 2;
                    end
                    2: if (c) phase = 3;
                    3: if (a) begin
                        phase = 0; history = 0; valid_bits = 0;
                    end
                endcase
            end
            #1;
            compare_outputs();
        end
    endtask

    task automatic start_timer;
        begin
            step(0,1,1,1);
            step(0,1,1,1);
            step(0,0,1,1);
            step(0,1,1,1);
            if (phase != 1) $fatal(1, "Directed pattern did not start timer");
        end
    endtask

    initial begin
        step(1,0,0,0);
        // Extra leading ones exercise overlapping prefix retention.
        step(0,1,0,0); step(0,1,0,0); start_timer();
        repeat (4) step(0,1,1,1);
        if (phase != 2) $fatal(1, "Shift duration must be exactly four cycles");
        repeat (5) step(0,1,0,1);
        step(0,0,1,1); // ack does not bypass the notification interval
        repeat (5) step(0,1,0,0);
        step(0,1,1,1);
        start_timer();
        repeat (4) step(0,0,0,0);
        step(0,0,1,0);
        step(0,0,0,1);
        // Reset at every shift position and each other active phase.
        for (k = 0; k < 7; k = k + 1) begin
            step(1,1,1,1);
            start_timer();
            for (j = 0; j < k; j = j + 1) step(0,1,1,0);
            step(1,1,1,1);
            step(0,0,1,1);
        end
        // Reset during each partial prefix.
        for (k = 1; k <= 3; k = k + 1) begin
            step(1,0,0,0);
            step(0,1,0,0);
            if (k >= 2) step(0,1,0,0);
            if (k >= 3) step(0,0,0,0);
            step(1,1,1,1);
            step(0,1,0,0);
        end
        // Enumerate every eight-bit serial stream from clean search.
        for (i = 0; i < 256; i = i + 1) begin
            step(1,0,0,0);
            for (j = 7; j >= 0; j = j - 1) step(0, (i >> j) & 1, 0, 0);
            repeat (4) step(0,0,0,0);
            step(0,0,1,0);
            step(0,0,0,1);
        end
        for (i = 0; i < 3000; i = i + 1) begin
            random_word = $random(seed);
            step((random_word & 63) == 0, random_word[6], random_word[7], random_word[8]);
        end
        $display("PASS independent timer FSM checks: %0d comparisons", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
