`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic reset = 0;
    logic [7:0] d = 8'hff;
    wire [7:0] q;
    logic [7:0] expected;
    integer checks = 0;
    integer value;

    TopModule dut (.clk(clk), .reset(reset), .d(d), .q(q));

    task automatic check(input logic [7:0] wanted);
        begin
            if (q !== wanted)
                $fatal(1, "Mismatch at %0t: q=%h expected=%h reset=%b d=%h clk=%b",
                       $time, q, wanted, reset, d, clk);
            checks = checks + 1;
        end
    endtask

    task automatic rising_edge;
        begin
            // Oracle follows the original specification, sampling before edge.
            if (reset == 1'b1) expected = 8'h00;
            else expected = d;
            clk = 1;
            #1;
            check(expected);
        end
    endtask

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end

    initial begin
        // No initial q expectation: the specification gives no power-up value.
        #2;
        reset = 1;
        #2;
        rising_edge();
        #2;
        clk = 0;
        #1;
        check(8'h00);
        reset = 0;
        d = 8'ha5;
        #1;
        check(8'h00);
        rising_edge();
        #2;
        clk = 0;
        #1;
        check(8'ha5);

        // A reset pulse entirely between rising edges must not clear q.
        reset = 1;
        d = 8'h3c;
        #1;
        check(8'ha5);
        reset = 0;
        #1;
        check(8'ha5);
        rising_edge();
        #2;
        clk = 0;
        #1;
        check(8'h3c);

        for (value = 0; value < 256; value = value + 1) begin
            d = value[7:0];
            reset = 0;
            #1;
            check(expected);
            rising_edge();
            // Mutating data while clk is high cannot change stored q.
            d = ~value[7:0];
            #1;
            check(expected);
            clk = 0;
            #1;
            check(expected);
            // Periodically hold reset across multiple rising edges.
            if ((value % 17) == 0) begin
                reset = 1;
                d = 8'hff;
                #1;
                check(expected);
                rising_edge();
                #1;
                clk = 0;
                #1;
                check(8'h00);
                d = 8'h81;
                #1;
                rising_edge();
                #1;
                clk = 0;
                #1;
                check(8'h00);
                reset = 0;
                #1;
                check(8'h00);
            end
        end
        $display("PASS: synchronous reset, exhaustive data capture, and edge hold (%0d checks)", checks);
        $finish;
    end
endmodule
