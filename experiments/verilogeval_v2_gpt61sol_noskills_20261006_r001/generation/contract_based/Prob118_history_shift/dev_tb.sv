`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg predict_valid = 0, predict_taken = 0;
    reg train_mispredicted = 0, train_taken = 0;
    reg [31:0] train_history = 0;
    wire [31:0] predict_history;
    reg [31:0] expected;
    reg [31:0] next_expected;
    integer checks = 0;
    integer i, j;
    reg [31:0] rng = 32'h79ac1234;
    TopModule dut(.*);
    always #5 clk = ~clk;

    task check;
        begin
            if (predict_history !== expected)
                $fatal(1, "At %0t expected %h got %h", $time, expected, predict_history);
            checks = checks + 1;
        end
    endtask

    task cycle(input reg pv, input reg pt, input reg tm,
               input reg tt, input reg [31:0] th);
        begin
            @(negedge clk);
            predict_valid = pv;
            predict_taken = pt;
            train_mispredicted = tm;
            train_taken = tt;
            train_history = th;
            #1;
            check();
            next_expected = expected;
            if (areset) next_expected = 0;
            else if (tm) begin
                for (j = 1; j < 32; j = j + 1)
                    next_expected[j] = th[j-1];
                next_expected[0] = tt;
            end else if (pv) begin
                for (j = 1; j < 32; j = j + 1)
                    next_expected[j] = expected[j-1];
                next_expected[0] = pt;
            end
            @(posedge clk);
            expected = next_expected;
            #1;
            check();
        end
    endtask

    initial begin
        #2; areset = 1; expected = 0;
        #1; check();
        cycle(1, 1, 1, 1, 32'hffffffff);
        @(negedge clk); areset = 0; predict_valid = 0; train_mispredicted = 0;
        #1; check();
        cycle(0, 1, 0, 1, 32'hffffffff);
        cycle(1, 1, 0, 0, 0);
        cycle(1, 0, 0, 0, 0);
        cycle(0, 0, 1, 0, 32'h80000000);
        cycle(0, 0, 1, 1, 32'h01234567);
        cycle(1, 0, 1, 1, 32'h89abcdef);
        cycle(1, 1, 1, 0, 32'hffffffff);
        for (i = 0; i < 40; i = i + 1)
            cycle(1, i == 0, 0, 0, 0);
        cycle(0, 0, 1, 1, 32'hffffffff);
        // Assert reset between edges while the register is nonzero.
        #1; areset = 1; expected = 0;
        #1; check();
        cycle(1, 1, 1, 1, 32'hffffffff);
        @(negedge clk); areset = 0; predict_valid = 0; train_mispredicted = 0;
        #1; check();
        for (i = 0; i < 250; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            cycle(rng[0], rng[1], rng[2], rng[3], rng);
        end
        $display("PASS history shift: %0d checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
