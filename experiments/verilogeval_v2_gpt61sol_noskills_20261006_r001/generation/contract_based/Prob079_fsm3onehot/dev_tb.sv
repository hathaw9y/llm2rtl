`timescale 1ns/1ps
module dev_tb;
    reg in;
    reg [3:0] state;
    wire [3:0] next_state;
    wire out;
    integer count = 0;
    integer pass_index;
    integer state_index;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));

    // Oracle is the original table, not the implementation's equations.
    task automatic check(input [3:0] current, input stimulus);
        reg [3:0] expected_next;
        reg expected_out;
        begin
            case (current)
                4'b0001: begin
                    if (stimulus) expected_next = 4'b0010;
                    else expected_next = 4'b0001;
                    expected_out = 0;
                end
                4'b0010: begin
                    if (stimulus) expected_next = 4'b0010;
                    else expected_next = 4'b0100;
                    expected_out = 0;
                end
                4'b0100: begin
                    if (stimulus) expected_next = 4'b1000;
                    else expected_next = 4'b0001;
                    expected_out = 0;
                end
                4'b1000: begin
                    if (stimulus) expected_next = 4'b0010;
                    else expected_next = 4'b0100;
                    expected_out = 1;
                end
                default: $fatal(1, "Invalid oracle state");
            endcase
            state = current;
            in = stimulus;
            #1;
            if (next_state !== expected_next || out !== expected_out)
                $fatal(1, "state=%b in=%b: next=%b expected=%b out=%b expected=%b",
                       current, stimulus, next_state, expected_next, out, expected_out);
            count = count + 1;
        end
    endtask

    initial begin
        // Repeated forward/reverse traversals detect unwanted retained state.
        for (pass_index = 0; pass_index < 2; pass_index = pass_index + 1) begin
            for (state_index = 0; state_index < 4; state_index = state_index + 1) begin
                check(4'b0001 << state_index, 0);
                check(4'b0001 << state_index, 1);
            end
            for (state_index = 3; state_index >= 0; state_index = state_index - 1) begin
                check(4'b0001 << state_index, 1);
                check(4'b0001 << state_index, 0);
            end
        end
        $display("PASS: %0d original-table combinational checks", count);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
