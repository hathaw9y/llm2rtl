`timescale 1ns/1ps
module dev_tb;
    reg clk, a, b;
    wire q, state;
    integer checks = 0;
    integer s, v;
    reg expected_next;
    TopModule dut(.clk(clk), .a(a), .b(b), .q(q), .state(state));
    task check(input reg es, input reg eq);
        begin
            if (state !== es || q !== eq)
                $fatal(1, "Mismatch at %0t: a=%b b=%b state=%b expected=%b q=%b expected=%b",
                       $time, a, b, state, es, q, eq);
            checks = checks + 1;
        end
    endtask
    // A row is observed after settling. NBA stimulus at an edge ensures
    // the flip-flop samples the inputs from the preceding waveform row.
    task row(input reg c, input reg av, input reg bv,
             input reg es, input reg eq);
        begin
            clk = c;
            a <= av;
            b <= bv;
            #0.001;
            check(es, eq);
        end
    endtask
    // Truth table inferred independently from the eight observed combinations.
    function parity_table(input reg sv, input reg av, input reg bv);
        begin
            case ({sv,av,bv})
                3'b000: parity_table=0;
                3'b001: parity_table=1;
                3'b010: parity_table=1;
                3'b011: parity_table=0;
                3'b100: parity_table=1;
                3'b101: parity_table=0;
                3'b110: parity_table=0;
                3'b111: parity_table=1;
                default: parity_table=1'bx;
            endcase
        end
    endfunction
    initial begin
        row(1'b0, 1'b1, 1'bx, 1'bx, 1'bx); // 0 ns
        #4.999;
        row(1'b1, 1'b1, 1'bx, 1'bx, 1'bx); // 5 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'bx, 1'bx); // 10 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 15 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 20 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 25 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 30 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 35 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 40 ns
        #4.999;
        row(1'b1, 1'b0, 1'b1, 1'b0, 1'b1); // 45 ns
        #4.999;
        row(1'b0, 1'b0, 1'b1, 1'b0, 1'b1); // 50 ns
        #4.999;
        row(1'b1, 1'b1, 1'b0, 1'b0, 1'b1); // 55 ns
        #4.999;
        row(1'b0, 1'b1, 1'b0, 1'b0, 1'b1); // 60 ns
        #4.999;
        row(1'b1, 1'b1, 1'b1, 1'b0, 1'b0); // 65 ns
        #4.999;
        row(1'b0, 1'b1, 1'b1, 1'b0, 1'b0); // 70 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b1, 1'b1); // 75 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b1, 1'b1); // 80 ns
        #4.999;
        row(1'b1, 1'b1, 1'b1, 1'b0, 1'b0); // 85 ns
        #4.999;
        row(1'b0, 1'b1, 1'b1, 1'b0, 1'b0); // 90 ns
        #4.999;
        row(1'b1, 1'b1, 1'b1, 1'b1, 1'b1); // 95 ns
        #4.999;
        row(1'b0, 1'b1, 1'b1, 1'b1, 1'b1); // 100 ns
        #4.999;
        row(1'b1, 1'b1, 1'b1, 1'b1, 1'b1); // 105 ns
        #4.999;
        row(1'b0, 1'b1, 1'b1, 1'b1, 1'b1); // 110 ns
        #4.999;
        row(1'b1, 1'b1, 1'b0, 1'b1, 1'b0); // 115 ns
        #4.999;
        row(1'b0, 1'b1, 1'b0, 1'b1, 1'b0); // 120 ns
        #4.999;
        row(1'b1, 1'b0, 1'b1, 1'b1, 1'b0); // 125 ns
        #4.999;
        row(1'b0, 1'b0, 1'b1, 1'b1, 1'b0); // 130 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b1, 1'b1); // 135 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b1, 1'b1); // 140 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 145 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 150 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 155 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 160 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 165 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 170 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 175 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 180 ns
        #4.999;
        row(1'b1, 1'b0, 1'b0, 1'b0, 1'b0); // 185 ns
        #4.999;
        row(1'b0, 1'b0, 1'b0, 1'b0, 1'b0); // 190 ns

        // Establish each state using stable inputs before the rising edge,
        // then vary inputs away from edges to check all combinational rows.
        for (s=0; s<2; s=s+1) begin
            #1; clk=0; a=s; b=s;
            #2; clk=1;
            #0.001; check(s, parity_table(s,s,s));
            #1; clk=0;
            for (v=0; v<4; v=v+1) begin
                #1; a=(v >> 1) & 1; b=v & 1;
                #0.001; check(s, parity_table(s,a,b));
            end
        end
        // Explicit next-state truth table: 00 clears, 11 sets,
        // mixed inputs retain the preceding state.
        for (s=0; s<2; s=s+1) begin
            for (v=0; v<4; v=v+1) begin
                #1; clk=0; a=s; b=s;
                #1; clk=1;
                #0.001; check(s, parity_table(s,s,s));
                #1; clk=0; a=(v >> 1) & 1; b=v & 1;
                #0.001; check(s, parity_table(s,a,b));
                case (v)
                    0: expected_next=0;
                    3: expected_next=1;
                    default: expected_next=s;
                endcase
                #1; clk=1;
                #0.001; check(expected_next, parity_table(expected_next,a,b));
            end
        end
        // Unknown propagation and majority masking, with no reset/init.
        #1; clk=0; a=0; b=0;
        #1; clk=1;
        #0.001; check(0,0);
        #1; clk=0;
        #1; a=0; b=1'bx;
        #0.001; check(0, 1'bx);
        #1; clk=1;
        #0.001; check(0, 1'bx);
        #1; clk=0; a=1; b=1'bx;
        #1; clk=1;
        #0.001; check(1'bx, 1'bx);
        #1; clk=0; a=0; b=0;
        #0.001; check(1'bx, 1'bx);
        #1; clk=1;
        #0.001; check(0,0);
        $display("PASS: original waveform and directed checks (%0d observations)", checks);
        $finish;
    end
    initial begin
        #500;
        $fatal(1, "Bounded timeout");
    end
endmodule
