`timescale 1ns/1ps
module dev_tb;
    reg in;
    reg [1:0] state;
    wire [1:0] next_state;
    wire out;
    integer checks = 0;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));

    task check;
        input [1:0] current;
        input stimulus;
        input [1:0] expected_next;
        input expected_out;
        begin
            state = current;
            in = stimulus;
            #1;
            if (next_state !== expected_next || out !== expected_out)
                $fatal(1, "state=%b in=%b got next=%b out=%b expected next=%b out=%b",
                       current, stimulus, next_state, out, expected_next, expected_out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Literal oracle from the original A/B/C/D transition table.
        check(2'b00, 1'b0, 2'b00, 1'b0);
        check(2'b00, 1'b1, 2'b01, 1'b0);
        check(2'b01, 1'b0, 2'b10, 1'b0);
        check(2'b01, 1'b1, 2'b01, 1'b0);
        check(2'b10, 1'b0, 2'b00, 1'b0);
        check(2'b10, 1'b1, 2'b11, 1'b0);
        check(2'b11, 1'b0, 2'b10, 1'b1);
        check(2'b11, 1'b1, 2'b01, 1'b1);
        // Reverse ordering also exercises state-only and input-only changes.
        check(2'b11, 1'b1, 2'b01, 1'b1);
        check(2'b11, 1'b0, 2'b10, 1'b1);
        check(2'b10, 1'b1, 2'b11, 1'b0);
        check(2'b10, 1'b0, 2'b00, 1'b0);
        check(2'b01, 1'b1, 2'b01, 1'b0);
        check(2'b01, 1'b0, 2'b10, 1'b0);
        check(2'b00, 1'b1, 2'b01, 1'b0);
        check(2'b00, 1'b0, 2'b00, 1'b0);
        $display("PASS: %0d combinational table checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
