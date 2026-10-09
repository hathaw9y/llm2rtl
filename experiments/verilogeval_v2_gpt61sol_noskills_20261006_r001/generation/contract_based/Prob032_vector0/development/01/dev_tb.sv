`timescale 1ns/1ps
module dev_tb;
    reg [2:0] vec;
    wire [2:0] outv;
    wire o2, o1, o0;
    integer i;
    TopModule dut(.vec(vec), .outv(outv), .o2(o2), .o1(o1), .o0(o0));

    task check_value(input reg [2:0] value);
        begin
            vec = value;
            #1;
            if (outv !== value || o0 !== value[0] ||
                o1 !== value[1] || o2 !== value[2])
                $fatal(1, "vec=%b outv=%b o2=%b o1=%b o0=%b", value, outv, o2, o1, o0);
        end
    endtask

    initial begin
        // With no specified initialization, undriven input starts unknown.
        #1;
        if (outv !== 3'bxxx || {o2,o1,o0} !== 3'bxxx)
            $fatal(1, "Initial unknown input must propagate");
        for (i = 0; i < 8; i = i + 1)
            check_value(i[2:0]);
        for (i = 7; i >= 0; i = i - 1)
            check_value(i[2:0]);
        check_value(3'bx01);
        check_value(3'b1x0);
        check_value(3'b01x);
        check_value(3'bz10);
        check_value(3'b0z1);
        check_value(3'b10z);
        check_value(3'bzzz);
        check_value(3'b000);
        $display("PASS: exhaustive vector and individual bit connections");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
