`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0, data = 0, done_counting = 0, ack = 0;
    wire shift_ena, counting, done;
    TopModule dut (.*);
    always #5 clk = ~clk;

    // Independent oracle: a rolling input window plus timer phases.
    integer phase = 0; // 0 search, 1 shift, 2 count, 3 notify
    integer remaining = 0;
    integer seen = 0;
    integer cycles = 0;
    logic [3:0] history = 0;
    logic [2:0] expected;
    logic [2:0] held;
    integer i, j;
    logic [15:0] stream;

    task automatic check_outputs;
        begin
            expected = {phase == 1, phase == 2, phase == 3};
            if ({shift_ena, counting, done} !== expected)
                $fatal(1, "cycle %0d phase %0d expected %b got %b", cycles,
                       phase, expected, {shift_ena, counting, done});
        end
    endtask

    task automatic tick(input logic r, input logic d,
                        input logic c, input logic a);
        begin
            @(negedge clk);
            held = {shift_ena, counting, done};
            reset = r; data = d; done_counting = c; ack = a;
            #1;
            // Inputs, including synchronous reset, cannot change Moore outputs.
            if (cycles > 0 && {shift_ena, counting, done} !== held)
                $fatal(1, "outputs changed before positive edge");
            @(posedge clk);
            if (r) begin
                phase = 0; remaining = 0; seen = 0; history = 0;
            end else begin
                case (phase)
                    0: begin
                        history = {history[2:0], d};
                        if (seen < 4) seen = seen + 1;
                        if (seen >= 4 && history == 4'b1101) begin
                            phase = 1; remaining = 4;
                        end
                    end
                    1: begin
                        remaining = remaining - 1;
                        if (remaining == 0) phase = 2;
                    end
                    2: if (c) phase = 3;
                    3: if (a) begin
                        phase = 0; seen = 0; history = 0;
                    end
                endcase
            end
            cycles = cycles + 1;
            #1;
            check_outputs();
        end
    endtask

    task automatic start_pattern;
        begin
            tick(0,1,0,0); tick(0,1,0,0);
            tick(0,0,0,0); tick(0,1,0,0);
        end
    endtask

    initial begin
        tick(1,0,0,0);
        // Long runs of ones exercise overlapping prefix detection.
        tick(0,1,1,1); tick(0,1,1,1); tick(0,1,1,1);
        tick(0,1,1,1); tick(0,0,1,1); tick(0,1,1,1);
        for (i=0; i<4; i=i+1) tick(0,i%2,1,1);
        tick(0,0,1,1); // counting must still have occupied one full cycle
        tick(0,1,0,0); tick(0,0,0,0); // done persists
        tick(0,1,0,1); // ack bit must not seed next search
        tick(0,1,0,0); tick(0,0,0,0); tick(0,1,0,0);
        tick(1,0,0,0);
        start_pattern();
        for (i=0; i<4; i=i+1) tick(0,1,0,0);
        for (i=0; i<8; i=i+1) tick(0,i%2,0,1);
        tick(0,0,1,0);
        for (i=0; i<5; i=i+1) tick(0,1,1,0);
        tick(0,0,0,1);
        // Reset at every shift position and in count/notification phases.
        for (j=0; j<6; j=j+1) begin
            tick(1,1,1,1);
            start_pattern();
            for (i=0; i<j; i=i+1) tick(0,1,1,0);
            tick(1,1,1,1);
            tick(0,0,1,1);
        end
        // Exhaustive short serial windows, each starting from reset.
        for (j=0; j<256; j=j+1) begin
            tick(1,0,0,0);
            stream = j;
            for (i=7; i>=0; i=i-1) tick(0,stream[i],0,0);
            for (i=0; i<6; i=i+1) tick(0,0,1,0);
            tick(0,0,0,1);
        end
        // Repeated transactions and randomized reset/control interaction.
        for (i=0; i<3000; i=i+1)
            tick(($urandom_range(0,49)==0), $urandom_range(0,1),
                 $urandom_range(0,1), $urandom_range(0,1));
        $display("PASS independent FSM checks: %0d cycles", cycles);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "timeout");
    end
endmodule
