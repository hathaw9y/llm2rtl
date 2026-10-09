`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic train_valid = 0;
    logic train_taken = 0;
    wire [1:0] state;
    integer expected = 1;
    integer checks = 0;
    integer coverage [0:3][0:3];
    integer s, v, t, i, j;
    TopModule dut (.clk(clk), .areset(areset), .train_valid(train_valid),
                   .train_taken(train_taken), .state(state));

    task automatic check_state;
        if (state !== expected[1:0])
            $fatal(1, "FAIL expected=%0d actual=%b", expected, state);
        checks = checks + 1;
    endtask

    task automatic step(input bit valid_value, input bit taken_value);
        train_valid = valid_value;
        train_taken = taken_value;
        #2;
        check_state();
        coverage[expected][2*valid_value+taken_value] = coverage[expected][2*valid_value+taken_value] + 1;
        clk = 1;
        if (areset) expected = 1;
        else if (valid_value) begin
            if (taken_value && expected < 3) expected = expected + 1;
            if (!taken_value && expected > 0) expected = expected - 1;
        end
        #1;
        check_state();
        clk = 0;
        #1;
        check_state();
    endtask

    task automatic reset_counter;
        #2;
        areset = 1;
        expected = 1;
        #1;
        check_state();
        step(1,1);
        step(1,0);
        areset = 0;
        #1;
        check_state();
    endtask

    initial begin
        for (i=0;i<4;i=i+1)
            for (j=0;j<4;j=j+1) coverage[i][j] = 0;
        reset_counter();
        for (s=0;s<4;s=s+1) begin
            for (v=0;v<2;v=v+1) begin
                for (t=0;t<2;t=t+1) begin
                    reset_counter();
                    if (s == 0) step(1,0);
                    for (i=1;i<s;i=i+1) step(1,1);
                    step(v != 0,t != 0);
                end
            end
        end
        for (i=0;i<10;i=i+1) step(1,1);
        for (i=0;i<10;i=i+1) step(1,0);
        for (i=0;i<20;i=i+1) step(0,i%2);
        reset_counter();
        for (i=0;i<4;i=i+1)
            for (j=0;j<4;j=j+1)
                if (coverage[i][j] == 0) $fatal(1,"FAIL missing transition coverage %0d %0d", i,j);
        $display("PASS checks=%0d all 16 state/input combinations covered", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1,"FAIL simulation timeout");
    end
endmodule
