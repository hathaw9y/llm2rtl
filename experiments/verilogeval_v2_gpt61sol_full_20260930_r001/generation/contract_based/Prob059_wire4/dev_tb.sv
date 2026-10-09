`timescale 1ns/1ps
module dev_tb;
    logic a, b, c;
    wire w, x, y, z;
    integer i, j, k;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .w(w), .x(x), .y(y), .z(z));

    function automatic logic value(input integer index);
        case (index)
            0: value = 1'b0;
            1: value = 1'b1;
            2: value = 1'bx;
            3: value = 1'bz;
        endcase
    endfunction

    task automatic check_connections;
        #1;
        if (w !== a || x !== b || y !== b || z !== c)
            $fatal(1, "FAIL: inputs=%b%b%b outputs=%b%b%b%b", a,b,c,w,x,y,z);
        checks = checks + 1;
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            {a,b,c} = i[2:0];
            check_connections();
        end
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                for (k = 0; k < 4; k = k + 1) begin
                    a = value(i);
                    b = value(j);
                    c = value(k);
                    check_connections();
                end
        $display("PASS: %0d connection checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
