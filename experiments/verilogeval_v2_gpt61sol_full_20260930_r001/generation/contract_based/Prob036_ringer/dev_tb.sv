`timescale 1ns/1ps
module dev_tb;
    logic ring, vibrate_mode;
    wire ringer, motor;
    integer source, destination;
    integer checks = 0;
    logic [1:0] expected;
    TopModule dut (.ring(ring), .vibrate_mode(vibrate_mode),
                   .ringer(ringer), .motor(motor));

    task automatic check_pair(input integer pair);
        begin
            {ring, vibrate_mode} = pair[1:0];
            case (pair)
                0: expected = 2'b00;
                1: expected = 2'b00;
                2: expected = 2'b10;
                3: expected = 2'b01;
                default: $fatal(1, "Invalid test input");
            endcase
            #1;
            if ({ringer, motor} !== expected)
                $fatal(1, "pair=%0d expected=%b actual=%b", pair, expected, {ringer,motor});
            if ((ringer & motor) !== 1'b0)
                $fatal(1, "Outputs are simultaneously asserted");
            if ((ringer | motor) !== ring)
                $fatal(1, "Ring activity mismatch");
            checks = checks + 1;
        end
    endtask

    initial begin
        for (source = 0; source < 4; source = source + 1)
            check_pair(source);
        for (source = 0; source < 4; source = source + 1)
            for (destination = 0; destination < 4; destination = destination + 1) begin
                check_pair(source);
                check_pair(destination);
            end
        $display("PASS: %0d checks, all four input pairs and all sixteen transitions", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
