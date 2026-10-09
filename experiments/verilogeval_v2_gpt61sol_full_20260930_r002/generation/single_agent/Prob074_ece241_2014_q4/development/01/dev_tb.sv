`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    logic x = 1'b0;
    wire z;
    bit [2:0] expected_state = 3'b000;
    integer checks = 0;
    integer sequence_number;
    integer position;
    TopModule dut (.clk(clk), .x(x), .z(z));

    task automatic check_output;
        bit expected_z;
        begin
            expected_z = (expected_state == 3'b000);
            if (z !== expected_z)
                $fatal(1, "Mismatch check=%0d state=%b x=%b clk=%b expected=%b actual=%b",
                       checks, expected_state, x, clk, expected_z, z);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input bit value);
        bit [2:0] next_state;
        begin
            x = value;
            #2;
            check_output();
            // Truth-table oracle for the three original gates.
            if (value) begin
                next_state[0] = !expected_state[0];
                next_state[1] = !expected_state[1];
                next_state[2] = 1'b1;
            end else begin
                next_state[0] = expected_state[0];
                next_state[1] = 1'b0;
                next_state[2] = !expected_state[2];
            end
            clk = 1'b1;
            expected_state = next_state;
            #1;
            check_output();
            // Change x with clock held high: state must not change.
            x = !value;
            #1;
            check_output();
            clk = 1'b0;
            #1;
            check_output();
        end
    endtask

    initial begin
        #1;
        check_output();
        // Sustained zero, sustained one, and alternating boundary cases.
        repeat (16) cycle(1'b0);
        repeat (16) cycle(1'b1);
        repeat (16) begin
            cycle(1'b0);
            cycle(1'b1);
        end
        // Exercise every eight-bit input word without introducing a reset port.
        for (sequence_number = 0; sequence_number < 256; sequence_number = sequence_number + 1)
            for (position = 0; position < 8; position = position + 1)
                cycle((sequence_number >> position) & 1);
        $display("PASS: %0d output checks", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
