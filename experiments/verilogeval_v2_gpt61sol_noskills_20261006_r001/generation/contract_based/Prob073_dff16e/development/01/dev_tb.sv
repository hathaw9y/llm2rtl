`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg resetn = 1;
    reg [1:0] byteena = 0;
    reg [15:0] d = 0;
    wire [15:0] q;
    reg [15:0] expected;
    reg established = 0;
    integer checks = 0;
    integer i, mask;
    TopModule dut (.clk(clk), .resetn(resetn), .byteena(byteena), .d(d), .q(q));

    task check_value;
        begin
            if (established) begin
                if (q !== expected)
                    $fatal(1, "Mismatch at %0t: q=%h expected=%h", $time, q, expected);
                checks = checks + 1;
            end
        end
    endtask

    // Drive while clock is low; verify no asynchronous change, then
    // compute the original specification's next stored value bit by bit.
    task cycle(input reg rn, input reg [1:0] en, input reg [15:0] data);
        integer bit_index;
        begin
            resetn = rn;
            byteena = en;
            d = data;
            #2;
            check_value();
            if (!rn) begin
                expected = 0;
                established = 1;
            end else begin
                for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1)
                    if (en[bit_index / 8]) expected[bit_index] = data[bit_index];
            end
            clk = 1;
            #1;
            check_value();
            // Input changes during the high phase cannot update the DFFs.
            d = ~data;
            byteena = ~en;
            resetn = ~rn;
            #1;
            check_value();
            clk = 0;
            #1;
            check_value();
        end
    endtask

    initial begin
        #1;
        // No power-up state is specified: establish it with a clocked reset.
        cycle(0, 0, 16'hffff);
        cycle(1, 3, 16'ha55a);
        cycle(1, 0, 16'hffff);
        cycle(1, 1, 16'h12ff);
        cycle(1, 2, 16'h00ab);
        cycle(1, 3, 16'hffff);
        for (mask = 0; mask < 4; mask = mask + 1) begin
            cycle(1, 3, 16'hffff);
            cycle(0, mask, 16'hffff);
            cycle(1, 0, 16'hffff);
        end
        for (i = 0; i < 16; i = i + 1) begin
            cycle(1, 3, 16'h0000);
            cycle(1, 1, 16'h0001 << i);
            cycle(1, 2, 16'h0001 << i);
            cycle(1, 0, 16'hffff);
        end
        for (i = 0; i < 128; i = i + 1)
            cycle(1, i % 4, (i * 16'h9e37) ^ 16'h5aa5);
        $display("PASS byte-enabled synchronous register: %0d comparisons", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
