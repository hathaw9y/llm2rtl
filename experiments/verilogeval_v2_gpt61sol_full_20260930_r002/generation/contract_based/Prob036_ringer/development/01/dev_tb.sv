`timescale 1ns/1ps
module dev_tb;
    logic ring;
    logic vibrate_mode;
    wire ringer;
    wire motor;
    integer checks = 0;
    integer source_case;
    integer destination_case;

    TopModule dut (.ring(ring), .vibrate_mode(vibrate_mode),
                   .ringer(ringer), .motor(motor));

    task automatic apply_and_check(input logic call_active, input logic mode);
        logic [1:0] expected;
        begin
            // Truth table is ordered {ringer, motor} and derives from the prose.
            case ({call_active, mode})
                2'b00: expected = 2'b00;
                2'b01: expected = 2'b00;
                2'b10: expected = 2'b10;
                2'b11: expected = 2'b01;
                default: $fatal(1, "Invalid test stimulus");
            endcase
            ring = call_active;
            vibrate_mode = mode;
            #1;
            if ({ringer, motor} !== expected)
                $fatal(1, "ring=%b mode=%b expected=%b observed=%b%b",
                       ring, vibrate_mode, expected, ringer, motor);
            if ((ringer === 1'b1) && (motor === 1'b1))
                $fatal(1, "Alerts must be mutually exclusive");
            checks = checks + 1;
        end
    endtask

    initial begin
        // Enumerate every ordered transition, including unchanged inputs.
        for (source_case = 0; source_case < 4; source_case = source_case + 1) begin
            for (destination_case = 0; destination_case < 4;
                 destination_case = destination_case + 1) begin
                apply_and_check(source_case[1], source_case[0]);
                apply_and_check(destination_case[1], destination_case[0]);
            end
        end
        $display("PASS: all %0d truth-table and transition checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
