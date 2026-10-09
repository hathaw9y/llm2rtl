`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic areset = 0;
    logic bump_left = 0, bump_right = 0;
    wire walk_left, walk_right;
    bit expected_right;
    integer checks = 0;
    integer coverage [0:1][0:3];
    TopModule dut (.clk(clk), .areset(areset), .bump_left(bump_left),
                   .bump_right(bump_right), .walk_left(walk_left), .walk_right(walk_right));
    always #5 clk = ~clk;

    task automatic check_outputs;
        begin
            checks = checks + 1;
            if ({walk_left,walk_right} !== (expected_right ? 2'b01 : 2'b10))
                $fatal(1, "FAIL check=%0d expected_right=%b got=%b%b", checks, expected_right, walk_left, walk_right);
        end
    endtask

    task automatic step(input logic [1:0] bumps);
        begin
            @(negedge clk);
            {bump_left,bump_right} = bumps;
            #1;
            check_outputs(); // Moore outputs cannot follow bump inputs directly.
            coverage[expected_right][bumps] = coverage[expected_right][bumps] + 1;
            // Explicit table oracle, independent of the DUT conditional implementation.
            case ({expected_right,bumps})
                3'b000, 3'b001, 3'b101, 3'b111: expected_right = 0;
                3'b010, 3'b011, 3'b100, 3'b110: expected_right = 1;
            endcase
            @(posedge clk);
            #1;
            check_outputs();
        end
    endtask

    initial begin
        for (integer s=0; s<2; s=s+1)
            for (integer b=0; b<4; b=b+1) coverage[s][b]=0;
        #2 areset = 1;
        expected_right = 0;
        #1 check_outputs();
        {bump_left,bump_right} = 2'b11;
        repeat (2) begin @(posedge clk); #1 check_outputs(); end
        @(negedge clk); #1 areset = 0;
        #1 check_outputs();
        for (integer s=0; s<2; s=s+1) begin
            for (integer b=0; b<4; b=b+1) begin
                if (s==0) step(2'b01); else step(2'b10);
                step(b[1:0]);
            end
        end
        repeat (8) step(2'b11);
        step(2'b10); // Ensure RIGHT before asynchronous reset.
        @(negedge clk); #2 areset = 1;
        expected_right = 0;
        #1 check_outputs();
        @(posedge clk); #1 check_outputs();
        @(negedge clk); #1 areset = 0;
        #1 check_outputs();
        for (integer i=0; i<64; i=i+1) step(i[1:0]);
        for (integer s=0; s<2; s=s+1)
            for (integer b=0; b<4; b=b+1)
                if (coverage[s][b]==0) $fatal(1,"FAIL missing transition coverage");
        $display("PASS: %0d output checks; all eight state/input combinations covered",checks);
        $finish;
    end
    initial begin
        #5000;
        $fatal(1,"FAIL watchdog timeout");
    end
endmodule
