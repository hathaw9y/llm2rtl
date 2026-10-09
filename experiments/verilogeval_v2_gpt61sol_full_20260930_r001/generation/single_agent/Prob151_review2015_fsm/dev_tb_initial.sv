`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset, data, done_counting, ack;
    wire shift_ena, counting, done;
    TopModule dut (.*);
    always #5 clk = ~clk;
    integer phase = 0;
    integer remaining = 0;
    integer history_length = 0;
    logic [3:0] history = 0;
    integer checks = 0;
    integer seed = 32'h158713;

    task automatic step(input logic r, d, c, a);
        begin
            @(negedge clk);
            reset = r; data = d; done_counting = c; ack = a;
            @(posedge clk);
            if (r) begin
                phase = 0; remaining = 0; history = 0; history_length = 0;
            end else begin
                case (phase)
                    0: begin
                        history = {history[2:0], d};
                        if (history_length < 4) history_length = history_length + 1;
                        if (history_length == 4 && history == 4'b1101) begin
                            phase = 1; remaining = 4;
                        end
                    end
                    1: begin
                        remaining = remaining - 1;
                        if (remaining == 0) phase = 2;
                    end
                    2: if (c) phase = 3;
                    3: if (a) begin
                        phase = 0; history = 0; history_length = 0;
                    end
                endcase
            end
            #1;
            if ({shift_ena,counting,done} !== {phase == 1,phase == 2,phase == 3})
                $fatal(1,"Mismatch at check %0d: phase %0d outputs %b%b%b", checks,phase,shift_ena,counting,done);
            checks = checks + 1;
        end
    endtask

    initial begin
        reset = 0; data = 0; done_counting = 0; ack = 0;
        step(1,0,0,0);
        // Extra leading ones exercise overlapping pattern prefixes.
        step(0,1,0,0); step(0,1,0,0); step(0,1,0,0);
        step(0,0,0,0); step(0,1,0,0);
        repeat (4) step(0,1,1,1);
        repeat (3) step(0,1,0,1);
        step(0,0,1,1);
        repeat (3) step(0,1,0,0);
        step(0,1,1,1);
        // Reset from each successive point of a transaction.
        for (integer j = 0; j < 12; j = j + 1) begin
            step(1,0,0,0);
            step(0,1,0,0); step(0,1,0,0);
            step(0,0,0,0); step(0,1,0,0);
            repeat (j) step(0,0,1,0);
            step(1,1,1,1);
        end
        repeat (5000) begin
            step(($random(seed) & 255) == 0,
                 ($random(seed) & 1) != 0,
                 ($random(seed) & 7) == 0,
                 ($random(seed) & 7) == 0);
        end
        $display("PASS: %0d cycle checks",checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Testbench timeout");
    end
endmodule
