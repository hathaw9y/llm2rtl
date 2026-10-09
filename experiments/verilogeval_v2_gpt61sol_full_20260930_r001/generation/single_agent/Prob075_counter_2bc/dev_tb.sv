`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic train_valid = 0;
    logic train_taken = 0;
    wire [1:0] state;
    integer expected;
    integer checks = 0;
    TopModule dut (.*);
    always #5 clk = ~clk;

    task automatic check_state(input integer value);
        if (state !== value[1:0])
            $fatal(1, "state=%b expected=%0d at %0t", state, value, $time);
        checks = checks + 1;
    endtask

    task automatic step(input bit valid_bit, input bit taken_bit);
        @(negedge clk);
        train_valid = valid_bit;
        train_taken = taken_bit;
        #1;
        check_state(expected);
        @(posedge clk);
        if (valid_bit) begin
            if (taken_bit && expected < 3) expected = expected + 1;
            if (!taken_bit && expected > 0) expected = expected - 1;
        end
        #1;
        check_state(expected);
    endtask

    task automatic reset_counter;
        @(negedge clk);
        #2;
        areset = 1;
        expected = 1;
        #1;
        check_state(expected);
        @(posedge clk);
        #1;
        check_state(expected);
        @(negedge clk);
        areset = 0;
        #1;
        check_state(expected);
    endtask

    initial begin
        reset_counter();
        // Exercise every state with both hold values and both directions.
        for (integer starting = 0; starting < 4; starting = starting + 1) begin
            for (integer valid_bit = 0; valid_bit < 2; valid_bit = valid_bit + 1) begin
                for (integer taken_bit = 0; taken_bit < 2; taken_bit = taken_bit + 1) begin
                    reset_counter();
                    step(1, 0);
                    for (integer advance = 0; advance < starting; advance = advance + 1)
                        step(1, 1);
                    step(valid_bit, taken_bit);
                end
            end
        end
        repeat (8) step(1, 1);
        repeat (8) step(1, 0);
        train_valid = 1;
        train_taken = 1;
        reset_counter();
        step(1, 1);
        $display("PASS: %0d state checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "testbench timeout");
    end
endmodule
