module dev_tb;
    logic [5:0] y;
    logic w;
    wire Y1, Y3;
    integer transitions [0:5][0:1];
    integer pass_idx, state_idx, input_idx, index, destination, checks;
    TopModule dut (.y(y), .w(w), .Y1(Y1), .Y3(Y3));
    initial begin
        #100;
        $fatal(1, "FAIL: watchdog timeout");
    end
    initial begin
        transitions[0][0] = 1; transitions[0][1] = 0;
        transitions[1][0] = 2; transitions[1][1] = 3;
        transitions[2][0] = 4; transitions[2][1] = 3;
        transitions[3][0] = 5; transitions[3][1] = 0;
        transitions[4][0] = 4; transitions[4][1] = 3;
        transitions[5][0] = 2; transitions[5][1] = 3;
        checks = 0;
        for (pass_idx = 0; pass_idx < 2; pass_idx = pass_idx + 1) begin
            for (index = 0; index < 12; index = index + 1) begin
                state_idx = (pass_idx == 0) ? index / 2 : 5 - index / 2;
                input_idx = (pass_idx == 0) ? index % 2 : 1 - index % 2;
                y = 6'b000001 << state_idx;
                w = (input_idx == 1);
                destination = transitions[state_idx][input_idx];
                #1;
                if (Y1 !== (destination == 1) || Y3 !== (destination == 3))
                    $fatal(1, "FAIL: state=%0d w=%0d Y1=%b Y3=%b destination=%0d", state_idx, input_idx, Y1, Y3, destination);
                checks = checks + 1;
            end
        end
        $display("PASS: %0d checks covering all 12 legal transitions in both orders", checks);
        $finish;
    end
endmodule
