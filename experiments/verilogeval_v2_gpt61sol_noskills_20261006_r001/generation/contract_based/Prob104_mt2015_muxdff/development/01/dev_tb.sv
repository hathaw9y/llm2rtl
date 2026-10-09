`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg L = 0;
    reg q_in = 0;
    reg r_in = 0;
    wire Q;
    reg [2:0] r = 0;
    wire [2:0] chain;
    reg expected;
    reg [2:0] expected_chain;
    reg held;
    reg [2:0] held_chain;
    integer i;
    integer j;
    TopModule dut (.clk(clk), .L(L), .q_in(q_in), .r_in(r_in), .Q(Q));
    TopModule bit2 (.clk(clk), .L(L), .q_in(chain[1] ^ chain[2]), .r_in(r[2]), .Q(chain[2]));
    TopModule bit1 (.clk(clk), .L(L), .q_in(chain[0]), .r_in(r[1]), .Q(chain[1]));
    TopModule bit0 (.clk(clk), .L(L), .q_in(chain[2]), .r_in(r[0]), .Q(chain[0]));

    task cycle(input reg load, input reg data_q, input reg data_r, input reg [2:0] vector_r);
        begin
            held = Q;
            held_chain = chain;
            L = load;
            q_in = data_q;
            r_in = data_r;
            r = vector_r;
            #2;
            if (Q !== held || chain !== held_chain)
                $fatal(1, "Output changed without positive edge");
            if (load) begin
                expected = data_r;
                expected_chain = vector_r;
            end else begin
                expected = data_q;
                expected_chain = {expected_chain[1] ^ expected_chain[2], expected_chain[0], expected_chain[2]};
            end
            clk = 1;
            #1;
            if (Q !== expected)
                $fatal(1, "Mux flop mismatch L=%b q_in=%b r_in=%b Q=%b expected=%b", load, data_q, data_r, Q, expected);
            if (chain !== expected_chain)
                $fatal(1, "Original full_module recurrence mismatch actual=%b expected=%b", chain, expected_chain);
            clk = 0;
            #1;
            if (Q !== expected || chain !== expected_chain)
                $fatal(1, "Output changed at falling edge");
        end
    endtask

    initial begin
        expected_chain = 3'bxxx;
        #1;
        if (Q !== 1'bx || chain !== 3'bxxx)
            $fatal(1, "Uninitialized flip-flops should be unknown");
        cycle(0, 1, 0, 0);
        for (i = 0; i < 8; i = i + 1)
            cycle(i[2], i[1], i[0], i[2:0]);
        for (i = 0; i < 8; i = i + 1) begin
            cycle(1, ~i[0], i[0], i[2:0]);
            for (j = 0; j < 12; j = j + 1)
                cycle(0, j[0], ~j[0], ~i[2:0]);
        end
        $display("PASS mux-flop truth table, edge holding, initialization and full_module recurrence");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Bounded timeout");
    end
endmodule
