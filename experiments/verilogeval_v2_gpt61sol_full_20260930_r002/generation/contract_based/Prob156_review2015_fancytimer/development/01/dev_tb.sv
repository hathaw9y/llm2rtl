`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0, data = 0, ack = 0;
    wire [3:0] count;
    wire counting, done;
    TopModule dut(.*);
    always #5 clk = ~clk;

    // Reference uses a sliding pattern window and absolute remaining time,
    // independently of the DUT prefix FSM and modulo-1000 counter.
    integer phase = 0; // search, capture, timer, completed
    integer window = 0, seen = 0, captured = 0, duration = 0;
    integer remaining = 0, steps = 0;
    integer d, i;
    task automatic step(input bit rst, input bit serial_bit, input bit acknowledge);
        begin
            @(negedge clk);
            reset = rst;
            data = serial_bit;
            ack = acknowledge;
            @(posedge clk);
            if (rst) begin
                phase = 0;
                window = 0;
                seen = 0;
                captured = 0;
                duration = 0;
                remaining = 0;
            end else begin
                case (phase)
                    0: begin
                        window = ((window * 2) + serial_bit) % 16;
                        if (seen < 4) seen = seen + 1;
                        if (seen == 4 && window == 13) begin
                            phase = 1;
                            captured = 0;
                            duration = 0;
                        end
                    end
                    1: begin
                        duration = duration * 2 + serial_bit;
                        captured = captured + 1;
                        if (captured == 4) begin
                            remaining = (duration + 1) * 1000;
                            phase = 2;
                        end
                    end
                    2: begin
                        remaining = remaining - 1;
                        if (remaining == 0) phase = 3;
                    end
                    3: if (acknowledge) begin
                        phase = 0;
                        window = 0;
                        seen = 0;
                    end
                endcase
            end
            #1;
            steps = steps + 1;
            if (counting !== (phase == 2))
                $fatal(1, "counting mismatch step=%0d phase=%0d remaining=%0d", steps, phase, remaining);
            if (done !== (phase == 3))
                $fatal(1, "done mismatch step=%0d phase=%0d", steps, phase);
            if (phase == 2 && count !== ((remaining - 1) / 1000))
                $fatal(1, "count mismatch step=%0d got=%0d expected=%0d", steps, count, (remaining-1)/1000);
        end
    endtask
    task automatic start_timer(input integer delay_value);
        integer b;
        begin
            step(0,1,0); step(0,1,0); step(0,0,0); step(0,1,0);
            for (b=3; b>=0; b=b-1) step(0, (delay_value >> b) & 1, 0);
            if (phase != 2) $fatal(1,"stimulus did not start timer");
        end
    endtask
    initial begin
        step(1,0,0);
        // Reset is synchronous: toggling it between edges must not change outputs.
        @(negedge clk); reset = 0;
        #1; reset = 1;
        #1;
        if (counting !== 0 || done !== 0) $fatal(1,"idle outputs changed");
        reset = 0;
        // Near misses and long overlapping prefixes: final 1101 starts capture.
        step(0,0,0); step(0,1,0); step(0,0,0); step(0,0,0);
        step(0,1,0); step(0,1,0); step(0,1,0); step(0,1,0);
        step(0,0,0); step(0,1,0);
        step(0,0,0); step(0,0,0); step(0,0,0); step(0,0,0);
        for(i=0;i<1000;i=i+1) step(0,(i%4)!=2,1);
        for(i=0;i<12;i=i+1) step(0,(i%4)!=2,0);
        step(0,1,1);
        for(d=0;d<16;d=d+1) begin
            start_timer(d);
            for(i=0;i<(d+1)*1000;i=i+1) step(0,(i%4)!=2,(i%7)==0);
            for(i=0;i<5;i=i+1) step(0,1,0);
            step(0,1,1);
        end
        // Cancel partial search and partial duration, then restart.
        step(0,1,0); step(0,1,0); step(1,1,1);
        step(0,0,0); step(0,1,0); step(0,1,0); step(0,0,0); step(0,1,0);
        step(0,1,0); step(0,0,0); step(1,0,0);
        start_timer(15);
        for(i=0;i<1003;i=i+1) step(0,1,1);
        // Assert reset away from an active edge and prove synchronous behavior.
        @(negedge clk); reset=1;
        #1;
        if (counting !== 1 || done !== 0 || count !== 14)
            $fatal(1,"reset acted asynchronously");
        reset=0;
        step(1,1,1);
        start_timer(0);
        for(i=0;i<1000;i=i+1) step(0,0,0);
        step(1,1,0); // reset while done
        start_timer(0);
        for(i=0;i<1000;i=i+1) step(0,1,1);
        step(0,0,1);
        $display("PASS all delays, boundaries, search overlap, ack and reset; %0d checked edges",steps);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1,"bounded timeout");
    end
endmodule
