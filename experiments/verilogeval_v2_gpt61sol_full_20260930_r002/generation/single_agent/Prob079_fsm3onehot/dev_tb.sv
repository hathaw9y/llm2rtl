`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic [3:0] state;
    wire [3:0] next_state;
    wire out;
    integer checks = 0;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));

    task automatic check_table(input logic [3:0] s, input logic i);
        logic [3:0] expected_next;
        logic expected_out;
        begin
            case (s)
                4'b0001: begin
                    if (i) expected_next = 4'b0010;
                    else expected_next = 4'b0001;
                    expected_out = 1'b0;
                end
                4'b0010: begin
                    if (i) expected_next = 4'b0010;
                    else expected_next = 4'b0100;
                    expected_out = 1'b0;
                end
                4'b0100: begin
                    if (i) expected_next = 4'b1000;
                    else expected_next = 4'b0001;
                    expected_out = 1'b0;
                end
                4'b1000: begin
                    if (i) expected_next = 4'b0010;
                    else expected_next = 4'b0100;
                    expected_out = 1'b1;
                end
                default: $fatal(1, "Invalid test stimulus");
            endcase
            state = s;
            in = i;
            #1;
            if (next_state !== expected_next || out !== expected_out)
                $fatal(1, "state=%b in=%b expected=%b/%b actual=%b/%b",
                       s, i, expected_next, expected_out, next_state, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer repeat_index = 0; repeat_index < 3; repeat_index = repeat_index + 1) begin
            check_table(4'b0001, 1'b0);
            check_table(4'b0001, 1'b1);
            check_table(4'b0010, 1'b1);
            check_table(4'b0010, 1'b0);
            check_table(4'b0100, 1'b0);
            check_table(4'b0100, 1'b1);
            check_table(4'b1000, 1'b1);
            check_table(4'b1000, 1'b0);
        end
        $display("PASS: %0d combinational transition/output checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
