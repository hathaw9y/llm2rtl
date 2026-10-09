`timescale 1ns/1ps
module dev_tb;
    logic clk=0, reset=0, data=0, ack=0;
    wire [3:0] count;
    wire counting, done;
    integer checks=0;
    TopModule dut(.clk(clk),.reset(reset),.data(data),.count(count),.counting(counting),.done(done),.ack(ack));
    always #5 clk=~clk;
    initial begin #3000000; $fatal(1,"watchdog timeout"); end
    task tick(input bit d, input bit a, input bit r);
        @(negedge clk); data=d; ack=a; reset=r;
        @(posedge clk); #1;
    endtask
    task expect_status(input bit c, input bit dn);
        checks=checks+1;
        if (counting !== c || done !== dn)
            $fatal(1,"status mismatch at %0t: counting=%b done=%b expected=%b,%b",$time,counting,done,c,dn);
    endtask
    task reset_dut;
        tick(0,0,1); expect_status(0,0);
        tick(0,0,0); expect_status(0,0);
    endtask
    task start_capture;
        // Extra leading ones exercise overlapping candidate prefixes.
        tick(1,0,0); expect_status(0,0);
        tick(1,0,0); expect_status(0,0);
        tick(1,0,0); expect_status(0,0);
        tick(0,0,0); expect_status(0,0);
        tick(1,0,0); expect_status(0,0);
    endtask
    task load_delay(input integer delay_value);
        for(integer b=3;b>=0;b=b-1) begin
            tick((delay_value >> b)&1,1,0);
            expect_status(b==0,0);
        end
        if(count !== delay_value[3:0]) $fatal(1,"wrong MSB-first delay capture");
    endtask
    task check_timer(input integer delay_value);
        integer expected;
        for(integer k=0;k<1000*(delay_value+1);k=k+1) begin
            expected=delay_value-k/1000;
            expect_status(1,0);
            checks=checks+1;
            if(count !== expected[3:0])
                $fatal(1,"delay=%0d cycle=%0d count=%0d expected=%0d",delay_value,k,count,expected);
            // Input includes start patterns; acknowledgments must be ignored.
            tick((k%4 != 2),(k%7==0),0);
        end
        expect_status(0,1);
        repeat(12) begin tick(1,0,0); expect_status(0,1); end
        tick(1,1,0); expect_status(0,0);
        // Ack edge's data must not become a prefix. Following 101 must not start capture.
        tick(1,0,0); expect_status(0,0);
        tick(0,0,0); expect_status(0,0);
        tick(1,0,0); expect_status(0,0);
        repeat(4) begin tick(0,0,0); expect_status(0,0); end
    endtask
    initial begin
        reset_dut();
        // Repeated transactions without reset cover all legal numeric values.
        for(integer d=0;d<16;d=d+1) begin
            start_capture(); load_delay(d); check_timer(d);
        end
        // Reset partial search history.
        tick(1,0,0); tick(1,0,0); tick(0,0,0);
        reset_dut();
        tick(1,0,0); repeat(4) begin tick(0,0,0); expect_status(0,0); end
        // Reset during capture.
        start_capture(); tick(1,0,0); tick(0,0,0); reset_dut();
        start_capture(); load_delay(15); repeat(1234) tick(1,1,0);
        // Reset during counting.
        reset_dut(); start_capture(); load_delay(0);
        repeat(1000) tick(0,0,0); expect_status(0,1);
        // Reset from done.
        reset_dut(); start_capture(); load_delay(0); check_timer(0);
        // Synchronous reset must not affect outputs until an active edge.
        start_capture(); load_delay(2);
        @(negedge clk); reset=1; #1; expect_status(1,0);
        @(posedge clk); #1; expect_status(0,0);
        $display("PASS: all delays, cycle boundaries, overlaps, repeated transactions, ignored inputs, done/ack and reset; %0d checks",checks);
        $finish;
    end
endmodule
