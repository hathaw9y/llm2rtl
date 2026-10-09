`timescale 1ns/1ps
module dev_tb;
    reg ring;
    reg vibrate_mode;
    wire ringer;
    wire motor;
    integer previous;
    integer current;
    integer count;
    TopModule dut (.ring(ring), .vibrate_mode(vibrate_mode),
                   .ringer(ringer), .motor(motor));

    task check_case(input reg call_active, input reg vibration);
        reg [1:0] expected;
        begin
            ring = call_active;
            vibrate_mode = vibration;
            // Oracle: no call leaves both off; a call selects one actuator.
            if (!call_active)
                expected = 2'b00;
            else if (vibration)
                expected = 2'b01;
            else
                expected = 2'b10;
            #1;
            if ({ringer, motor} !== expected)
                $fatal(1, "ring=%b mode=%b expected=%b actual=%b%b",
                       ring, vibrate_mode, expected, ringer, motor);
            if (ringer && motor)
                $fatal(1, "Both actuators active");
            count = count + 1;
        end
    endtask

    initial begin
        count = 0;
        // Exercise every binary input combination and every directed transition.
        for (previous = 0; previous < 4; previous = previous + 1) begin
            for (current = 0; current < 4; current = current + 1) begin
                check_case(previous[1], previous[0]);
                check_case(current[1], current[0]);
            end
        end
        $display("PASS: %0d combinational checks", count);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
