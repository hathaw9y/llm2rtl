`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic [1:0] state;
    wire [1:0] next_state;
    wire out;
    logic [1:0] expected_next [0:7];
    logic expected_out [0:7];
    integer checked;
    integer index_value;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));

    task automatic check_entry(input integer entry);
        begin
            state = entry / 2;
            in = entry % 2;
            #1;
            if (next_state !== expected_next[entry] || out !== expected_out[entry])
                $fatal(1, "FAIL entry=%0d next=%b expected=%b out=%b expected=%b",
                       entry, next_state, expected_next[entry], out, expected_out[entry]);
            checked = checked + 1;
        end
    endtask

    initial begin
        expected_next[0] = 2'b00; expected_out[0] = 1'b0;
        expected_next[1] = 2'b01; expected_out[1] = 1'b0;
        expected_next[2] = 2'b10; expected_out[2] = 1'b0;
        expected_next[3] = 2'b01; expected_out[3] = 1'b0;
        expected_next[4] = 2'b00; expected_out[4] = 1'b0;
        expected_next[5] = 2'b11; expected_out[5] = 1'b0;
        expected_next[6] = 2'b10; expected_out[6] = 1'b1;
        expected_next[7] = 2'b01; expected_out[7] = 1'b1;
        checked = 0;
        for (index_value = 0; index_value < 8; index_value = index_value + 1)
            check_entry(index_value);
        for (index_value = 7; index_value >= 0; index_value = index_value - 1)
            check_entry(index_value);
        for (index_value = 0; index_value < 8; index_value = index_value + 1)
            check_entry(index_value);
        $display("PASS: %0d checks covering all eight binary combinations", checked);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
