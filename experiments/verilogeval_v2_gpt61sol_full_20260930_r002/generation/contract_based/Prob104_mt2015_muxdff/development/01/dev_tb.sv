`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic L = 0;
    logic q_in = 0;
    logic r_in = 0;
    wire Q;
    logic expected = 1'bx;
    logic [2:0] r = 0;
    wire [2:0] q;
    logic [2:0] full_expected = 3'bxxx;
    integer checks = 0;
    integer i, j;

    TopModule dut (.clk(clk), .L(L), .q_in(q_in), .r_in(r_in), .Q(Q));
    TopModule bit2 (.clk(clk), .L(L), .q_in(q[1] ^ q[2]), .r_in(r[2]), .Q(q[2]));
    TopModule bit1 (.clk(clk), .L(L), .q_in(q[0]), .r_in(r[1]), .Q(q[1]));
    TopModule bit0 (.clk(clk), .L(L), .q_in(q[2]), .r_in(r[0]), .Q(q[0]));

    task automatic check_outputs;
        begin
            if (Q !== expected)
                $fatal(1, "Scalar mismatch time=%0t L=%b q_in=%b r_in=%b expected=%b actual=%b", $time,L,q_in,r_in,expected,Q);
            if (q !== full_expected)
                $fatal(1, "Factored full_module mismatch time=%0t expected=%b actual=%b",$time,full_expected,q);
            checks = checks + 1;
        end
    endtask

    task automatic capture;
        begin
            // Original full_module is the independent three-bit oracle.
            if (L) begin
                expected = r_in;
                full_expected = r;
            end else begin
                expected = q_in;
                full_expected = {full_expected[1] ^ full_expected[2],full_expected[0],full_expected[2]};
            end
            clk = 1;
            #1;
            check_outputs();
            // Perturb every data input and select while high: storage must hold.
            L = ~L;
            q_in = ~q_in;
            r_in = ~r_in;
            r = ~r;
            #1;
            check_outputs();
            clk = 0;
            #1;
            check_outputs();
        end
    endtask

    initial begin
        #1;
        check_outputs();
        // Exhaust all binary selector/data combinations, repeated twice.
        for (j = 0; j < 2; j = j + 1) begin
            for (i = 0; i < 8; i = i + 1) begin
                L = (i >> 2) & 1;
                q_in = (i >> 1) & 1;
                r_in = i & 1;
                r = i;
                #1;
                check_outputs();
                capture();
            end
        end
        // Every original three-bit load value, followed by eight feedback edges.
        for (i = 0; i < 8; i = i + 1) begin
            L = 1;
            r = i;
            r_in = i & 1;
            #1;
            check_outputs();
            capture();
            for (j = 0; j < 8; j = j + 1) begin
                L = 0;
                q_in = j & 1;
                #1;
                check_outputs();
                capture();
            end
        end
        $display("PASS: %0d scalar and original full_module retention/capture checks",checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1,"Timeout");
    end
endmodule
