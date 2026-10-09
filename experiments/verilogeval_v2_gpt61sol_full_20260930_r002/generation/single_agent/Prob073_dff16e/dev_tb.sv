`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic resetn = 1;
    logic [1:0] byteena = 0;
    logic [15:0] d = 0;
    wire [15:0] q;
    logic [15:0] expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .resetn(resetn), .byteena(byteena), .d(d), .q(q));

    task automatic check_q;
        begin
            if (q !== expected)
                $fatal(1, "Mismatch time=%0t q=%h expected=%h", $time, q, expected);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input logic rn, input logic [1:0] en, input logic [15:0] data);
        begin
            // Inputs change with clock low: synchronous state must hold.
            resetn = rn;
            byteena = en;
            d = data;
            #2;
            check_q();
            clk = 1;
            if (!rn) expected = 16'h0000;
            else begin
                // Independent bit-level oracle from the byte-enable specification.
                for (integer bit_idx = 0; bit_idx < 16; bit_idx = bit_idx + 1)
                    if (en[bit_idx / 8]) expected[bit_idx] = data[bit_idx];
            end
            #1;
            check_q();
            // Toggle payload during high phase, then check the falling edge.
            d = ~data;
            #1;
            check_q();
            clk = 0;
            #1;
            check_q();
        end
    endtask

    initial begin
        // No initialization behavior is required: establish known state by reset.
        resetn = 0;
        byteena = 2'b11;
        d = 16'hffff;
        #2;
        clk = 1;
        expected = 0;
        #1;
        check_q();
        clk = 0;
        #1;
        cycle(1, 2'b11, 16'ha55a);
        cycle(1, 2'b00, 16'hffff);
        cycle(1, 2'b01, 16'h12ff);
        cycle(1, 2'b10, 16'h00aa);
        cycle(1, 2'b01, 16'hff00);
        cycle(1, 2'b10, 16'hff00);
        // Reset must clear both bytes regardless of enables.
        for (integer en = 0; en < 4; en = en + 1) begin
            cycle(1, 2'b11, 16'hffff);
            cycle(0, en[1:0], 16'hffff);
            cycle(1, 2'b00, 16'hffff);
        end
        // Exercise every data bit with all enable masks.
        for (integer bit_idx = 0; bit_idx < 16; bit_idx = bit_idx + 1)
            for (integer en = 0; en < 4; en = en + 1) begin
                cycle(1, 2'b11, 16'h0000);
                cycle(1, en[1:0], 16'h0001 << bit_idx);
                cycle(1, en[1:0], ~(16'h0001 << bit_idx));
            end
        $display("PASS: byte enables, reset priority, and edge semantics (%0d checks)", checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1, "Timeout");
    end
endmodule
