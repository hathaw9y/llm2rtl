`timescale 1ns/1ps
module dev_tb;
    logic clk = 0;
    logic w = 0, R = 0, E = 0, L = 0;
    wire Q;
    logic expected = 1'bx;
    integer checks = 0;
    integer prior, combination;
    TopModule dut (.clk(clk), .w(w), .R(R), .E(E), .L(L), .Q(Q));

    task automatic check_output;
        begin
            if (Q !== expected)
                $fatal(1, "Q mismatch at %0t: expected %b got %b L=%b E=%b R=%b w=%b", $time, expected, Q, L, E, R, w);
            checks = checks + 1;
        end
    endtask

    task automatic cycle(input logic load, enable_shift, load_data, shift_data);
        begin
            // Inputs change while clock is low; neither these changes nor
            // the falling edge may update the stored value.
            L = load; E = enable_shift; R = load_data; w = shift_data;
            #2;
            check_output();
            clk = 1;
            // Oracle from specified load, shift, and hold operations.
            case ({load, enable_shift})
                2'b10, 2'b11: expected = load_data;
                2'b01: expected = shift_data;
                2'b00: begin end
            endcase
            #1;
            check_output();
            #2;
            clk = 0;
            #1;
            check_output();
        end
    endtask

    initial begin
        #1;
        check_output();
        cycle(0, 0, 0, 1); // Holding an uninitialized register.
        cycle(0, 0, 1, 0);
        // Exhaustive binary inputs starting from each stored state.
        for (prior = 0; prior < 2; prior = prior + 1) begin
            for (combination = 0; combination < 16; combination = combination + 1) begin
                cycle(1, 0, prior[0], ~prior[0]);
                cycle(combination[3], combination[2], combination[1], combination[0]);
            end
        end
        cycle(0, 1, 0, 1);
        cycle(0, 1, 1, 0);
        cycle(1, 1, 1, 0);
        cycle(1, 1, 0, 1);
        cycle(0, 0, 1, 1);
        $display("PASS: %0d checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
