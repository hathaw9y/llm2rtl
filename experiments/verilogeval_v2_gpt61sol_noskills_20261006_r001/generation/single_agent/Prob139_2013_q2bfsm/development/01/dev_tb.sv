`timescale 1ns/1ps
module dev_tb;
    reg clk=0, resetn=0, x=0, y=0;
    wire f,g;
    TopModule dut(.clk(clk), .resetn(resetn), .x(x), .y(y), .f(f), .g(g));
    // Behavioral oracle: pulse phase, rolling sample history, and deadline count.
    integer phase=0, samples=0, y_samples=0, checks=0;
    reg [2:0] history=0;
    reg expected_f=0, expected_g=0;
    integer pattern, mode, k;
    reg old_f, old_g;
    task step(input reg rn, input reg xv, input reg yv);
        begin
            clk=0; resetn=rn; x=xv; y=yv;
            old_f=f; old_g=g;
            #4;
            // Reset and inputs must not alter outputs before a rising edge.
            if (checks>0 && (f !== old_f || g !== old_g))
                $fatal(1,"Output changed between edges");
            clk=1;
            if (!rn) begin
                phase=0; samples=0; history=0; y_samples=0;
                expected_f=0; expected_g=0;
            end else begin
                case (phase)
                    0: begin phase=1; expected_f=1; end
                    1: begin phase=2; expected_f=0; samples=0; history=0; end
                    2: begin
                        history={history[1:0],xv};
                        if (samples<3) samples=samples+1;
                        if (samples>=3 && history==3'b101) begin
                            expected_g=1; phase=3; y_samples=0;
                        end
                    end
                    3: begin
                        y_samples=y_samples+1;
                        if (yv) phase=4;
                        else if (y_samples==2) begin expected_g=0; phase=4; end
                    end
                    4: begin end
                endcase
            end
            #1;
            checks=checks+1;
            if (f !== expected_f || g !== expected_g)
                $fatal(1,"Check %0d rn=%b x=%b y=%b expected f,g=%b%b got=%b%b",checks,rn,xv,yv,expected_f,expected_g,f,g);
            #5; clk=0;
        end
    endtask
    initial begin
        step(0,0,0);
        step(0,1,1);
        // Exhaustive short x streams and both y deadline boundaries.
        for (pattern=0; pattern<256; pattern=pattern+1) begin
            for (mode=0; mode<4; mode=mode+1) begin
                step(0,0,0);
                step(1,1,1); // x in the pulse is ignored
                step(1,0,1); // transition out of pulse also ignores x
                for (k=7; k>=0; k=k-1) begin
                    if (phase==3) begin
                        if (y_samples==0) step(1,pattern[k],mode[0]);
                        else step(1,pattern[k],mode[1]);
                    end else step(1,pattern[k],1);
                end
                // Guarantee a detection if the short stream did not contain one.
                step(1,1,0); step(1,0,0); step(1,1,1);
                if (phase==3 && y_samples==0) step(1,0,mode[0]);
                if (phase==3) step(1,1,mode[1]);
                repeat (4) step(1,1,1);
            end
        end
        // Reset can interrupt pulse, search, the deadline, or a permanent result.
        for (k=0; k<3000; k=k+1)
            step(($urandom_range(0,15)!=0),$urandom_range(0,1),$urandom_range(0,1));
        $display("PASS: %0d FSM checks",checks);
        $finish;
    end
    initial begin #300000; $fatal(1,"Timeout"); end
endmodule
