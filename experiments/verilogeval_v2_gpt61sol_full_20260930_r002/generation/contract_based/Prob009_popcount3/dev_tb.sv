`timescale 1ns/1ps
module dev_tb;
    logic [2:0] in;
    wire [1:0] out;
    integer first_vector;
    integer second_vector;
    integer checks = 0;

    TopModule dut (.in(in), .out(out));

    function automatic logic [1:0] expected_count(input logic [2:0] vector);
        case (vector)
            3'b000: expected_count = 2'd0;
            3'b001, 3'b010, 3'b100: expected_count = 2'd1;
            3'b011, 3'b101, 3'b110: expected_count = 2'd2;
            3'b111: expected_count = 2'd3;
            default: expected_count = 2'bxx;
        endcase
    endfunction

    task automatic drive_and_check(input logic [2:0] vector);
        in = vector;
        #1;
        if (out !== expected_count(vector))
            $fatal(1, "in=%b expected=%d actual=%b", vector, expected_count(vector), out);
        checks = checks + 1;
    endtask

    initial begin
        for (first_vector = 0; first_vector < 8; first_vector = first_vector + 1)
            for (second_vector = 0; second_vector < 8; second_vector = second_vector + 1) begin
                drive_and_check(first_vector[2:0]);
                drive_and_check(second_vector[2:0]);
            end
        $display("PASS: population count, all 8 inputs and 64 ordered transitions (%0d comparisons)", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout waiting for population-count verification");
    end
endmodule
