`timescale 1ns/1ps
module dev_tb;
    reg a, b, c;
    wire w, x, y, z;
    integer ia, ib, ic;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .c(c), .w(w), .x(x), .y(y), .z(z));

    function automatic reg stimulus_value(input integer index);
        case (index)
            0: stimulus_value = 1'b0;
            1: stimulus_value = 1'b1;
            2: stimulus_value = 1'bx;
            3: stimulus_value = 1'bz;
        endcase
    endfunction

    task automatic check_connections;
        begin
            if (w !== a || x !== b || y !== b || z !== c)
                $fatal(1, "Wire mismatch: a=%b b=%b c=%b w=%b x=%b y=%b z=%b", a,b,c,w,x,y,z);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Undriven regs begin unknown; continuous wires must propagate them.
        #1;
        check_connections();
        for (ia = 0; ia < 4; ia = ia + 1)
            for (ib = 0; ib < 4; ib = ib + 1)
                for (ic = 0; ic < 4; ic = ic + 1) begin
                    a = stimulus_value(ia);
                    b = stimulus_value(ib);
                    c = stimulus_value(ic);
                    #1;
                    check_connections();
                end
        $display("PASS: %0d wire connection checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
