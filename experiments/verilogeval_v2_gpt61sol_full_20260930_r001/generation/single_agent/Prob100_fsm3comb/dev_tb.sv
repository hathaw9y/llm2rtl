module dev_tb;
    logic in;
    logic [1:0] state;
    wire [1:0] next_state;
    wire out;
    logic [1:0] expected_next;
    integer s, i;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));
    initial begin
        for (s = 0; s < 4; s = s + 1) begin
            for (i = 0; i < 2; i = i + 1) begin
                state = s[1:0];
                in = i[0];
                case (s*2+i)
                    0: expected_next = 2'b00;
                    1: expected_next = 2'b01;
                    2: expected_next = 2'b10;
                    3: expected_next = 2'b01;
                    4: expected_next = 2'b00;
                    5: expected_next = 2'b11;
                    6: expected_next = 2'b10;
                    7: expected_next = 2'b01;
                endcase
                #1;
                if (next_state !== expected_next || out !== (s == 3))
                    $fatal(1, "FAIL state=%b in=%b next=%b out=%b", state, in, next_state, out);
            end
        end
        $display("PASS: all 8 state/input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
