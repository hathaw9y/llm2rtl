`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic x = 0;
    wire z;
    integer model;
    integer transitions [0:4][0:1];
    integer coverage [0:4][0:1];
    integer resets [0:4][0:1];
    integer seq, bitidx, st, inp;
    bit initialized = 0;
    TopModule dut (.clk(clk), .reset(reset), .x(x), .z(z));
    always #5 clk = ~clk;

    task automatic check_output;
        logic expected;
        begin
            expected = (model == 3 || model == 4);
            if (z !== expected)
                $fatal(1, "z mismatch time=%0t state=%0d expected=%b actual=%b", $time, model, expected, z);
        end
    endtask

    task automatic step(input bit r, input bit value);
        begin
            @(negedge clk);
            reset = r;
            x = value;
            #1;
            // Neither input changes nor synchronous reset may change Moore output.
            if (initialized) check_output();
            @(posedge clk);
            if (r) begin
                if (initialized) resets[model][value] = resets[model][value] + 1;
                model = 0;
                initialized = 1;
            end else begin
                coverage[model][value] = coverage[model][value] + 1;
                model = transitions[model][value];
            end
            #1;
            check_output();
        end
    endtask

    task automatic reach(input integer target);
        begin
            step(1,0);
            if (target != 0) step(0,1); // 000 -> 001
            if (target == 4 || target == 3 || target == 2) step(0,1); // -> 100
            if (target == 3 || target == 2) step(0,0); // -> 011
            if (target == 2) step(0,1); // -> 010
            if (model != target) $fatal(1,"TB reach error");
        end
    endtask

    initial begin
        transitions[0][0]=0; transitions[0][1]=1;
        transitions[1][0]=1; transitions[1][1]=4;
        transitions[2][0]=2; transitions[2][1]=1;
        transitions[3][0]=1; transitions[3][1]=2;
        transitions[4][0]=3; transitions[4][1]=4;
        for (st=0;st<5;st=st+1)
            for (inp=0;inp<2;inp=inp+1) begin
                coverage[st][inp]=0;
                resets[st][inp]=0;
            end
        step(1,1);
        step(1,0);
        for (st=0;st<5;st=st+1)
            for (inp=0;inp<2;inp=inp+1) begin
                reach(st);
                step(0,inp != 0);
                reach(st);
                step(1,inp != 0);
            end
        for (seq=0;seq<256;seq=seq+1) begin
            step(1,0);
            for (bitidx=0;bitidx<8;bitidx=bitidx+1)
                step(0,((seq >> bitidx) & 1) != 0);
        end
        for (st=0;st<5;st=st+1)
            for (inp=0;inp<2;inp=inp+1) begin
                if (coverage[st][inp]==0) $fatal(1,"Missing transition coverage");
                if (resets[st][inp]==0) $fatal(1,"Missing reset coverage");
            end
        $display("PASS all legal transitions, synchronous resets, Moore sampling, and exhaustive 8-bit histories");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Timeout");
    end
endmodule
