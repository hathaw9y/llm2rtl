`timescale 1ns/1ps
module dev_tb;
    reg a, b, c;
    wire w, x, y, z;
    integer i, j, k;
    reg [1:0] va, vb, vc;
    TopModule dut (.a(a), .b(b), .c(c), .w(w), .x(x), .y(y), .z(z));

    function automatic reg value(input integer index);
        case (index)
            0: value = 1'b0;
            1: value = 1'b1;
            2: value = 1'bx;
            3: value = 1'bz;
        endcase
    endfunction

    task automatic check_connections;
        begin
            #1;
            if (w !== a || x !== b || y !== b || z !== c)
                $fatal(1, "Wire mismatch: a=%b b=%b c=%b w=%b x=%b y=%b z=%b", a,b,c,w,x,y,z);
        end
    endtask

    initial begin
        // Uninitialized inputs and every binary/four-state combination.
        check_connections();
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                for (k = 0; k < 4; k = k + 1) begin
                    a = value(i);
                    b = value(j);
                    c = value(k);
                    check_connections();
                end
        $display("PASS: all wire connections across all 64 four-state combinations");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
