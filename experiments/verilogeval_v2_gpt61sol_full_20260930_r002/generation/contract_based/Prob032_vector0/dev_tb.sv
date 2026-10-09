`timescale 1ns/1ps
module dev_tb;
    logic [2:0] vec;
    wire [2:0] outv;
    wire o2, o1, o0;
    integer checks = 0;
    integer n, a, b, c;

    TopModule dut (.vec(vec), .outv(outv), .o2(o2), .o1(o1), .o0(o0));

    function automatic logic symbol(input integer index);
        case (index)
            0: symbol = 1'b0;
            1: symbol = 1'b1;
            2: symbol = 1'bx;
            3: symbol = 1'bz;
            default: symbol = 1'bx;
        endcase
    endfunction

    task automatic check_vector(input logic [2:0] stimulus);
        begin
            vec = stimulus;
            #1;
            if (outv !== stimulus || o0 !== stimulus[0] ||
                o1 !== stimulus[1] || o2 !== stimulus[2])
                $fatal(1, "vec=%b outv=%b o2/o1/o0=%b%b%b", stimulus, outv, o2, o1, o0);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No initialized state is specified; undriven logic starts unknown.
        #1;
        if (outv !== 3'bxxx || {o2, o1, o0} !== 3'bxxx)
            $fatal(1, "Initial unknown input did not propagate");
        checks = checks + 1;
        for (n = 0; n < 8; n = n + 1)
            check_vector(n[2:0]);
        for (n = 7; n >= 0; n = n - 1)
            check_vector(n[2:0]);
        for (a = 0; a < 4; a = a + 1)
            for (b = 0; b < 4; b = b + 1)
                for (c = 0; c < 4; c = c + 1)
                    check_vector({symbol(a), symbol(b), symbol(c)});
        $display("PASS: %0d vector identity and bit-position checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
