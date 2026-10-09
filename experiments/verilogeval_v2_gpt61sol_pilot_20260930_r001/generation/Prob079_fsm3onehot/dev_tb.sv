module dev_tb;
    logic in;
    logic [3:0] state;
    wire [3:0] next_state;
    wire out;
    logic [3:0] expected;
    integer s, i, checks;
    TopModule dut (.in(in), .state(state), .next_state(next_state), .out(out));
    initial begin
        checks = 0;
        for (s = 0; s < 16; s = s + 1) begin
            for (i = 0; i < 2; i = i + 1) begin
                state = s[3:0];
                in = i[0];
                expected = 4'b0000;
                if (state[0]) expected = expected | (in ? 4'b0010 : 4'b0001);
                if (state[1]) expected = expected | (in ? 4'b0010 : 4'b0100);
                if (state[2]) expected = expected | (in ? 4'b1000 : 4'b0001);
                if (state[3]) expected = expected | (in ? 4'b0010 : 4'b0100);
                #1;
                if (next_state !== expected || out !== state[3])
                    $fatal(1, "FAIL state=%b in=%b next=%b expected=%b out=%b", state, in, next_state, expected, out);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d combinations including all 8 legal transitions", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL timeout");
    end
endmodule
