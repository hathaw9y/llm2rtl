`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic aresetn = 1;
    logic x = 0;
    wire z;
    logic [1:0] history = 0;
    integer count = 0;
    integer checks = 0;
    integer pattern, bit_index;
    TopModule dut (.clk(clk), .aresetn(aresetn), .x(x), .z(z));

    task automatic check_output;
        logic expected;
        begin
            expected = (count >= 2) && (history == 2'b10) && x;
            checks = checks + 1;
            if (z !== expected)
                $fatal(1, "Mismatch history=%b count=%0d x=%b z=%b expected=%b", history, count, x, z, expected);
        end
    endtask

    task automatic reset_dut;
        begin
            clk = 0;
            #2;
            aresetn = 0;
            history = 0;
            count = 0;
            #1;
            check_output();
            x = 1;
            #1;
            check_output();
            clk = 1;
            #1;
            check_output();
            clk = 0;
            #1;
            aresetn = 1;
            #1;
            check_output();
        end
    endtask

    task automatic send_bit(input logic value);
        begin
            clk = 0;
            x = value;
            #1;
            check_output();
            // Changing x without a clock must immediately affect the output.
            x = ~value;
            #1;
            check_output();
            x = value;
            #1;
            check_output();
            clk = 1;
            history = {history[0], value};
            if (count < 2) count = count + 1;
            #1;
            check_output();
            clk = 0;
            #1;
        end
    endtask

    initial begin
        for (pattern = 0; pattern < 256; pattern = pattern + 1) begin
            reset_dut();
            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1)
                send_bit((pattern >> bit_index) & 1);
        end
        reset_dut();
        send_bit(1); send_bit(0);
        x = 1;
        #1;
        check_output();
        reset_dut(); // Asynchronous reset while detection is asserted.
        send_bit(1); send_bit(0); send_bit(1); send_bit(0); send_bit(1);
        reset_dut();
        send_bit(1);
        reset_dut(); // Discard a partial prefix.
        send_bit(0); send_bit(1);
        $display("PASS: %0d checks; exhaustive eight-bit streams, overlap, Mealy response, asynchronous reset", checks);
        $finish;
    end
    initial begin
        #30000;
        $fatal(1, "Watchdog timeout");
    end
endmodule
