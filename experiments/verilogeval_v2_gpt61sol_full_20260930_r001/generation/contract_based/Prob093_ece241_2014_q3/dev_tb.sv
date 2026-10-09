`timescale 1ns/1ps
module dev_tb;
    logic c, d;
    wire [3:0] mux_in;
    logic [3:0] expected;
    integer row, selector, pass_index, checks;
    TopModule dut (.c(c), .d(d), .mux_in(mux_in));

    // Literal original K-map entries in binary ab order.
    function automatic logic kmap(input integer cd_index, input integer ab_index);
        case (cd_index)
            0: case (ab_index)
                0: kmap=0; 1: kmap=0; 2: kmap=1; 3: kmap=0;
            endcase
            1: case (ab_index)
                0: kmap=1; 1: kmap=0; 2: kmap=0; 3: kmap=0;
            endcase
            2: case (ab_index)
                0: kmap=1; 1: kmap=0; 2: kmap=1; 3: kmap=0;
            endcase
            3: case (ab_index)
                0: kmap=1; 1: kmap=0; 2: kmap=1; 3: kmap=1;
            endcase
            default: kmap=1'bx;
        endcase
    endfunction

    initial begin
        checks=0;
        for (pass_index=0; pass_index<2; pass_index=pass_index+1) begin
            for (integer i=0; i<4; i=i+1) begin
                row = pass_index == 0 ? i : 3-i;
                {c,d}=2'(row);
                for (selector=0; selector<4; selector=selector+1)
                    expected[selector]=kmap(row,selector);
                #1;
                if (mux_in !== expected)
                    $fatal(1,"cd=%b%b expected=%b actual=%b", c,d,expected,mux_in);
                for (selector=0; selector<4; selector=selector+1) begin
                    if (mux_in[selector] !== kmap(row,selector))
                        $fatal(1,"K-map mismatch row=%0d selector=%0d",row,selector);
                    checks=checks+1;
                end
            end
        end
        $display("PASS: 8 vector checks and %0d external selector checks",checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1,"Development simulation timeout");
    end
endmodule
