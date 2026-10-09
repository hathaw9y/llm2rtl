`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic x = 0;
    wire z;
    integer model = 0;
    integer transitions [0:4][0:1];
    integer table_next [0:4][0:1];
    integer checks = 0;
    integer s, b, word, k;
    logic old_z;
    TopModule dut (.clk(clk), .reset(reset), .x(x), .z(z));
    always #5 clk = ~clk;

    task automatic check_output;
        logic expected;
        begin
            expected = (model == 3 || model == 4);
            if (z !== expected)
                $fatal(1, "state=%0d expected z=%b actual=%b", model, expected, z);
            checks = checks + 1;
        end
    endtask

    task automatic step(input logic rst, input logic value);
        begin
            @(negedge clk);
            old_z = z;
            reset = rst;
            x = value;
            #1;
            if (z !== old_z) $fatal(1, "Output changed between clock edges");
            @(posedge clk);
            if (rst) model = 0;
            else begin
                transitions[model][value] = transitions[model][value] + 1;
                model = table_next[model][value];
            end
            #1;
            check_output();
        end
    endtask

    // Reach each state exclusively through specified transitions from reset.
    task automatic reach(input integer target);
        begin
            step(1, 1);
            if (target != 0) step(0, 1);
            if (target >= 2) step(0, 1);
            if (target == 2 || target == 3) step(0, 0);
            if (target == 2) step(0, 1);
            if (model != target) $fatal(1, "Testbench reach failure");
        end
    endtask

    initial begin
        table_next[0][0]=0; table_next[0][1]=1;
        table_next[1][0]=1; table_next[1][1]=4;
        table_next[2][0]=2; table_next[2][1]=1;
        table_next[3][0]=1; table_next[3][1]=2;
        table_next[4][0]=3; table_next[4][1]=4;
        for (s=0; s<5; s=s+1)
            for (b=0; b<2; b=b+1) transitions[s][b]=0;
        // Initial state is unspecified; begin comparisons after a reset edge.
        reset = 1;
        @(posedge clk);
        #1;
        check_output();
        for (s=0; s<5; s=s+1) begin
            for (b=0; b<2; b=b+1) begin
                reach(s);
                step(0, b != 0);
            end
            reach(s);
            step(1, 0);
            step(1, 1);
        end
        // Exhaustively replay all eight-cycle binary input sequences.
        for (word=0; word<256; word=word+1) begin
            step(1, 0);
            for (k=0; k<8; k=k+1) step(0, ((word >> k) & 1) != 0);
        end
        for (s=0; s<5; s=s+1)
            for (b=0; b<2; b=b+1)
                if (transitions[s][b] == 0) $fatal(1, "Missing transition %0d/%0d", s,b);
        $display("PASS checked %0d output samples and all specified transitions", checks);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
