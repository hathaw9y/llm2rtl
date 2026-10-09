`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg in = 0;
    wire disc, flag, err;
    TopModule dut (.clk(clk), .reset(reset), .in(in), .disc(disc), .flag(flag), .err(err));
    always #5 clk = ~clk;
    integer run_length = 0;
    integer checks = 0;
    reg [2:0] expected = 0;
    reg initialized = 0;
    integer stream, bit_index, length, j;

    task check_outputs;
        begin
            if ({disc,flag,err} !== expected)
                $fatal(1, "Mismatch check=%0d run=%0d expected=%b actual=%b", checks, run_length, expected, {disc,flag,err});
            checks = checks + 1;
        end
    endtask

    task sample(input reg value, input reg rst);
        begin
            @(negedge clk);
            in = value;
            reset = rst;
            #1;
            // A synchronous Moore machine must not react to input/reset mid-cycle.
            if (initialized) check_outputs();
            @(posedge clk);
            expected = 3'b000;
            if (rst) run_length = 0;
            else if (value) begin
                if (run_length < 7) run_length = run_length + 1;
                if (run_length >= 7) expected[0] = 1;
            end else begin
                if (run_length == 5) expected[2] = 1;
                if (run_length == 6) expected[1] = 1;
                run_length = 0;
            end
            #1;
            initialized = 1;
            check_outputs();
            #2;
            check_outputs();
        end
    endtask

    initial begin
        sample(1,1);
        sample(0,0);
        // All short binary histories, including overlapping adjacent events.
        for (stream = 0; stream < 1024; stream = stream + 1) begin
            sample(0,1);
            for (bit_index = 9; bit_index >= 0; bit_index = bit_index - 1)
                sample((stream >> bit_index) & 1,0);
        end
        for (length = 0; length <= 20; length = length + 1) begin
            sample(0,0);
            for (j = 0; j < length; j = j + 1) sample(1,0);
            sample(0,0);
            // Reset clears partial runs, saturated errors, and event states.
            sample(1,1);
            for (j = 0; j < 6; j = j + 1) sample(1,0);
            sample(0,0);
            sample(0,1);
        end
        // Explicit reset during each partial/error run.
        for (length = 0; length <= 9; length = length + 1) begin
            sample(0,1);
            for (j = 0; j < length; j = j + 1) sample(1,0);
            sample(0,1);
            sample(1,0);
            sample(0,0);
        end
        sample(0,1);
        for (j = 0; j < 5; j = j + 1) sample(1,0);
        sample(0,0);
        sample(1,1);
        sample(0,0);
        $display("PASS independent HDLC oracle: %0d phase checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1,"Timeout");
    end
endmodule
