`timescale 1ns/1ps
module dev_tb;
    reg clk=0, reset=0, s=0, w=0;
    wire z;
    TopModule dut(.clk(clk), .reset(reset), .s(s), .w(w), .z(z));
    always #5 clk = ~clk;
    integer active=0, samples=0, ones=0, cycles=0;
    reg expected=0;
    integer p,q,k,r;

    // Behavioral oracle: partition post-entry samples into groups of three.
    task tick(input reg rst, input reg start, input reg bit_w);
        begin
            @(negedge clk);
            reset=rst; s=start; w=bit_w;
            #1;
            if (z !== expected) $fatal(1,"Output changed between clock edges at cycle %0d",cycles);
            @(posedge clk);
            if (rst) begin
                active=0; samples=0; ones=0; expected=0;
            end else if (!active) begin
                expected=0;
                if (start) active=1;
            end else begin
                samples=samples+1;
                if (bit_w) ones=ones+1;
                expected=0;
                if (samples==3) begin
                    expected=(ones==2);
                    samples=0; ones=0;
                end
            end
            #1;
            cycles=cycles+1;
            if (z !== expected)
                $fatal(1,"Cycle %0d: z=%b expected=%b reset=%b s=%b w=%b",cycles,z,expected,rst,start,bit_w);
        end
    endtask
    initial begin
        // Establish the specified reset state, then hold A while w toggles.
        @(posedge clk); reset=1;
        #1; // avoid checking uninitialized state before a sampled reset
        tick(1,0,0);
        for(k=0;k<8;k=k+1) tick(0,0,k%2);
        // Exhaust every pair of adjacent groups, including back-to-back hits.
        for(p=0;p<8;p=p+1) begin
            for(q=0;q<8;q=q+1) begin
                tick(1,1,1);
                tick(0,1,1); // entry w must not count
                for(k=0;k<3;k=k+1) tick(0,k%2,(p>>k)&1);
                for(k=0;k<3;k=k+1) tick(0,k%2,(q>>k)&1);
                tick(0,0,0); // pulse must clear on next group's first sample
            end
        end
        // Reset from every sampling phase and from an asserted output.
        for(r=0;r<4;r=r+1) begin
            tick(1,0,0);
            tick(0,1,0);
            for(k=0;k<r;k=k+1) tick(0,0,k<2);
            tick(1,1,1);
            tick(0,0,1);
            tick(0,1,0);
            tick(0,0,1); tick(0,0,1); tick(0,0,0);
        end
        for(k=0;k<1000;k=k+1)
            tick(($urandom_range(0,31)==0),$urandom_range(0,1),$urandom_range(0,1));
        $display("PASS: %0d cycles checked",cycles);
        $finish;
    end
    initial begin
        #30000;
        $fatal(1,"Testbench timeout");
    end
endmodule
