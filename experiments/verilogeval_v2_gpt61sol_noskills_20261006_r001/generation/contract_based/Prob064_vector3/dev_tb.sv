`timescale 1ns/1ps
module dev_tb;
    reg [4:0] a, b, c, d, e, f;
    wire [7:0] w, x, y, z;
    reg [29:0] stimulus;
    reg [31:0] expected;
    reg [4:0] source_vector;
    integer i, j, k;
    integer checks = 0;
    TopModule dut(.a(a), .b(b), .c(c), .d(d), .e(e), .f(f),
                  .w(w), .x(x), .y(y), .z(z));

    task check;
        begin
            // Independent bitwise oracle: f first in ascending bit positions.
            expected = 32'b0;
            expected[0] = 1'b1;
            expected[1] = 1'b1;
            for (integer group_index = 0; group_index < 6; group_index = group_index + 1) begin
                case (group_index)
                    0: source_vector = f;
                    1: source_vector = e;
                    2: source_vector = d;
                    3: source_vector = c;
                    4: source_vector = b;
                    5: source_vector = a;
                endcase
                for (integer bit_index = 0; bit_index < 5; bit_index = bit_index + 1)
                    expected[2 + 5*group_index + bit_index] = source_vector[bit_index];
            end
            #1;
            if (w !== expected[31:24] || x !== expected[23:16] ||
                y !== expected[15:8] || z !== expected[7:0])
                $fatal(1, "Mismatch check %0d: got %h expected %h", checks, {w,x,y,z}, expected);
            checks = checks + 1;
        end
    endtask

    task apply_stimulus;
        begin
            a = stimulus[29:25]; b = stimulus[24:20];
            c = stimulus[19:15]; d = stimulus[14:10];
            e = stimulus[9:5]; f = stimulus[4:0];
            check;
        end
    endtask

    initial begin
        stimulus = 0; apply_stimulus;
        stimulus = {30{1'b1}}; apply_stimulus;
        for (i = 0; i < 30; i = i + 1) begin
            stimulus = 30'b1 << i; apply_stimulus;
            stimulus = ~(30'b1 << i); apply_stimulus;
        end
        for (j = 0; j < 6; j = j + 1)
            for (k = 0; k < 32; k = k + 1) begin
                stimulus = k << (5*j); apply_stimulus;
            end
        stimulus = 30'h13579bdf;
        for (i = 0; i < 500; i = i + 1) begin
            stimulus = {stimulus[28:0], stimulus[29] ^ stimulus[5] ^ stimulus[3] ^ stimulus[0]};
            apply_stimulus;
        end
        stimulus = {30{1'bx}}; apply_stimulus;
        stimulus = {30{1'bz}}; apply_stimulus;
        for (i = 0; i < 30; i = i + 1) begin
            stimulus = 0; stimulus[i] = 1'bx; apply_stimulus;
            stimulus = {30{1'b1}}; stimulus[i] = 1'bz; apply_stimulus;
        end
        $display("PASS: %0d independent combinational checks", checks);
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
