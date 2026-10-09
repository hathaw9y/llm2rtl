`timescale 1ns/1ps
module dev_tb;
    reg [1023:0] in;
    reg [7:0] sel;
    wire [3:0] out;
    integer s, v, k, b, checks;
    reg [3:0] expected;
    TopModule dut (.in(in), .sel(sel), .out(out));

    task check;
        integer bit_number;
        begin
            #1;
            // Original specification: group s starts at bit 4*s.
            // Build the oracle one bit at a time, without a part-select.
            for (bit_number=0; bit_number<4; bit_number=bit_number+1)
                expected[bit_number] = in[4*sel+bit_number];
            if (out !== expected)
                $fatal(1, "Mismatch selector=%0d expected=%b got=%b", sel, expected, out);
            checks = checks+1;
        end
    endtask

    initial begin
        checks=0;
        in=0;
        sel=0;
        check;
        in={1024{1'b1}};
        sel=255;
        check;
        // Every nibble value at every selector, surrounded by its complement.
        for (s=0; s<256; s=s+1) begin
            sel=s;
            for (v=0; v<16; v=v+1) begin
                for (k=0; k<256; k=k+1)
                    for (b=0; b<4; b=b+1)
                        in[4*k+b]=~((v >> b) & 1);
                for (b=0; b<4; b=b+1)
                    in[4*s+b]=(v >> b) & 1;
                check;
            end
        end
        // Each input bit is selected and rejected by all selector settings.
        for (k=0; k<1024; k=k+1) begin
            in=0;
            in[k]=1'b1;
            for (s=0; s<256; s=s+1) begin
                sel=s;
                check;
            end
        end
        // Data changes with fixed selector, including four-state data.
        sel=128;
        in=0;
        check;
        in[0]=1;
        in[1023]=1;
        check;
        in[512]=1;
        check;
        in[513]=1'bx;
        in[514]=1'bz;
        check;
        sel=0;
        check;
        sel=128;
        check;
        $display("PASS: %0d multiplexer checks", checks);
        $finish;
    end
    initial begin
        #300000;
        $fatal(1, "Timeout");
    end
endmodule
