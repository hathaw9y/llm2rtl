`timescale 1ns/1ps
module dev_tb;
logic clk=0,d=0; wire q;
TopModule dut(.clk(clk),.d(d),.q(q));
initial begin
 #2; clk=1; #1; if(q !== 0) $fatal(1,"Expected sampled d=0");
 clk=0; d=1; #2; clk=1; #1; if(q !== 1) $fatal(1,"Expected sampled d=1");
 $display("PASS: debug preflight"); $finish;
end
initial begin #100; $fatal(1,"Timeout"); end
endmodule
