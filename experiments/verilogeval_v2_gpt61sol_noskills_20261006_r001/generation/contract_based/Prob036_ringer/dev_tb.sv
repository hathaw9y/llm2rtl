`timescale 1ns/1ps
module dev_tb;
    reg ring;
    reg vibrate_mode;
    wire ringer;
    wire motor;
    integer source_case;
    integer destination_case;
    integer checks = 0;

    TopModule dut (.ring(ring), .vibrate_mode(vibrate_mode),
                   .ringer(ringer), .motor(motor));

    task check_case(input integer stimulus);
        reg [1:0] expected;
        begin
            case (stimulus)
                0: begin ring = 0; vibrate_mode = 0; expected = 2'b00; end
                1: begin ring = 0; vibrate_mode = 1; expected = 2'b00; end
                2: begin ring = 1; vibrate_mode = 0; expected = 2'b10; end
                3: begin ring = 1; vibrate_mode = 1; expected = 2'b01; end
                default: $fatal(1, "Invalid stimulus");
            endcase
            #1;
            if ({ringer, motor} !== expected)
                $fatal(1, "case %0d: expected %b, observed %b", stimulus, expected, {ringer, motor});
            if (ringer === 1'b1 && motor === 1'b1)
                $fatal(1, "Ringer and motor active simultaneously");
            checks = checks + 1;
        end
    endtask

    initial begin
        for (source_case = 0; source_case < 4; source_case = source_case + 1)
            for (destination_case = 0; destination_case < 4; destination_case = destination_case + 1) begin
                check_case(source_case);
                check_case(destination_case);
            end
        $display("PASS: %0d truth-table and transition checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
