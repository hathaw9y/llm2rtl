`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg [7:0] d = 0;
    wire [7:0] q;
    reg [7:0] expected;
    integer checks = 0;
    integer i;
    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task check_q;
        begin
            if (q !== expected)
                $fatal(1, "Mismatch at time %0t: q=%h expected=%h", $time, q, expected);
            checks = checks + 1;
        end
    endtask

    // Oracle: original specification resets or captures at positive edges only.
    task cycle(input reg r, input reg [7:0] value);
        begin
            reset = r;
            d = value;
            #2; check_q();
            clk = 1;
            if (r) expected = 8'h00;
            else expected = value;
            #1; check_q();
            d = ~value;
            #1; check_q();
            clk = 0;
            #1; check_q();
        end
    endtask

    initial begin
        // Initialization is unspecified; first establish a defined state by reset.
        reset = 1;
        d = 8'hff;
        #2; clk = 1;
        expected = 8'h00;
        #1; check_q();
        clk = 0;
        #1; check_q();
        cycle(0, 8'ha5);
        // Assert and release reset without a rising edge: output must hold.
        reset = 1;
        d = 8'h00;
        #2; check_q();
        reset = 0;
        #2; check_q();
        cycle(0, 8'h5a);
        cycle(1, 8'hff);
        cycle(1, 8'h81);
        cycle(0, 8'hff);
        for (i = 0; i < 256; i = i + 1)
            cycle(0, i[7:0]);
        cycle(1, 8'h7e);
        cycle(0, 8'h01);
        $display("PASS: %0d synchronous DFF checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
