`timescale 1ns/1ps
module dev_tb;
    logic clk = 1'b0;
    wire [255:0] z;
    logic [255:0] x;
    logic [2:0] expected [0:255];
    integer sequence_id;
    integer step;
    integer checks = 0;

    for (genvar g = 0; g < 256; g = g + 1) begin : instances
        TopModule dut (.clk(clk), .x(x[g]), .z(z[g]));
    end

    function automatic logic [2:0] transition(input logic [2:0] state, input logic bit_x);
        case ({state, bit_x})
            4'b0000: transition = 3'b001;
            4'b0001: transition = 3'b111;
            4'b0010: transition = 3'b000;
            4'b0011: transition = 3'b111;
            4'b0100: transition = 3'b011;
            4'b0101: transition = 3'b101;
            4'b0110: transition = 3'b010;
            4'b0111: transition = 3'b101;
            4'b1000: transition = 3'b101;
            4'b1001: transition = 3'b011;
            4'b1010: transition = 3'b100;
            4'b1011: transition = 3'b011;
            4'b1100: transition = 3'b111;
            4'b1101: transition = 3'b001;
            4'b1110: transition = 3'b110;
            4'b1111: transition = 3'b001;
            default: transition = 3'bxxx;
        endcase
    endfunction

    task automatic check_outputs;
        for (integer i = 0; i < 256; i = i + 1) begin
            if (z[i] !== (expected[i] == 3'b000))
                $fatal(1, "FAIL sequence=%0d step=%0d state=%b z=%b", i, step, expected[i], z[i]);
            checks = checks + 1;
        end
    endtask

    initial begin
        x = '0;
        for (sequence_id = 0; sequence_id < 256; sequence_id = sequence_id + 1)
            expected[sequence_id] = 3'b000;
        #1;
        check_outputs();
        for (step = 0; step < 8; step = step + 1) begin
            for (sequence_id = 0; sequence_id < 256; sequence_id = sequence_id + 1)
                x[sequence_id] = (sequence_id >> step) & 1;
            #1;
            check_outputs();
            for (sequence_id = 0; sequence_id < 256; sequence_id = sequence_id + 1)
                expected[sequence_id] = transition(expected[sequence_id], x[sequence_id]);
            clk = 1'b1;
            #1;
            check_outputs();
            clk = 1'b0;
            #1;
            check_outputs();
        end
        $display("PASS: 256 input sequences of length 8; %0d output checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
