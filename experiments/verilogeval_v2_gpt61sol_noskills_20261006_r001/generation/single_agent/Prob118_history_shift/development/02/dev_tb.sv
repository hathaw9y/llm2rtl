`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg areset = 0;
    reg predict_valid = 0;
    reg predict_taken = 0;
    reg train_mispredicted = 0;
    reg train_taken = 0;
    reg [31:0] train_history = 0;
    wire [31:0] predict_history;
    reg [31:0] expected;
    reg [31:0] random_bits;
    integer checks = 0;
    integer i;
    TopModule dut (.*);
    always #5 clk = ~clk;

    task check;
        begin
            checks = checks + 1;
            if (predict_history !== expected)
                $fatal(1, "Mismatch at %0t: expected %h got %h", $time, expected, predict_history);
        end
    endtask

    // Arithmetic oracle: oldest bit falls off a 32-bit history;
    // the new branch direction occupies bit zero.
    task cycle(input reg pv, input reg pt, input reg tm,
               input reg tt, input reg [31:0] th);
        begin
            @(negedge clk);
            predict_valid = pv;
            predict_taken = pt;
            train_mispredicted = tm;
            train_taken = tt;
            train_history = th;
            #1; check(); // Inputs alone must not change state.
            @(posedge clk);
            if (areset) expected = 0;
            else if (tm) expected = th * 32'd2 + tt;
            else if (pv) expected = expected * 32'd2 + pt;
            #1; check();
        end
    endtask

    initial begin
        #2;
        areset = 1;
        expected = 0;
        #1; check(); // Async reset between clock edges.
        @(negedge clk);
        areset = 0;
        cycle(0, 1, 0, 1, 32'hffffffff);
        cycle(1, 1, 0, 0, 0);
        cycle(1, 0, 0, 0, 0);
        cycle(0, 0, 0, 0, 0);
        cycle(0, 0, 1, 1, 32'h80000000);
        cycle(1, 0, 1, 1, 32'h12345678);
        cycle(1, 1, 1, 0, 32'hffffffff);
        cycle(0, 1, 1, 0, 32'h00000001);
        for (i = 0; i < 40; i = i + 1)
            cycle(1, 1, 0, 0, 0);
        for (i = 0; i < 40; i = i + 1)
            cycle(1, 0, 0, 0, 0);
        cycle(0, 0, 1, 1, 32'hdeadbeef);
        @(negedge clk);
        #2; areset = 1; expected = 0;
        #1; check();
        cycle(1, 1, 1, 1, 32'hffffffff); // Reset wins both requests.
        @(negedge clk);
        predict_valid = 0;
        train_mispredicted = 0;
        areset = 0;
        for (i = 0; i < 250; i = i + 1) begin
            random_bits = $random;
            cycle(random_bits[0], random_bits[1], random_bits[2],
                  random_bits[3], $random);
        end
        $display("PASS: %0d history checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
