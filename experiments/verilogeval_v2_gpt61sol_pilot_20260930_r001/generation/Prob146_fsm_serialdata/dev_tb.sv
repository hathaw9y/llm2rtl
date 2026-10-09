module dev_tb;
    logic clk=0, in=1, reset=0;
    wire [7:0] out_byte;
    wire done;
    integer checks=0;
    TopModule dut(.*);
    always #5 clk=~clk;
    task automatic step(input bit b, input bit rst, input bit expected_done, input logic [7:0] expected_byte);
        @(negedge clk); in=b; reset=rst;
        @(posedge clk); #1;
        checks=checks+1;
        if (done !== expected_done) $fatal(1,"done check %0d actual %b expected %b",checks,done,expected_done);
        if (expected_done && out_byte !== expected_byte) $fatal(1,"data check %0d actual %h expected %h",checks,out_byte,expected_byte);
    endtask
    task automatic frame(input logic [7:0] value, input bit good);
        step(0,0,0,0);
        for(integer j=0;j<8;j=j+1) step(value[j],0,0,0);
        step(good,0,good,value);
    endtask
    initial begin
        step(1,1,0,0);
        repeat(4) step(1,0,0,0);
        for(integer n=0;n<256;n=n+1) frame(n[7:0],1);
        step(1,0,0,0);
        frame(8'hA5,0);
        repeat(20) step(0,0,0,0);
        step(1,0,0,0);
        frame(8'h96,1);
        step(0,0,0,0);
        step(1,0,0,0);
        step(0,1,0,0);
        step(1,0,0,0);
        frame(8'h3C,1);
        frame(8'h81,0);
        step(0,1,0,0);
        frame(8'hE7,1);
        step(1,0,0,0);
        $display("PASS checks=%0d all 256 bytes, malformed stop recovery, active/reset recovery",checks);
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
