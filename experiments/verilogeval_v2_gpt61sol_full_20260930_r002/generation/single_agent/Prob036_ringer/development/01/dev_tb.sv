`timescale 1ns/1ps
module dev_tb;
    logic ring;
    logic vibrate_mode;
    wire ringer;
    wire motor;
    integer source_case;
    integer target_case;
    integer checks = 0;

    TopModule dut (.ring(ring), .vibrate_mode(vibrate_mode),
                   .ringer(ringer), .motor(motor));

    task automatic check_case(input integer stimulus);
        logic [1:0] expected;
        begin
            // Explicit oracle from the incoming-call and mode requirements.
            case (stimulus)
                0: expected = 2'b00; // No call, normal mode.
                1: expected = 2'b00; // No call, vibrate mode.
                2: expected = 2'b10; // Call, normal mode: ringer only.
                3: expected = 2'b01; // Call, vibrate mode: motor only.
                default: $fatal(1, "Invalid stimulus");
            endcase
            ring = (stimulus >= 2);
            vibrate_mode = (stimulus % 2);
            #1;
            if ({ringer, motor} !== expected)
                $fatal(1, "case %0d expected %b got %b", stimulus,
                       expected, {ringer, motor});
            if ((ringer === 1'b1) && (motor === 1'b1))
                $fatal(1, "Ringer and motor both active");
            checks = checks + 1;
        end
    endtask

    initial begin
        // Exercise every ordered transition, including unchanged inputs.
        for (source_case = 0; source_case < 4; source_case = source_case + 1)
            for (target_case = 0; target_case < 4; target_case = target_case + 1) begin
                check_case(source_case);
                check_case(target_case);
            end
        $display("PASS: %0d combinational truth-table checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
