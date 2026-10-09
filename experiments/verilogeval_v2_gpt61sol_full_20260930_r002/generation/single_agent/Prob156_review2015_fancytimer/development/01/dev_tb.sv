`timescale 1ns/1ps
module dev_tb;
    logic clk=0, reset=0, data=0, ack=0;
    wire [3:0] count;
    wire counting, done;
    TopModule dut(.*);
    always #5 clk=~clk;
    integer phase=0, history=0, seen=0, bits_read=0, duration=0;
    integer remaining=0, cycles=0;
    integer d, j, k;
    // Independent oracle: rolling pattern window and total cycles remaining.
    task automatic tick(input bit r, input bit b, input bit a);
        begin
            @(negedge clk);
            reset=r; data=b; ack=a;
            @(posedge clk);
            if (r) begin
                phase=0; history=0; seen=0; bits_read=0;
                duration=0; remaining=0;
            end else begin
                case (phase)
                    0: begin
                        history=((history << 1) | b) & 15;
                        if (seen<4) seen=seen+1;
                        if (seen==4 && history==13) begin
                            phase=1; bits_read=0; duration=0;
                        end
                    end
                    1: begin
                        duration=(duration << 1) | b;
                        bits_read=bits_read+1;
                        if (bits_read==4) begin
                            remaining=(duration+1)*1000; phase=2;
                        end
                    end
                    2: begin
                        remaining=remaining-1;
                        if (remaining==0) phase=3;
                    end
                    3: if (a) begin
                        phase=0; history=0; seen=0;
                    end
                endcase
            end
            #1;
            cycles=cycles+1;
            if (counting !== (phase==2))
                $fatal(1,"counting mismatch cycle %0d phase %0d",cycles,phase);
            if (done !== (phase==3))
                $fatal(1,"done mismatch cycle %0d phase %0d",cycles,phase);
            if (phase==2 && count !== ((remaining-1)/1000))
                $fatal(1,"count mismatch cycle %0d got %0d expected %0d",cycles,count,(remaining-1)/1000);
        end
    endtask
    task automatic start_timer(input integer value);
        begin
            tick(0,1,0); tick(0,1,0); tick(0,0,0); tick(0,1,0);
            for (integer n=3;n>=0;n=n-1) tick(0,(value>>n)&1,0);
        end
    endtask
    initial begin
        tick(1,0,0);
        // False matches and overlapping runs of ones.
        tick(0,1,0); tick(0,0,0); tick(0,1,0); tick(0,0,0);
        tick(0,1,0); tick(0,1,0); tick(0,0,0); tick(0,0,0);
        tick(0,1,0); tick(0,1,0); tick(0,1,0); tick(0,0,0); tick(0,1,0);
        for (j=0;j<4;j=j+1) tick(0,0,0);
        for (j=0;j<1000;j=j+1) tick(0,j%2,1);
        for (j=0;j<7;j=j+1) tick(0,1,0);
        tick(0,1,1);
        for (d=0;d<16;d=d+1) begin
            start_timer(d);
            for (j=0;j<(d+1)*1000;j=j+1)
                tick(0,((j%4)!=2),(j%17)==0);
            for (j=0;j<5;j=j+1) tick(0,j%2,0);
            tick(0,1,1);
        end
        // Reset cancels each partial prefix and each partial duration.
        for (k=0;k<8;k=k+1) begin
            tick(1,0,0);
            for (j=0;j<k;j=j+1) begin
                case(j)
                    2: tick(0,0,0);
                    default: tick(0,1,0);
                endcase
            end
            tick(1,1,1);
            start_timer(0);
            for (j=0;j<1000;j=j+1) tick(0,0,0);
            tick(1,0,0);
        end
        start_timer(15);
        for (j=0;j<1037;j=j+1) tick(0,1,0);
        tick(1,1,1);
        start_timer(0);
        for (j=0;j<1000;j=j+1) tick(0,0,0);
        tick(1,0,0);
        $display("PASS timer directed and boundary checks (%0d cycles)",cycles);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1,"bounded timeout");
    end
endmodule
