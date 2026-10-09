`timescale 1ns/1ps
module dev_tb;
    reg [9:0] stimulus;
    wire p1y, p2y;
    integer i;
    reg expected1, expected2;
    TopModule dut (
        .p1a(stimulus[9]), .p1b(stimulus[8]), .p1c(stimulus[7]),
        .p1d(stimulus[6]), .p1e(stimulus[5]), .p1f(stimulus[4]),
        .p2a(stimulus[3]), .p2b(stimulus[2]),
        .p2c(stimulus[1]), .p2d(stimulus[0]),
        .p1y(p1y), .p2y(p2y)
    );
    task check;
        input [9:0] inputs;
        input want1, want2;
        begin
            stimulus = inputs;
            #1;
            if (p1y !== want1 || p2y !== want2)
                $fatal(1, "inputs=%b expected=%b%b actual=%b%b",
                       inputs, want1, want2, p1y, p2y);
        end
    endtask
    initial begin
        // Binary oracle: each gate asserts only when its group is all ones.
        for (i = 0; i < 1024; i = i + 1) begin
            expected1 = ((i / 128) % 8 == 7) || ((i / 16) % 8 == 7);
            expected2 = ((i / 4) % 4 == 3) || (i % 4 == 3);
            check(i[9:0], expected1, expected2);
        end
        // Four-state gate behavior: zero masks unknowns; one masks OR unknowns.
        check(10'bxxxxxxxxxx, 1'bx, 1'bx);
        check(10'b0xx0xx0x0x, 1'b0, 1'b0);
        check(10'b111xxx11xx, 1'b1, 1'b1);
        check(10'bxxx111xx11, 1'b1, 1'b1);
        check(10'b11x0001x00, 1'bx, 1'bx);
        check(10'b0zz0zz0z0z, 1'b0, 1'b0);
        check(10'b11z0001z00, 1'bx, 1'bx);
        $display("PASS exhaustive binary inputs and directed four-state cases");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
