`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg enable = 0;
    reg S = 0;
    reg A = 0, B = 0, C = 0;
    wire Z;
    reg expected [0:7];
    integer i, n, checks = 0;
    reg [7:0] pattern;
    TopModule dut(.clk(clk), .enable(enable), .S(S),
                  .A(A), .B(B), .C(C), .Z(Z));

    task scan;
        integer address;
        begin
            for (address = 0; address < 8; address = address + 1) begin
                {A, B, C} = address[2:0];
                #1;
                if (Z !== expected[address])
                    $fatal(1, "address=%0d expected=%b actual=%b time=%0t",
                           address, expected[address], Z, $time);
                checks = checks + 1;
            end
        end
    endtask

    task cycle(input reg en, input reg serial);
        integer j;
        begin
            enable = en;
            S = serial;
            scan; // Changing data/enable cannot modify storage without an edge.
            clk = 1;
            if (en) begin
                for (j = 7; j > 0; j = j - 1)
                    expected[j] = expected[j-1];
                expected[0] = serial;
            end
            #1; // Sample after nonblocking updates.
            scan;
            clk = 0;
            S = ~serial;
            #1;
            scan; // Falling edges do not shift.
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1)
            expected[i] = 1'bx;
        scan; // No reset or initialization is specified.
        cycle(0, 0);
        cycle(0, 1);
        pattern = 8'b10110010;
        for (n = 7; n >= 0; n = n - 1)
            cycle(1, pattern[n]); // MSB first; final Q[7:0] equals pattern.
        for (n = 0; n < 8; n = n + 1)
            cycle(0, n[0]);
        for (n = 0; n < 8; n = n + 1)
            cycle(1, 0);
        for (n = 0; n < 8; n = n + 1)
            cycle(1, 1);
        for (n = 0; n < 64; n = n + 1)
            cycle((n % 3) != 0, ((n*13 + n/4) % 7) < 3);
        $display("PASS: %0d checks of initial unknowns, shifting, hold and asynchronous reads", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
