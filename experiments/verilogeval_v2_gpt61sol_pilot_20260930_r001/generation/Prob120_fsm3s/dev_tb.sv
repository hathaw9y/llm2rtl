module dev_tb;
    logic clk=0, reset=0, in=0;
    wire out;
    integer refstate=0, checks=0;
    integer coverage [0:7];
    integer seq, k, idx;
    TopModule dut(.clk(clk), .reset(reset), .in(in), .out(out));
    always #5 clk=~clk;
    task automatic step(input bit rst, input bit value);
        integer oldstate;
        begin
            @(negedge clk);
            reset=rst; in=value;
            #1;
            if (out !== (refstate==3)) $fatal(1,"Moore output changed between edges");
            oldstate=refstate;
            @(posedge clk);
            if(rst) refstate=0;
            else begin
                coverage[oldstate*2+value]=coverage[oldstate*2+value]+1;
                // Independent branch-based reference, numbered states.
                if(value) begin
                    if(oldstate==2) refstate=3;
                    else refstate=1;
                end else begin
                    if(oldstate==1 || oldstate==3) refstate=2;
                    else refstate=0;
                end
            end
            #1;
            checks=checks+1;
            if(out !== (refstate==3)) $fatal(1,"Mismatch check %0d",checks);
        end
    endtask
    initial begin
        for(idx=0;idx<8;idx=idx+1) coverage[idx]=0;
        reset=1;
        @(posedge clk); #1;
        if(out!==0) $fatal(1,"Initial reset failed");
        for(seq=0;seq<256;seq=seq+1) begin
            step(1,seq[0]);
            for(k=0;k<8;k=k+1) step(0,seq[k]);
        end
        step(1,0); step(0,1); step(0,0); step(0,1);
        // D output must remain high until clock even when reset asserted.
        @(negedge clk); reset=1; in=1; #1;
        if(out!==1) $fatal(1,"Reset acted asynchronously");
        @(posedge clk); refstate=0; #1;
        if(out!==0) $fatal(1,"Reset priority failed");
        for(idx=0;idx<8;idx=idx+1)
            if(coverage[idx]==0) $fatal(1,"Missing transition %0d",idx);
        $display("PASS checks=%0d all_eight_transitions_covered",checks);
        $finish;
    end
    initial begin #100000; $fatal(1,"Timeout"); end
endmodule
