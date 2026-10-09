module dev_tb;
    logic in;
    logic [3:0] state;
    wire [3:0] next_state;
    wire out;
    logic [3:0] expected;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));
    initial begin
        for (integer s = 0; s < 4; s = s + 1) begin
            for (integer i = 0; i < 2; i = i + 1) begin
                state = 4'b0001 << s;
                in = (i == 1);
                case (s)
                    0: expected = in ? 4'b0010 : 4'b0001;
                    1: expected = in ? 4'b0010 : 4'b0100;
                    2: expected = in ? 4'b1000 : 4'b0001;
                    3: expected = in ? 4'b0010 : 4'b0100;
                endcase
                #1;
                if (next_state !== expected || out !== (s == 3))
                    $fatal(1, "FAIL state=%b in=%b next=%b expected=%b out=%b", state, in, next_state, expected, out);
            end
        end
        $display("PASS: all 8 one-hot state/input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: development simulation timeout");
    end
endmodule
