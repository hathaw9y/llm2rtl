`timescale 1ns/1ps
module dev_tb;
    logic ring;
    logic vibrate_mode;
    logic ringer;
    logic motor;
    TopModule dut (.ring(ring), .vibrate_mode(vibrate_mode),
                   .ringer(ringer), .motor(motor));
    initial begin
        for (int i = 0; i < 4; i++) begin
            {ring, vibrate_mode} = 2'(i);
            #1;
            case (i)
                0, 1: if ({ringer, motor} !== 2'b00) $fatal(1, "Idle outputs incorrect");
                2: if ({ringer, motor} !== 2'b10) $fatal(1, "Ringer mode incorrect");
                3: if ({ringer, motor} !== 2'b01) $fatal(1, "Vibrate mode incorrect");
            endcase
        end
        $display("PASS: all four input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Testbench timeout");
    end
endmodule
