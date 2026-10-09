`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic L = 0;
    logic q_in = 0;
    logic r_in = 0;
    wire Q;
    logic expected = 1'bx;
    integer checks = 0;
    TopModule dut (.clk(clk), .L(L), .q_in(q_in), .r_in(r_in), .Q(Q));

    task automatic check_output;
        begin
            if (Q !== expected)
                $fatal(1, "Mismatch at %0t: Q=%b expected=%b", $time, Q, expected);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input logic load, input logic shift_value, input logic load_value);
        begin
            L = load;
            q_in = shift_value;
            r_in = load_value;
            #2;
            check_output();
            // Sample only at the rising edge, then observe after NBA updates.
            clk = 1;
            if (load === 1'b1)
                expected = load_value;
            else
                expected = shift_value;
            #1;
            check_output();
            // Changing either mux input cannot alter the stored output.
            q_in = ~shift_value;
            r_in = ~load_value;
            L = ~load;
            #1;
            check_output();
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        #1;
        check_output();
        for (integer repeat_index = 0; repeat_index < 3; repeat_index = repeat_index + 1)
            for (integer bits = 0; bits < 8; bits = bits + 1)
                cycle(bits[2], bits[1], bits[0]);
        cycle(1'b0, 1'bx, 1'b1);
        cycle(1'b1, 1'b0, 1'bx);
        cycle(1'b0, 1'b1, 1'bx);
        cycle(1'b1, 1'bx, 1'b0);
        cycle(1'b0, 1'bz, 1'b0);
        cycle(1'b1, 1'b1, 1'bz);
        cycle(1'b1, 1'b0, 1'b1);
        $display("PASS: %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
