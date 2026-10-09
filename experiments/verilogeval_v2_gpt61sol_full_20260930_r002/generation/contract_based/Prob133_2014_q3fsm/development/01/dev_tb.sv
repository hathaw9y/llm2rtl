`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic s = 0;
    logic w = 0;
    wire z;
    TopModule dut (.clk(clk), .reset(reset), .s(s), .w(w), .z(z));
    always #5 clk = ~clk;

    bit active = 0;
    bit established = 0;
    bit expected = 0;
    integer sample_index = 0;
    integer window_sum = 0;
    integer checks = 0;
    integer p, q, j, k;
    logic [31:0] stream = 32'h75e1a6c9;

    // Oracle uses the textual three-sample window rather than DUT states.
    always @(posedge clk) begin
        if (reset) begin
            active = 0;
            established = 1;
            sample_index = 0;
            window_sum = 0;
            expected = 0;
        end else if (established) begin
            expected = 0;
            if (!active) begin
                if (s) active = 1;
            end else begin
                window_sum = window_sum + (w ? 1 : 0);
                sample_index = sample_index + 1;
                if (sample_index == 3) begin
                    expected = (window_sum == 2);
                    sample_index = 0;
                    window_sum = 0;
                end
            end
        end
        #1;
        if (established) begin
            checks = checks + 1;
            if (z !== expected)
                $fatal(1, "Mismatch t=%0t z=%b expected=%b sample=%0d sum=%0d", $time, z, expected, sample_index, window_sum);
        end
    end

    task automatic cycle(input bit r, input bit sv, input bit wv);
        @(negedge clk);
        reset = r;
        s = sv;
        w = wv;
        // Changes to reset and data must not change a synchronous output.
        #1;
        if (established && z !== expected)
            $fatal(1, "Output changed between clock edges at %0t", $time);
        @(posedge clk);
        #2;
    endtask

    initial begin
        cycle(1, 1, 1);
        repeat (5) cycle(0, 0, 1);
        // Exhaust all ordered adjacent windows, including every pulse transition.
        for (p = 0; p < 8; p = p + 1) begin
            for (q = 0; q < 8; q = q + 1) begin
                cycle(1, 0, 0);
                cycle(0, 1, 1); // w on entry is excluded.
                for (j = 0; j < 3; j = j + 1)
                    cycle(0, (j % 2), ((p >> j) & 1));
                for (j = 0; j < 3; j = j + 1)
                    cycle(0, 0, ((q >> j) & 1));
                cycle(0, 1, 0); // prior result must clear while next window starts.
            end
        end
        // Interrupt each possible partial window and completed pulse with reset.
        for (k = 0; k <= 3; k = k + 1) begin
            cycle(1, 0, 0);
            cycle(0, 1, 0);
            for (j = 0; j < k; j = j + 1)
                cycle(0, 0, (j < 2));
            cycle(1, 1, 1);
            repeat (4) cycle(0, 0, 1);
            cycle(0, 1, 1);
            cycle(0, 0, 1);
            cycle(0, 0, 0);
            cycle(0, 0, 1);
        end
        for (j = 0; j < 600; j = j + 1) begin
            stream = {stream[30:0], stream[31] ^ stream[21] ^ stream[1] ^ stream[0]};
            cycle(0, stream[4], stream[0]);
        end
        cycle(1, 0, 0);
        $display("PASS independent FSM window verification: %0d comparisons", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
