`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic x = 1'b0;
    wire z;
    logic [2:0] expected = 3'b000;
    integer cycles = 0;
    TopModule dut (.clk(clk), .x(x), .z(z));

    task automatic step(input logic value);
        logic old_z;
        begin
            x = value;
            old_z = ~(|expected);
            #2;
            if (z !== old_z) $fatal(1, "Output changed before rising edge");
            expected = {expected[2] ^ value,
                        value & ~expected[1], value | ~expected[0]};
            clk = 1'b1;
            #1;
            if (z !== ~(|expected))
                $fatal(1, "Mismatch at cycle %0d: x=%b state=%b z=%b", cycles, x, expected, z);
            clk = 1'b0;
            #1;
            if (z !== ~(|expected)) $fatal(1, "Output changed at falling edge");
            cycles = cycles + 1;
        end
    endtask

    initial begin
        #1;
        if (z !== 1'b1) $fatal(1, "Initial zero state must produce z=1");
        repeat (16) step(1'b0);
        repeat (16) step(1'b1);
        for (integer pattern = 0; pattern < 256; pattern = pattern + 1)
            for (integer bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                step((pattern >> bit_index) & 1);
        $display("PASS: %0d cycles, initial state, all 8-bit input patterns, and edge behavior", cycles);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Testbench timeout");
    end
endmodule
