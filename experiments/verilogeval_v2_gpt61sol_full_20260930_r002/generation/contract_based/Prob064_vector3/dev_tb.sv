`timescale 1ns/1ps
module dev_tb;
    logic [4:0] a, b, c, d, e, f;
    wire [7:0] w, x, y, z;
    logic [29:0] stimulus;
    logic [31:0] expected;
    logic [31:0] prng = 32'h482b193d;
    integer checks = 0;
    integer i, j, k;

    TopModule dut (.a(a), .b(b), .c(c), .d(d), .e(e), .f(f),
                   .w(w), .x(x), .y(y), .z(z));

    task automatic check(input logic [29:0] value);
        logic [4:0] inputs_by_order [0:5];
        integer port_index, bit_index, output_index;
        begin
            a = value[29:25]; b = value[24:20]; c = value[19:15];
            d = value[14:10]; e = value[9:5]; f = value[4:0];
            inputs_by_order[0] = a; inputs_by_order[1] = b;
            inputs_by_order[2] = c; inputs_by_order[3] = d;
            inputs_by_order[4] = e; inputs_by_order[5] = f;
            expected = 32'b0;
            expected[0] = 1'b1;
            expected[1] = 1'b1;
            for (port_index = 0; port_index < 6; port_index = port_index + 1)
                for (bit_index = 0; bit_index < 5; bit_index = bit_index + 1) begin
                    output_index = 2 + 5*(5-port_index) + bit_index;
                    expected[output_index] = inputs_by_order[port_index][bit_index];
                end
            #1;
            if (w !== expected[31:24] || x !== expected[23:16] ||
                y !== expected[15:8] || z !== expected[7:0])
                $fatal(1, "Mismatch inputs=%b expected=%b actual=%b", value, expected, {w,x,y,z});
            checks = checks + 1;
        end
    endtask

    initial begin
        check(30'b0);
        check({30{1'b1}});
        for (i = 0; i < 30; i = i + 1) begin
            check(30'b1 << i);
            check(~(30'b1 << i));
        end
        for (j = 0; j < 6; j = j + 1)
            for (k = 0; k < 32; k = k + 1) begin
                stimulus = 30'b0;
                stimulus[j*5 +: 5] = k[4:0];
                check(stimulus);
            end
        for (i = 0; i < 1000; i = i + 1) begin
            prng = prng ^ (prng << 13);
            prng = prng ^ (prng >> 17);
            prng = prng ^ (prng << 5);
            check(prng[29:0]);
        end
        check({30{1'bx}});
        check({30{1'bz}});
        for (i = 0; i < 30; i = i + 1) begin
            stimulus = 30'b0;
            stimulus[i] = 1'bx;
            check(stimulus);
            stimulus = {30{1'b1}};
            stimulus[i] = 1'bz;
            check(stimulus);
        end
        $display("PASS %0d combinational checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
