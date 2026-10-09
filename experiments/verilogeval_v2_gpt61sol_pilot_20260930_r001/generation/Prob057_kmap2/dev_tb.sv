module dev_tb;
    logic a,b,c,d,out;
    logic [3:0] row;
    logic expected;
    integer i;
    TopModule dut(.a(a),.b(b),.c(c),.d(d),.out(out));
    initial begin
        for (i=0; i<16; i=i+1) begin
            {a,b,c,d}=i[3:0];
            case ({c,d})
                2'b00: row=4'b0111;
                2'b01: row=4'b0101;
                2'b11: row=4'b1110;
                2'b10: row=4'b0011;
            endcase
            expected=row[{a,b}];
            #1;
            if(out !== expected) $fatal(1,"FAIL abcd=%b expected=%b actual=%b",{a,b,c,d},expected,out);
        end
        $display("PASS: all 16 binary K-map cells checked");
        $finish;
    end
endmodule
