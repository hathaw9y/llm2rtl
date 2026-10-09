`timescale 1ns/1ps
module dev_tb;
    logic a, b, cin;
    wire cout, sum;
    integer vector_index;
    integer expected_total;
    integer checks = 0;

    TopModule dut (.a(a), .b(b), .cin(cin), .cout(cout), .sum(sum));

    task automatic check_vector(input integer value);
        begin
            {a, b, cin} = value[2:0];
            expected_total = integer'(a) + integer'(b) + integer'(cin);
            #1;
            if ({cout, sum} !== expected_total[1:0])
                $fatal(1, "a=%b b=%b cin=%b: got %b%b expected %b", a, b, cin, cout, sum, expected_total[1:0]);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (vector_index = 0; vector_index < 8; vector_index = vector_index + 1)
            check_vector(vector_index);
        for (vector_index = 7; vector_index >= 0; vector_index = vector_index - 1)
            check_vector(vector_index);
        $display("PASS full adder: %0d checks covering all eight binary combinations", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
