module dev_tb;
    logic clk=0, reset=0, s=0, w=0;
    wire z;
    TopModule dut(.clk(clk), .reset(reset), .s(s), .w(w), .z(z));
    always #5 clk=~clk;
    bit active=0;
    bit samples[0:2];
    bit expected=0;
    integer n=0, checks=0, total;
    integer a,b,i,j;
    logic [31:0] rng=32'h81234567;
    task automatic step(input bit rst, input bit ss, input bit ww);
        @(negedge clk);
        reset=rst; s=ss; w=ww;
        #1;
        if (z !== expected) $fatal(1,"Output changed between edges");
        @(posedge clk);
        expected=0;
        if (rst) begin active=0; n=0; end
        else if (!active) begin
            if(ss) begin active=1; n=0; end
        end else begin
            samples[n]=ww;
            n=n+1;
            if(n==3) begin
                total=0;
                for(integer k=0;k<3;k=k+1) if(samples[k]) total=total+1;
                expected=(total==2);
                n=0;
            end
        end
        #1;
        checks=checks+1;
        if(z !== expected) $fatal(1,"Mismatch check=%0d expected=%b actual=%b",checks,expected,z);
    endtask
    initial begin
        step(1,0,0);
        for(i=0;i<8;i=i+1) step(0,0,i[0]);
        for(a=0;a<8;a=a+1) begin
            for(b=0;b<8;b=b+1) begin
                step(1,0,0);
                step(0,1,1);
                for(i=0;i<3;i=i+1) step(0,i[0],(a>>i)&1);
                for(i=0;i<3;i=i+1) step(0,0,(b>>i)&1);
                step(0,1,0);
            end
        end
        for(j=0;j<4;j=j+1) begin
            step(1,1,1); step(0,1,0);
            for(i=0;i<j;i=i+1) step(0,0,i<2);
            step(1,1,1); step(0,0,1); step(0,1,1);
            step(0,0,1); step(0,0,1); step(0,0,0);
            step(1,0,0);
        end
        for(i=0;i<3000;i=i+1) begin
            rng=rng ^ (rng<<13); rng=rng ^ (rng>>17); rng=rng ^ (rng<<5);
            step(rng[7:2]==0,rng[0],rng[1]);
        end
        $display("PASS: %0d cycle and between-edge checks",checks);
        $finish;
    end
    initial begin #100000; $fatal(1,"Testbench timeout"); end
endmodule
