`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    integer checks = 0;
    integer src, dst;
    TopModule dut (.x(x), .y(y), .z(z));

    function automatic logic expected(input logic [1:0] pair);
        case (pair)
            2'b00: expected = 1'b1;
            2'b01: expected = 1'b0;
            2'b10: expected = 1'b0;
            2'b11: expected = 1'b1;
        endcase
    endfunction

    task automatic sample(input logic a, b, want);
        x = a;
        y = b;
        #0.001;
        if (z !== want)
            $fatal(1, "FAIL x=%b y=%b expected=%b actual=%b", x, y, want, z);
        checks = checks + 1;
        #4.999;
    endtask

    initial begin
        sample(0,0,1); // 0 ns
        sample(0,0,1); // 5 ns
        sample(0,0,1); // 10 ns
        sample(0,0,1); // 15 ns
        sample(0,0,1); // 20 ns
        sample(1,0,0); // 25 ns
        sample(1,0,0); // 30 ns
        sample(0,1,0); // 35 ns
        sample(0,1,0); // 40 ns
        sample(1,1,1); // 45 ns
        sample(1,1,1); // 50 ns
        sample(0,0,1); // 55 ns
        sample(0,1,0); // 60 ns
        sample(0,1,0); // 65 ns
        sample(1,1,1); // 70 ns
        sample(0,1,0); // 75 ns
        sample(0,1,0); // 80 ns
        sample(0,1,0); // 85 ns
        sample(1,0,0); // 90 ns
        for (src = 0; src < 4; src = src + 1) begin
            for (dst = 0; dst < 4; dst = dst + 1) begin
                sample(src[1], src[0], expected(src[1:0]));
                sample(dst[1], dst[0], expected(dst[1:0]));
            end
        end
        $display("PASS: %0d checks; waveform and all 16 ordered binary transitions", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "FAIL watchdog timeout");
    end
endmodule
