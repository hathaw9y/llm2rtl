`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic [3:0] state;
    wire [3:0] next_state;
    wire out;
    integer checks = 0;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));

    task automatic check_table(input logic [3:0] current, input logic stimulus);
        logic [3:0] expected_next;
        logic expected_out;
        begin
            // Oracle follows the original transition table by state, not equations.
            case (current)
                4'b0001: begin
                    if (stimulus) expected_next = 4'b0010;
                    else expected_next = 4'b0001;
                    expected_out = 1'b0;
                end
                4'b0010: begin
                    if (stimulus) expected_next = 4'b0010;
                    else expected_next = 4'b0100;
                    expected_out = 1'b0;
                end
                4'b0100: begin
                    if (stimulus) expected_next = 4'b1000;
                    else expected_next = 4'b0001;
                    expected_out = 1'b0;
                end
                4'b1000: begin
                    if (stimulus) expected_next = 4'b0010;
                    else expected_next = 4'b0100;
                    expected_out = 1'b1;
                end
                default: $fatal(1, "Illegal test oracle state");
            endcase
            state = current;
            in = stimulus;
            #1;
            if (next_state !== expected_next || out !== expected_out)
                $fatal(1, "state=%b in=%b expected next=%b out=%b got next=%b out=%b",
                       state, in, expected_next, expected_out, next_state, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer s = 0; s < 4; s = s + 1) begin
            check_table(4'b0001 << s, 1'b0);
            check_table(4'b0001 << s, 1'b1);
            check_table(4'b0001 << s, 1'b0);
        end
        for (integer v = 0; v < 2; v = v + 1)
            for (integer s = 3; s >= 0; s = s - 1)
                check_table(4'b0001 << s, v == 1);
        $display("PASS: %0d original-table combinational checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
