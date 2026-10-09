`timescale 1ns/1ps
module dev_tb;
    reg clk=0, reset=0, s=0, w=0;
    wire z;
    TopModule dut(.clk(clk), .reset(reset), .s(s), .w(w), .z(z));
    integer active=0, samples=0, ones=0, cycles=0;
    integer p, q, j, phase;
    reg expected=0, valid=0;

    // Each call drives inputs during the low half-cycle and checks both
    // sides of the rising edge. This model counts samples, not DUT states.
    task step(input reg rst, input reg start, input reg sample);
        begin
            clk=0; reset=rst; s=start; w=sample;
            #4;
            if (valid && z !== expected)
                $fatal(1,"Output changed without rising edge at cycle %0d",cycles);
            clk=1;
            if (rst) begin
                active=0; samples=0; ones=0; expected=0; valid=1;
            end else if (!active) begin
                expected=0;
                if (start) active=1;
            end else begin
                ones=ones+sample;
                samples=samples+1;
                expected=0;
                if (samples==3) begin
                    expected=(ones==2);
                    samples=0; ones=0;
                end
            end
            #1;
            cycles=cycles+1;
            if (z !== expected)
                $fatal(1,"Cycle %0d: reset=%b s=%b w=%b expected z=%b got %b",cycles,rst,start,sample,expected,z);
            #5; clk=0;
        end
    endtask

    initial begin
        step(1,0,0);
        // Idle ignores w; transition edge w is excluded.
        for(j=0;j<8;j=j+1) step(0,0,j%2);
        step(0,1,1);
        step(0,0,0); step(0,1,0); step(0,0,0);
        // Exhaustive consecutive groups test boundary timing and all counts.
        for(p=0;p<8;p=p+1) begin
            for(q=0;q<8;q=q+1) begin
                step(1,1,1);
                step(0,1,1);
                for(j=0;j<3;j=j+1) step(0,j%2,(p>>j)&1);
                for(j=0;j<3;j=j+1) step(0,(j+1)%2,(q>>j)&1);
                for(j=0;j<3;j=j+1) step(0,0,0);
            end
        end
        // Reset interrupts each partial-group phase and clears pending result.
        for(phase=0;phase<3;phase=phase+1) begin
            step(1,0,0); step(0,1,0);
            for(j=0;j<phase;j=j+1) step(0,0,1);
            step(1,1,1);
            step(0,0,1); step(0,1,0);
            step(0,0,1); step(0,0,1); step(0,0,0);
        end
        // z is currently high: asserting synchronous reset while low
        // must preserve z until the next rising edge.
        reset=1; #2;
        if(z !== 1) $fatal(1,"Reset acted asynchronously");
        step(1,0,0);
        step(0,0,0);
        $display("PASS: exhaustive groups, entry timing, ignored s, and synchronous resets (%0d cycles)",cycles);
        $finish;
    end
    initial begin
        #20000; $fatal(1,"Bounded timeout");
    end
endmodule
