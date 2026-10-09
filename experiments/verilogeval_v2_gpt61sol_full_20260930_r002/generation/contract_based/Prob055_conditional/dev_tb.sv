`timescale 1ns/1ps
module dev_tb;
    logic [7:0] a, b, c, d;
    wire [7:0] min;
    integer checks = 0;
    integer value, position, i, j, k, l;
    integer boundary [0:5];
    logic [31:0] prng = 32'h7329a15b;
    logic [7:0] ra, rb, rc, rd;
    TopModule dut (.a(a), .b(b), .c(c), .d(d), .min(min));

    task automatic check_case(input integer va, vb, vc, vd);
        integer expected;
        integer inputs [0:3];
        integer index;
        begin
            inputs[0] = va; inputs[1] = vb;
            inputs[2] = vc; inputs[3] = vd;
            expected = 256;
            for (index = 0; index < 4; index = index + 1)
                if (inputs[index] < expected) expected = inputs[index];
            a = va; b = vb; c = vc; d = vd;
            #1;
            if (min !== expected[7:0])
                $fatal(1, "minimum mismatch a=%0d b=%0d c=%0d d=%0d expected=%0d actual=%0d", va, vb, vc, vd, expected, min);
            checks = checks + 1;
        end
    endtask

    task automatic next_byte(output logic [7:0] result);
        begin
            prng = prng ^ (prng << 13);
            prng = prng ^ (prng >> 17);
            prng = prng ^ (prng << 5);
            result = prng[7:0];
        end
    endtask

    initial begin
        boundary[0]=0; boundary[1]=1; boundary[2]=127;
        boundary[3]=128; boundary[4]=254; boundary[5]=255;
        for (value=0; value<256; value=value+1) begin
            check_case(value,value,value,value);
            check_case(value,255,255,255);
            check_case(255,value,255,255);
            check_case(255,255,value,255);
            check_case(255,255,255,value);
        end
        for (i=0; i<6; i=i+1)
            for (j=0; j<6; j=j+1)
                for (k=0; k<6; k=k+1)
                    for (l=0; l<6; l=l+1)
                        check_case(boundary[i],boundary[j],boundary[k],boundary[l]);
        for (i=0; i<10000; i=i+1) begin
            next_byte(ra); next_byte(rb); next_byte(rc); next_byte(rd);
            check_case(ra,rb,rc,rd);
        end
        $display("PASS minimum checks=%0d", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1,"Timeout");
    end
endmodule
