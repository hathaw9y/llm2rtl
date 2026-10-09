`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic in = 0;
    wire out;
    logic expected;
    integer sequence_id;
    integer bit_id;
    TopModule dut (.clk(clk), .areset(areset), .in(in), .out(out));
    always #5 clk = ~clk;

    task automatic check_output;
        if (out !== expected)
            $fatal(1, "FAIL expected=%b actual=%b", expected, out);
    endtask

    initial begin
        #2;
        areset = 1;
        expected = 1;
        #1;
        check_output();
        #3;
        check_output();
        @(negedge clk);
        areset = 0;
        for (sequence_id = 0; sequence_id < 256; sequence_id = sequence_id + 1) begin
            // Reset between sequences, away from a rising clock edge.
            #1;
            areset = 1;
            expected = 1;
            #1;
            check_output();
            areset = 0;
            for (bit_id = 0; bit_id < 8; bit_id = bit_id + 1) begin
                in = (sequence_id >> bit_id) & 1;
                #1;
                check_output(); // Moore output must not react to input alone.
                @(posedge clk);
                if (!in) expected = ~expected;
                #1;
                check_output();
                @(negedge clk);
            end
        end
        // Keep reset asserted across several clock edges.
        areset = 1;
        expected = 1;
        repeat (3) begin
            @(posedge clk);
            #1;
            check_output();
        end
        $display("PASS: exhaustive 8-input sequences, asynchronous reset, hold and toggle transitions");
        $finish;
    end
    initial begin
        #30000;
        $fatal(1, "FAIL: timeout");
    end
endmodule
