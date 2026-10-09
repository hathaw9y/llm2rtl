module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic data = 0;
    wire start_shifting;
    logic [3:0] history = 0;
    integer valid_count = 0;
    logic expected = 0;
    integer checks = 0;
    integer stream, bit_index;
    TopModule dut (.clk(clk), .reset(reset), .data(data), .start_shifting(start_shifting));
    always #5 clk = ~clk;

    task automatic step(input logic rst, input logic bit_value);
        @(negedge clk);
        reset = rst;
        data = bit_value;
        @(posedge clk);
        if (rst) begin
            history = 0;
            valid_count = 0;
            expected = 0;
        end else begin
            history = {history[2:0], bit_value};
            if (valid_count < 4) valid_count = valid_count + 1;
            if (valid_count == 4 && history == 4'b1101) expected = 1;
        end
        #1;
        checks = checks + 1;
        if (start_shifting !== expected)
            $fatal(1, "Mismatch check=%0d history=%b reset=%b expected=%b actual=%b", checks, history, rst, expected, start_shifting);
    endtask

    initial begin
        step(1, 1);
        for (stream = 0; stream < 4096; stream = stream + 1) begin
            step(1, 0);
            for (bit_index = 11; bit_index >= 0; bit_index = bit_index - 1)
                step(0, ((stream >> bit_index) & 1));
        end
        // Reset discards a partial prefix and ignores the simultaneous data bit.
        step(1, 0);
        step(0, 1); step(0, 1); step(0, 0);
        step(1, 1);
        step(0, 1); step(0, 0); step(0, 1);
        step(0, 1); step(0, 0); step(0, 1);
        // Found is absorbing, even for long unrelated input runs.
        repeat (32) step(0, 0);
        // Reset changes the output only at a positive clock edge.
        @(negedge clk);
        reset = 1;
        #1;
        if (start_shifting !== 1'b1) $fatal(1, "Reset acted asynchronously");
        @(posedge clk);
        #1;
        if (start_shifting !== 1'b0) $fatal(1, "Synchronous reset failed");
        history = 0; valid_count = 0; expected = 0;
        step(1, 1);
        step(0, 1); step(0, 1); step(0, 0); step(0, 1);
        $display("PASS: %0d oracle comparisons, exhaustive length-12 streams and reset/sticky checks", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Testbench watchdog timeout");
    end
endmodule
