`timescale 1ns/1ps
module dev_tb;
    reg clk=0, reset=0, data=0, ack=0;
    wire [3:0] count;
    wire counting, done;
    TopModule dut(.clk(clk), .reset(reset), .data(data), .ack(ack),
                  .count(count), .counting(counting), .done(done));
    // Independent oracle: sliding input window and total cycles remaining.
    integer phase=0, loaded=0, duration=0, remaining=0, cycles=0;
    reg [3:0] history=0;
    task step(input reg d, input reg a, input reg r);
        begin
            clk=0; data=d; ack=a; reset=r;
            #5; clk=1;
            if (r) begin
                phase=0; loaded=0; duration=0; remaining=0; history=0;
            end else begin
                case (phase)
                    0: begin
                        history={history[2:0],d};
                        if (history == 4'b1101) begin
                            phase=1; loaded=0; duration=0;
                        end
                    end
                    1: begin
                        duration=2*duration+d;
                        loaded=loaded+1;
                        if (loaded==4) begin
                            remaining=(duration+1)*1000;
                            phase=2;
                        end
                    end
                    2: begin
                        remaining=remaining-1;
                        if (remaining==0) phase=3;
                    end
                    3: if (a) begin phase=0; history=0; end
                endcase
            end
            #1; cycles=cycles+1;
            if (counting !== (phase==2))
                $fatal(1,"counting mismatch cycle %0d phase %0d",cycles,phase);
            if (done !== (phase==3))
                $fatal(1,"done mismatch cycle %0d phase %0d",cycles,phase);
            if (phase==2 && count !== ((remaining-1)/1000))
                $fatal(1,"count mismatch cycle %0d got %0d remaining %0d",cycles,count,remaining);
            #4; clk=0;
        end
    endtask
    task start_timer(input integer value);
        integer bitno;
        begin
            step(1,0,0); step(1,0,0); step(0,0,0); step(1,0,0);
            for(bitno=3;bitno>=0;bitno=bitno-1)
                step((value >> bitno)&1,0,0);
        end
    endtask
    integer v, i;
    initial begin
        step(0,0,1);
        // False patterns and overlapping prefixes: 111101 triggers once.
        step(1,0,0); step(0,0,0); step(1,0,0); step(0,0,0);
        step(1,0,0); step(1,0,0);
        start_timer(0);
        for(i=0;i<1000;i=i+1) step(i%2,1,0);
        // ack during counting cannot prevent the done indication.
        for(i=0;i<12;i=i+1) step(i%2,0,0);
        step(1,1,0);
        // All delay encodings, including MSB order and both boundaries.
        for(v=0;v<16;v=v+1) begin
            start_timer(v);
            for(i=0;i<(v+1)*1000;i=i+1)
                step((i%7)<4,(i%3)==0,0);
            for(i=0;i<5;i=i+1) step(1,0,0);
            step(1,1,0);
        end
        // Reset interrupts partial pattern, partial load, run, and done.
        step(1,0,0); step(1,0,0); step(0,0,1);
        start_timer(4);
        for(i=0;i<123;i=i+1) step(1,0,0);
        step(1,1,1);
        step(1,0,0); step(1,0,0); step(0,0,0); step(1,0,0);
        step(1,0,0); step(0,0,1);
        start_timer(0);
        for(i=0;i<1000;i=i+1) step(0,0,0);
        step(0,0,1);
        // Reset is synchronous: assertion between edges preserves outputs.
        start_timer(2);
        reset=1; #2;
        if(counting !== 1 || done !== 0 || count !== 2)
            $fatal(1,"reset took effect without a clock edge");
        step(0,0,1);
        for(i=0;i<20;i=i+1) step(0,0,0);
        $display("PASS: all durations, exact cycle boundaries, overlap, ack and resets");
        $finish;
    end
    initial begin
        #2000000; $fatal(1,"Timeout");
    end
endmodule
