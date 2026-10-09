`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0, data = 0, done_counting = 0, ack = 0;
    wire shift_ena, counting, done;
    TopModule dut(.*);
    always #5 clk = ~clk;

    // Independent oracle: serial window plus phase and remaining bit count.
    reg [3:0] history = 0;
    integer phase = 0, remaining = 0;
    integer cycles = 0;
    reg initialized = 0;
    integer word_value, bit_index, iteration;
    reg [31:0] prng = 32'h653a719d;

    task check_outputs;
        begin
            if ({shift_ena, counting, done} !==
                { (phase == 1), (phase == 2), (phase == 3) })
                $fatal(1, "Cycle %0d phase %0d remaining %0d: outputs %b%b%b",
                       cycles, phase, remaining, shift_ena, counting, done);
        end
    endtask

    task tick(input reg r, input reg d, input reg c, input reg a);
        begin
            @(negedge clk);
            reset = r; data = d; done_counting = c; ack = a;
            #1;
            // Input changes, including reset, cannot change Moore outputs.
            if (initialized) check_outputs;
            @(posedge clk);
            cycles = cycles + 1;
            if (r) begin
                phase = 0; history = 0; remaining = 0;
            end else begin
                case (phase)
                    0: begin
                        history = {history[2:0], d};
                        if (history == 4'b1101) begin
                            phase = 1; remaining = 4;
                        end
                    end
                    1: begin
                        remaining = remaining - 1;
                        if (remaining == 0) phase = 2;
                    end
                    2: if (c) phase = 3;
                    3: if (a) begin phase = 0; history = 0; end
                endcase
            end
            initialized = 1;
            #1; check_outputs;
        end
    endtask

    task pattern;
        begin
            tick(0,1,0,0); tick(0,1,0,0);
            tick(0,0,0,0); tick(0,1,0,0);
        end
    endtask

    initial begin
        tick(1,0,0,0);
        // Extra leading ones must retain the 11 prefix.
        tick(0,1,1,1); tick(0,1,1,1); pattern;
        // Early counting completion and ack must not shorten shifting.
        repeat (4) tick(0,1,1,1);
        tick(0,0,1,1);
        tick(0,1,0,1);
        // Data on the acknowledgement edge is discarded.
        tick(0,1,0,0); tick(0,0,0,0); tick(0,1,0,0);
        if (phase != 0) $fatal(1,"Ack edge was treated as search data");
        pattern;
        repeat (4) tick(0,0,0,0);
        repeat (7) tick(0,1,0,1);
        tick(0,0,1,0);
        repeat (7) tick(0,1,1,0);
        tick(0,1,1,1);

        // Reset each partial prefix, each shift cycle, counting, and done.
        for (iteration = 0; iteration < 10; iteration = iteration + 1) begin
            tick(1,1,1,1);
            case (iteration)
                0: begin end
                1: tick(0,1,0,0);
                2: begin tick(0,1,0,0); tick(0,1,0,0); end
                3: begin tick(0,1,0,0); tick(0,1,0,0); tick(0,0,0,0); end
                default: begin
                    pattern;
                    repeat (iteration-4) tick(0,0,0,0);
                    if (iteration == 9) tick(0,0,1,0);
                end
            endcase
            tick(1,1,1,1);
            tick(0,0,1,1);
        end

        // Exhaustive short search streams include all prefix fallback paths.
        for (word_value = 0; word_value < 256; word_value = word_value + 1) begin
            tick(1,0,0,0);
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                tick(0, (word_value >> bit_index) & 1, 0, 0);
            repeat (5) tick(0,0,0,0);
            tick(0,0,1,0); tick(0,0,0,1);
        end
        // Deterministic broad coverage of data and independent handshakes.
        for (iteration = 0; iteration < 3000; iteration = iteration + 1) begin
            prng = prng ^ (prng << 13);
            prng = prng ^ (prng >> 17);
            prng = prng ^ (prng << 5);
            tick(prng[7:0] == 0, prng[8], prng[9], prng[10]);
        end
        $display("PASS: timer FSM checked over %0d cycles", cycles);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1,"Development test timeout");
    end
endmodule
