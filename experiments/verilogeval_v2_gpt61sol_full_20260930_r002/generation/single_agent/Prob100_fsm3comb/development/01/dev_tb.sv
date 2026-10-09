`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic [1:0] state;
    wire [1:0] next_state;
    wire out;
    integer checks = 0;
    // Literal oracle entries {out, next_state}, indexed by {state, in}.
    logic [2:0] expected [0:7];
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));

    task automatic check_entry(input integer index);
        begin
            {state, in} = index[2:0];
            #1;
            if ({out, next_state} !== expected[index])
                $fatal(1, "state=%b in=%b expected=%b observed=%b",
                       state, in, expected[index], {out, next_state});
            checks = checks + 1;
        end
    endtask

    initial begin
        expected[0] = 3'b000; // A, 0 -> A, out 0
        expected[1] = 3'b001; // A, 1 -> B, out 0
        expected[2] = 3'b010; // B, 0 -> C, out 0
        expected[3] = 3'b001; // B, 1 -> B, out 0
        expected[4] = 3'b000; // C, 0 -> A, out 0
        expected[5] = 3'b011; // C, 1 -> D, out 0
        expected[6] = 3'b110; // D, 0 -> C, out 1
        expected[7] = 3'b101; // D, 1 -> B, out 1
        for (integer i = 0; i < 8; i = i + 1) check_entry(i);
        for (integer i = 7; i >= 0; i = i - 1) check_entry(i);
        // Hold the input fixed while changing the state.
        check_entry(0); check_entry(6); check_entry(2); check_entry(4);
        check_entry(5); check_entry(1); check_entry(7); check_entry(3);
        $display("PASS: %0d combinational state-table checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
