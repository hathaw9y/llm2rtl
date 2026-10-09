`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire q;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .q(q));

    task automatic sample(input logic expected);
        begin
            // Settle combinational delta cycles without changing timestamps.
            #0;
            if (q !== expected)
                $fatal(1, "Mismatch time=%0t abcd=%b%b%b%b expected=%b actual=%b",
                       $time, a, b, c, d, expected, q);
            checks = checks + 1;
        end
    endtask

    initial begin
        {a,b,c,d} = 4'b0000; sample(1'b0); // 0 ns
        #5; sample(1'b0);
        #5; sample(1'b0);
        #5; sample(1'b0);
        #5; {a,b,c,d} = 4'b0001; sample(1'b0);
        #5; {a,b,c,d} = 4'b0010; sample(1'b0);
        #5; {a,b,c,d} = 4'b0011; sample(1'b0);
        #5; {a,b,c,d} = 4'b0100; sample(1'b0);
        #5; {a,b,c,d} = 4'b0101; sample(1'b1);
        #5; {a,b,c,d} = 4'b0110; sample(1'b1);
        #5; {a,b,c,d} = 4'b0111; sample(1'b1);
        #5; {a,b,c,d} = 4'b1000; sample(1'b0);
        #5; {a,b,c,d} = 4'b1001; sample(1'b1);
        #5; {a,b,c,d} = 4'b1010; sample(1'b1);
        #5; {a,b,c,d} = 4'b1011; sample(1'b1);
        #5; {a,b,c,d} = 4'b1100; sample(1'b0);
        #5; {a,b,c,d} = 4'b1101; sample(1'b1);
        #5; {a,b,c,d} = 4'b1110; sample(1'b1);
        #5; {a,b,c,d} = 4'b1111; sample(1'b1);
        $display("PASS original waveform: %0d checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
