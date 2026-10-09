`timescale 1ns/1ps
module dev_tb;
    logic [254:0] in;
    wire [7:0] out;
    logic [254:0] vector_value;
    integer i, j, n;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    // Count by repeatedly removing the lowest set bit.
    function automatic integer oracle(input logic [254:0] value);
        logic [254:0] remaining;
        integer count;
        begin
            remaining = value;
            count = 0;
            while (remaining != 255'd0) begin
                remaining = remaining & (remaining - 255'd1);
                count = count + 1;
            end
            oracle = count;
        end
    endfunction

    task automatic check_vector(input logic [254:0] value);
        integer expected;
        begin
            expected = oracle(value);
            in = value;
            #1;
            if (out !== expected[7:0])
                $fatal(1, "Mismatch vector=%h expected=%0d actual=%0d", value, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector(255'd0);
        check_vector({255{1'b1}});
        // Exercise every possible count, including 127/128 and 254/255.
        vector_value = 255'd0;
        for (n = 0; n <= 255; n = n + 1) begin
            check_vector(vector_value);
            if (n < 255) vector_value[n] = 1'b1;
        end
        for (i = 0; i < 255; i = i + 1) begin
            vector_value = 255'd0;
            vector_value[i] = 1'b1;
            check_vector(vector_value);
            check_vector(~vector_value);
        end
        for (i = 0; i < 255; i = i + 1)
            vector_value[i] = (i % 2 == 0);
        check_vector(vector_value);
        check_vector(~vector_value);
        for (j = 0; j < 1000; j = j + 1) begin
            for (i = 0; i < 255; i = i + 1)
                vector_value[i] = $urandom_range(0, 1);
            check_vector(vector_value);
        end
        $display("PASS population count: %0d vectors", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
