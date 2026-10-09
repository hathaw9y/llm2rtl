module dev_tb;
    logic clk = 0;
    logic j = 0;
    logic k = 0;
    wire Q;
    logic expected;
    integer checks = 0;
    TopModule dut (.clk(clk), .j(j), .k(k), .Q(Q));

    task automatic step(input logic jj, input logic kk);
        logic old_q;
        begin
            old_q = Q;
            j = jj;
            k = kk;
            #2;
            if (Q !== old_q) $fatal(1, "Output changed without rising edge");
            case ({jj, kk})
                2'b00: expected = old_q;
                2'b01: expected = 0;
                2'b10: expected = 1;
                2'b11: expected = ~old_q;
            endcase
            clk = 1;
            #1;
            if (Q !== expected) $fatal(1, "JK mismatch j=%b k=%b expected=%b Q=%b", j, k, expected, Q);
            clk = 0;
            #1;
            if (Q !== expected) $fatal(1, "Output changed at falling edge");
            checks = checks + 1;
        end
    endtask

    initial begin
        step(0, 0);
        step(1, 1);
        step(0, 1);
        for (integer state_value = 0; state_value < 2; state_value++) begin
            for (integer inputs_value = 0; inputs_value < 4; inputs_value++) begin
                if (state_value == 0) step(0, 1);
                else step(1, 0);
                step((inputs_value >> 1) & 1, inputs_value & 1);
            end
        end
        repeat (10) step(1, 1);
        $display("PASS: %0d JK and edge checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end
endmodule
