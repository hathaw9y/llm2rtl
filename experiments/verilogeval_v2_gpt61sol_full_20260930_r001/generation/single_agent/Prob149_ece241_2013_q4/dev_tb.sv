`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [2:0] s = 0;
    wire fr2, fr1, fr0, dfr;
    TopModule dut(.*);
    always #5 clk = ~clk;
    integer previous_level = 0;
    bit supplement = 1;
    integer checks = 0;
    logic [3:0] expected;

    function automatic logic [2:0] sensors(input integer level);
        case(level)
            0: sensors = 3'b000;
            1: sensors = 3'b001;
            2: sensors = 3'b011;
            3: sensors = 3'b111;
        endcase
    endfunction

    task automatic step(input integer level, input bit rst);
        logic [3:0] before_edge;
        begin
            @(negedge clk);
            before_edge = {fr2,fr1,fr0,dfr};
            s = sensors(level);
            reset = rst;
            #1;
            if ({fr2,fr1,fr0,dfr} !== before_edge)
                $fatal(1, "Outputs changed before active clock edge");
            @(posedge clk);
            if (rst) begin
                previous_level = 0;
                supplement = 1;
            end else begin
                if (level == 0) supplement = 1;
                else if (level == 3) supplement = 0;
                else if (level != previous_level)
                    supplement = (level > previous_level);
                previous_level = level;
            end
            case(previous_level)
                0: expected = {3'b111, supplement};
                1: expected = {3'b011, supplement};
                2: expected = {3'b001, supplement};
                3: expected = {3'b000, supplement};
            endcase
            #1;
            if ({fr2,fr1,fr0,dfr} !== expected)
                $fatal(1, "Mismatch level=%0d reset=%0b expected=%b actual=%b", level,rst,expected,{fr2,fr1,fr0,dfr});
            checks = checks + 1;
        end
    endtask

    integer sequence_id, position, encoded;
    initial begin
        step(3, 1);
        // All 4^6 level sequences cover jumps, holds, and direction reversals.
        for (sequence_id = 0; sequence_id < 4096; sequence_id = sequence_id + 1) begin
            step(3, 1);
            encoded = sequence_id;
            for (position = 0; position < 6; position = position + 1) begin
                step(encoded % 4, 0);
                encoded = encoded / 4;
            end
        end
        step(2, 1);
        step(1, 0);
        step(1, 0);
        step(3, 0);
        step(2, 0);
        step(2, 0);
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Testbench timeout");
    end
endmodule
