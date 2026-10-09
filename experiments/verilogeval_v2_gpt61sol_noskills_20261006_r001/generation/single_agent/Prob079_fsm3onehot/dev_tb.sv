`timescale 1ns/1ps
module dev_tb;
    reg in;
    reg [3:0] state;
    wire [3:0] next_state;
    wire out;
    integer s, b, checks;
    TopModule dut(.in(in), .state(state), .next_state(next_state), .out(out));

    task check_entry(input integer state_index, input integer input_value);
        reg [3:0] expected_next;
        reg expected_out;
        begin
            state = 4'b0001 << state_index;
            in = input_value;
            expected_out = 1'b0;
            case (state_index)
                0: begin
                    if (input_value == 0) expected_next = 4'b0001;
                    else expected_next = 4'b0010;
                end
                1: begin
                    if (input_value == 0) expected_next = 4'b0100;
                    else expected_next = 4'b0010;
                end
                2: begin
                    if (input_value == 0) expected_next = 4'b0001;
                    else expected_next = 4'b1000;
                end
                3: begin
                    if (input_value == 0) expected_next = 4'b0100;
                    else expected_next = 4'b0010;
                    expected_out = 1'b1;
                end
                default: $fatal(1, "Invalid test state");
            endcase
            #1;
            if (next_state !== expected_next || out !== expected_out)
                $fatal(1, "state=%b in=%b: next=%b expected=%b out=%b expected=%b",
                       state, in, next_state, expected_next, out, expected_out);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        for (s = 0; s < 4; s = s + 1)
            for (b = 0; b < 2; b = b + 1)
                check_entry(s, b);
        for (s = 3; s >= 0; s = s - 1)
            for (b = 1; b >= 0; b = b - 1)
                check_entry(s, b);
        $display("PASS: %0d Moore transition/output checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
