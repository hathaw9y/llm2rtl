`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg load = 0;
    reg [1:0] ena = 0;
    reg [99:0] data = 0;
    wire [99:0] q;
    reg [99:0] expected;
    reg [99:0] prior;
    reg [99:0] stimulus;
    integer count = 0;
    integer i;
    integer j;
    TopModule dut (.clk(clk), .load(load), .ena(ena), .data(data), .q(q));
    always #5 clk = ~clk;

    task step(input reg ld, input reg [1:0] en, input reg [99:0] value);
        integer bit_index;
        begin
            @(negedge clk);
            prior = expected;
            load = ld;
            ena = en;
            data = value;
            #1;
            if (q !== prior) $fatal(1, "Changed without rising edge at check %0d", count);
            @(posedge clk);
            if (ld) expected = value;
            else if (en == 2'b01) begin
                for (bit_index = 0; bit_index < 100; bit_index = bit_index + 1)
                    expected[bit_index] = prior[(bit_index + 1) % 100];
            end else if (en == 2'b10) begin
                for (bit_index = 0; bit_index < 100; bit_index = bit_index + 1)
                    expected[bit_index] = prior[(bit_index + 99) % 100];
            end
            #1;
            if (q !== expected)
                $fatal(1, "Mismatch check %0d load=%b ena=%b expected=%h actual=%h", count, ld, en, expected, q);
            count = count + 1;
        end
    endtask

    initial begin
        expected = {100{1'bx}};
        // No reset or initialization is specified; do not demand a known startup value.
        step(1, 0, 100'b1);
        step(0, 1, 0); // wrap bit 0 to bit 99
        step(0, 2, 0); // wrap bit 99 to bit 0
        for (i = 0; i < 100; i = i + 1) step(0, 2, 0);
        if (q !== 100'b1) $fatal(1, "Left full revolution failed");
        for (i = 0; i < 100; i = i + 1) step(0, 1, 0);
        if (q !== 100'b1) $fatal(1, "Right full revolution failed");
        for (i = 0; i < 4; i = i + 1) begin
            stimulus = 0;
            stimulus[99-i] = 1;
            stimulus[i] = 1;
            step(1, i, stimulus); // load overrides every enable
            step(0, 0, ~stimulus);
            step(0, 3, ~stimulus);
        end
        step(1, 1, 0);
        step(0, 1, 0);
        step(0, 2, 0);
        step(1, 2, {100{1'b1}});
        step(0, 1, 0);
        step(0, 2, 0);
        for (i = 0; i < 300; i = i + 1) begin
            for (j = 0; j < 100; j = j + 1) stimulus[j] = $random;
            step((i % 13) == 0, i % 4, stimulus);
        end
        $display("PASS rotator: %0d cycle checks", count);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
