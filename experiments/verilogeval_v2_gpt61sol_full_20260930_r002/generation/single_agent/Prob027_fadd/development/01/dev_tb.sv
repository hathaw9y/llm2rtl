`timescale 1ns/1ps
module dev_tb;
    logic a, b, cin;
    wire cout, sum;
    integer vector_index;
    integer expected;

    TopModule dut (.a(a), .b(b), .cin(cin), .cout(cout), .sum(sum));

    initial begin
        for (vector_index = 0; vector_index < 8; vector_index = vector_index + 1) begin
            {a, b, cin} = vector_index[2:0];
            expected = integer'(a) + integer'(b) + integer'(cin);
            #1;
            if ({cout, sum} !== expected[1:0])
                $fatal(1, "Mismatch a=%b b=%b cin=%b: got %b%b expected %b", a, b, cin, cout, sum, expected[1:0]);
        end
        // Repeat in reverse order to check combinational responses to transitions.
        for (vector_index = 7; vector_index >= 0; vector_index = vector_index - 1) begin
            {a, b, cin} = vector_index[2:0];
            expected = integer'(a) + integer'(b) + integer'(cin);
            #1;
            if ({cout, sum} !== expected[1:0])
                $fatal(1, "Reverse mismatch a=%b b=%b cin=%b: got %b%b expected %b", a, b, cin, cout, sum, expected[1:0]);
        end
        $display("PASS full adder: all eight combinations checked in both orders");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
