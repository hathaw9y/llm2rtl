`timescale 1ns/1ps
module dev_tb;
    logic clk=0, L=0, q_in=0, r_in=0;
    wire Q;
    logic expected;
    integer checks=0;
    TopModule dut(.clk(clk), .L(L), .q_in(q_in), .r_in(r_in), .Q(Q));
    initial begin
        #1;
        if (Q !== 1'bx) $fatal(1,"Unexpected initialization");
        for (integer repeat_idx=0; repeat_idx<4; repeat_idx=repeat_idx+1) begin
            for (integer combo=0; combo<8; combo=combo+1) begin
                {L,q_in,r_in}=combo[2:0];
                #2;
                if (checks>0 && Q !== expected) $fatal(1,"Changed without rising edge");
                expected = L ? r_in : q_in;
                clk=1;
                #1;
                if (Q !== expected) $fatal(1,"Mux capture mismatch combo=%0d",combo);
                checks=checks+1;
                {L,q_in,r_in}=~combo[2:0];
                #1;
                if (Q !== expected) $fatal(1,"Input change altered register");
                clk=0;
                #1;
                if (Q !== expected) $fatal(1,"Falling edge altered register");
            end
        end
        $display("PASS: %0d exhaustive captures plus hold checks",checks);
        $finish;
    end
    initial begin #1000; $fatal(1,"Timeout"); end
endmodule
