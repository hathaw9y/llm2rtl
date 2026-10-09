`timescale 1ns/1ps
module dev_tb;
    reg a, b, c, d;
    wire q;
    integer i;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    task check_row(input reg [3:0] inputs, input reg expected);
        begin
            {a,b,c,d} = inputs;
            #0;
            if (q !== expected)
                $fatal(1, "Mismatch at %0t: abcd=%b expected=%b actual=%b", $time, inputs, expected, q);
            checks = checks + 1;
        end
    endtask

    // Literal table transcribed from the original waveform, indexed by abcd.
    function reg expected_for(input reg [3:0] inputs);
        begin
            case (inputs)
                4'b0000, 4'b0001, 4'b0010, 4'b0011,
                4'b0100, 4'b1000, 4'b1100: expected_for = 1'b0;
                4'b0101, 4'b0110, 4'b0111, 4'b1001,
                4'b1010, 4'b1011, 4'b1101, 4'b1110,
                4'b1111: expected_for = 1'b1;
                default: expected_for = 1'bx;
            endcase
        end
    endfunction

    initial begin
        check_row(4'b0000, 0);       // 0 ns
        #5; check_row(4'b0000, 0);   // 5 ns
        #5; check_row(4'b0000, 0);   // 10 ns
        #5; check_row(4'b0000, 0);   // 15 ns
        #5; check_row(4'b0001, 0);   // 20 ns
        #5; check_row(4'b0010, 0);   // 25 ns
        #5; check_row(4'b0011, 0);   // 30 ns
        #5; check_row(4'b0100, 0);   // 35 ns
        #5; check_row(4'b0101, 1);   // 40 ns
        #5; check_row(4'b0110, 1);   // 45 ns
        #5; check_row(4'b0111, 1);   // 50 ns
        #5; check_row(4'b1000, 0);   // 55 ns
        #5; check_row(4'b1001, 1);   // 60 ns
        #5; check_row(4'b1010, 1);   // 65 ns
        #5; check_row(4'b1011, 1);   // 70 ns
        #5; check_row(4'b1100, 0);   // 75 ns
        #5; check_row(4'b1101, 1);   // 80 ns
        #5; check_row(4'b1110, 1);   // 85 ns
        #5; check_row(4'b1111, 1);   // 90 ns
        for (i = 15; i >= 0; i = i - 1) begin
            #5; check_row(i[3:0], expected_for(i[3:0]));
        end
        $display("PASS: %0d waveform and exhaustive checks", checks);
        $finish;
    end
    initial begin
        #200;
        $fatal(1, "Bounded timeout expired");
    end
endmodule
