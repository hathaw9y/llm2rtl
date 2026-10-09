module dev_tb;
    logic [99:0] in;
    wire out_and, out_or, out_xor;
    integer checks = 0;
    integer seed = 32'h052100;
    TopModule dut (.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));

    task automatic check(input logic [99:0] vector);
        integer count;
        logic expected_and, expected_or, expected_xor;
        begin
            count = 0;
            for (integer bit_index = 0; bit_index < 100; bit_index = bit_index + 1)
                if (vector[bit_index]) count = count + 1;
            expected_and = (count == 100);
            expected_or = (count != 0);
            expected_xor = ((count % 2) == 1);
            in = vector;
            #1;
            if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                $fatal(1, "FAIL vector=%h count=%0d outputs=%b%b%b", vector, count, out_and, out_or, out_xor);
            checks = checks + 1;
        end
    endtask

    logic [99:0] vector;
    initial begin
        check('0);
        check('1);
        for (integer index = 0; index < 100; index = index + 1) begin
            vector = '0;
            vector[index] = 1'b1;
            check(vector);
            vector = '1;
            vector[index] = 1'b0;
            check(vector);
        end
        for (integer index = 0; index < 100; index = index + 1)
            vector[index] = (index % 2 == 0);
        check(vector);
        check(~vector);
        for (integer population = 0; population <= 100; population = population + 1) begin
            vector = '0;
            for (integer index = 0; index < population; index = index + 1)
                vector[index] = 1'b1;
            check(vector);
        end
        for (integer trial = 0; trial < 1000; trial = trial + 1) begin
            for (integer index = 0; index < 100; index = index + 1)
                vector[index] = ($random(seed) & 1);
            check(vector);
        end
        $display("PASS: %0d binary vectors checked", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
