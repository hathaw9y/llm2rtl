module dev_tb;
    logic clk = 0;
    logic load = 0;
    logic [1:0] ena = 0;
    logic [99:0] data = 0;
    wire [99:0] q;
    logic [99:0] expected;
    logic [99:0] previous;
    integer checks = 0;
    TopModule dut (.clk(clk), .load(load), .ena(ena), .data(data), .q(q));
    always #5 clk = ~clk;

    task automatic step(input logic ld, input logic [1:0] en,
                        input logic [99:0] value);
        @(negedge clk);
        previous = expected;
        load = ld;
        ena = en;
        data = value;
        #1;
        if (checks > 0 && q !== previous)
            $fatal(1, "Output changed before rising edge");
        if (ld)
            expected = value;
        else if (en == 2'b01)
            for (integer b = 0; b < 100; b = b + 1)
                expected[b] = previous[(b + 1) % 100];
        else if (en == 2'b10)
            for (integer b = 0; b < 100; b = b + 1)
                expected[b] = previous[(b + 99) % 100];
        @(posedge clk);
        #1;
        if (q !== expected)
            $fatal(1, "Mismatch at check %0d: got %h expected %h", checks, q, expected);
        checks = checks + 1;
    endtask

    initial begin
        step(1, 0, 100'b1);
        repeat (100) step(0, 2'b01, 0);
        repeat (100) step(0, 2'b10, 0);
        step(0, 2'b00, '1);
        step(0, 2'b11, '1);
        for (integer en = 0; en < 4; en = en + 1)
            step(1, en[1:0], 100'hA123456789ABCDEF0123456789);
        step(1, 0, '0);
        step(0, 1, 0);
        step(1, 0, '1);
        step(0, 2, 0);
        repeat (500) begin
            step($urandom_range(0, 4) == 0, $urandom_range(0, 3),
                 {$urandom, $urandom, $urandom, $urandom});
        end
        $display("PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Testbench timeout");
    end
endmodule
