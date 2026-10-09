`timescale 1ns/1ps
module dev_tb;
    logic a, b, c, d;
    wire out;
    logic expected [0:15];
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .out(out));

    task automatic check_input(input integer index);
        {a,b,c,d} = index[3:0];
        #1;
        if (expected[index] !== 1'bx) begin
            if (out !== expected[index])
                $fatal(1, "FAIL input=%04b expected=%b actual=%b", index[3:0], expected[index], out);
        end else if ((out !== 1'b0) && (out !== 1'b1)) begin
            $fatal(1, "FAIL undefined output at don't-care input=%04b", index[3:0]);
        end
        checks = checks + 1;
    endtask

    initial begin
        // Literal original map in ascending {a,b,c,d} order.
        expected[0]=0; expected[1]=0; expected[2]=1; expected[3]=1;
        expected[4]=1'bx; expected[5]=0; expected[6]=0; expected[7]=0;
        expected[8]=1; expected[9]=1'bx; expected[10]=1; expected[11]=1;
        expected[12]=1; expected[13]=1'bx; expected[14]=1; expected[15]=1;
        for (integer i=0; i<16; i=i+1) check_input(i);
        for (integer i=15; i>=0; i=i-1) check_input(i);
        $display("PASS: %0d checks; all 16 inputs in both orders, 13 specified cells per sweep", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "FAIL simulation watchdog");
    end
endmodule
