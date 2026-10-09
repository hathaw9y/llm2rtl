`timescale 1ns/1ps
module dev_tb;
    reg clk, a, b;
    wire out_assign, out_always_comb, out_always_ff;
    reg held;
    integer i, j;
    TopModule dut (.clk(clk), .a(a), .b(b),
        .out_assign(out_assign), .out_always_comb(out_always_comb),
        .out_always_ff(out_always_ff));

    // Truth-table oracle, including four-state XOR behavior.
    function automatic reg expected(input reg x, input reg y);
        begin
            case ({x,y})
                2'b00, 2'b11: expected = 1'b0;
                2'b01, 2'b10: expected = 1'b1;
                default: expected = 1'bx;
            endcase
        end
    endfunction

    function automatic reg value(input integer n);
        case (n)
            0: value = 1'b0;
            1: value = 1'b1;
            2: value = 1'bx;
            3: value = 1'bz;
        endcase
    endfunction

    task automatic check_outputs;
        begin
            if (out_assign !== expected(a,b))
                $fatal(1, "assign mismatch a=%b b=%b", a,b);
            if (out_always_comb !== expected(a,b))
                $fatal(1, "combinational mismatch a=%b b=%b", a,b);
            if (out_always_ff !== held)
                $fatal(1, "registered mismatch got=%b expected=%b", out_always_ff,held);
        end
    endtask

    initial begin
        clk = 0;
        a = 0;
        b = 0;
        held = 1'bx;
        #1;
        check_outputs();
        for (i=0; i<4; i=i+1) begin
            for (j=0; j<4; j=j+1) begin
                a = value(i);
                b = value(j);
                #1;
                check_outputs(); // Input changes must not clock the register.
                held = expected(a,b);
                clk = 1;
                #1;
                check_outputs(); // Sample after nonblocking assignment settles.
                a = ~value(i);
                b = value(j);
                #1;
                check_outputs(); // Register holds while clock is high.
                clk = 0;
                #1;
                check_outputs(); // Falling edge must not update register.
            end
        end
        $display("PASS XOR truth table, four-state behavior, and positive-edge storage");
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
