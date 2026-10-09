`timescale 1ns/1ps
module tb_smollm2_perf_counters;
    logic aclk=0, aresetn=0, clear=0;
    logic [18:0] events=0;
    logic load_valid=0, load_ready=0, store_valid=0, store_ready=0;
    logic [15:0] load_keep=0, store_keep=0;
    logic [6:0] read_index=0;
    logic [15:0] read_value;
    always #5 aclk=~aclk;
    smollm2_perf_counters dut (.*);
    task automatic expect_count(input integer metric, input logic [63:0] expected);
        logic [63:0] actual;
        actual=0;
        for(integer i=0;i<4;i++) begin
            read_index=7'(metric*4+i); #1;
            actual[i*16+:16]=read_value;
        end
        if(actual !== expected) $fatal(1,"metric %0d actual=%h expected=%h",metric,actual,expected);
    endtask
    initial begin
        repeat(2) @(negedge aclk); aresetn=1;
        events[0]=1; events[1]=1; events[3]=1; events[18]=1;
        load_valid=1; load_ready=1; load_keep='1;
        store_valid=1; store_ready=0; store_keep='1;
        repeat(3) @(negedge aclk);
        // Partial keep, stalled load, and accepted STORE.
        load_ready=0; store_ready=1; store_keep=16'h001f;
        events[10]=1; events[14]=1; events[16]=1;
        repeat(2) @(negedge aclk);
        events=0;
        expect_count(0,5); expect_count(1,5); expect_count(3,5);
        expect_count(10,2); expect_count(14,2); expect_count(16,2);
        expect_count(19,48); expect_count(20,10);
        expect_count(21,2); expect_count(22,3); expect_count(23,5);
        // Counters freeze after DONE even if stream pins remain asserted.
        repeat(5) @(negedge aclk); expect_count(0,5); expect_count(20,10);
        // Read all 64 bits, including a value above 32 bits.
        dut.count[4]=64'h123456789abcdef0; expect_count(4,64'h123456789abcdef0);
        @(negedge aclk); clear=1; events='1;
        @(negedge aclk); clear=0; events=0;
        for(integer i=0;i<24;i++) expect_count(i,0);
        read_index=127; #1; if(read_value !== 0) $fatal(1,"invalid read");
        $display("PASS perf counters overlap/byte-keep/stall/freeze/clear/64-bit read");
        $finish;
    end
    initial begin #10000; $fatal(1,"timeout"); end
endmodule
