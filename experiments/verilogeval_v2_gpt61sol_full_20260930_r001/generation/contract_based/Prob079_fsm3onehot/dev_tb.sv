`timescale 1ns/1ps
module dev_tb;
    logic in;
    logic [3:0] state;
    wire [3:0] next_state;
    wire out;
    logic [3:0] expected_next;
    logic expected_out;
    integer checks = 0;

    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));

    task automatic check(input logic [3:0] s, input logic i);
        begin
            state = s;
            in = i;
            case (s)
                4'b0001: begin expected_next = i ? 4'b0010 : 4'b0001; expected_out = 1'b0; end
                4'b0010: begin expected_next = i ? 4'b0010 : 4'b0100; expected_out = 1'b0; end
                4'b0100: begin expected_next = i ? 4'b1000 : 4'b0001; expected_out = 1'b0; end
                4'b1000: begin expected_next = i ? 4'b0010 : 4'b0100; expected_out = 1'b1; end
                default: $fatal(1, "Illegal test stimulus");
            endcase
            #1;
            if (next_state !== expected_next || out !== expected_out)
                $fatal(1, "FAIL state=%b in=%b next=%b expected=%b out=%b expected=%b", state, in, next_state, expected_next, out, expected_out);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (integer pass = 0; pass < 2; pass = pass + 1)
            for (integer s = 0; s < 4; s = s + 1) begin
                check(4'b0001 << s, 1'b0);
                check(4'b0001 << s, 1'b1);
                check(4'b0001 << s, 1'b0);
            end
        $display("PASS: %0d table comparisons, all eight legal combinations", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
