`timescale 1ns/1ps
module dev_tb;
    reg in;
    reg [1:0] state;
    wire [1:0] next_state;
    wire out;
    reg [1:0] expected_next [0:7];
    reg expected_out [0:7];
    integer i;
    integer pass_index;
    integer index;

    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));

    initial begin
        #100;
        $fatal(1, "Timeout");
    end

    initial begin
        // Explicit oracle entries copied from the original transition table.
        // Index is {state, in}.
        expected_next[0] = 2'b00; expected_out[0] = 0;
        expected_next[1] = 2'b01; expected_out[1] = 0;
        expected_next[2] = 2'b10; expected_out[2] = 0;
        expected_next[3] = 2'b01; expected_out[3] = 0;
        expected_next[4] = 2'b00; expected_out[4] = 0;
        expected_next[5] = 2'b11; expected_out[5] = 0;
        expected_next[6] = 2'b10; expected_out[6] = 1;
        expected_next[7] = 2'b01; expected_out[7] = 1;
        // Sweep forward and backward to exercise changes of input and state.
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (i = 0; i < 8; i = i + 1) begin
                if (pass_index == 0) index = i;
                else index = 7 - i;
                {state, in} = index[2:0];
                #1;
                if (next_state !== expected_next[index] || out !== expected_out[index])
                    $fatal(1, "state=%b in=%b next=%b expected=%b out=%b expected=%b",
                           state, in, next_state, expected_next[index], out, expected_out[index]);
            end
        end
        $display("PASS all eight transition/output combinations in both sweep directions");
        $finish;
    end
endmodule
