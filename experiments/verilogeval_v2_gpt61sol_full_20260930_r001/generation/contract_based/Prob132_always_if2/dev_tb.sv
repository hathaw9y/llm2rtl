`timescale 1ns/1ps
module dev_tb;
    reg cpu_overheated, arrived, gas_tank_empty;
    wire shut_off_computer, keep_driving;
    integer source, destination, checks;
    TopModule dut (
        .cpu_overheated(cpu_overheated),
        .shut_off_computer(shut_off_computer),
        .arrived(arrived),
        .gas_tank_empty(gas_tank_empty),
        .keep_driving(keep_driving)
    );
    task automatic apply_and_check(input integer vector);
        reg expected_shutdown, expected_driving;
        begin
            {cpu_overheated, arrived, gas_tank_empty} = vector[2:0];
            case (vector)
                0: begin expected_shutdown = 0; expected_driving = 1; end
                1, 2, 3: begin expected_shutdown = 0; expected_driving = 0; end
                4: begin expected_shutdown = 1; expected_driving = 1; end
                5, 6, 7: begin expected_shutdown = 1; expected_driving = 0; end
                default: $fatal(1, "Invalid test vector");
            endcase
            #1;
            if (shut_off_computer !== expected_shutdown ||
                keep_driving !== expected_driving)
                $fatal(1, "vector=%0d shutdown=%b driving=%b expected=%b/%b",
                       vector, shut_off_computer, keep_driving,
                       expected_shutdown, expected_driving);
            checks = checks + 1;
        end
    endtask
    initial begin
        checks = 0;
        for (source = 0; source < 8; source = source + 1)
            for (destination = 0; destination < 8; destination = destination + 1) begin
                apply_and_check(source);
                apply_and_check(destination);
            end
        $display("PASS: all 8 binary combinations, all 64 ordered transitions, %0d checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end
endmodule
