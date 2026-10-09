`timescale 1ns/1ps
module dev_tb;
    reg cpu_overheated;
    reg arrived;
    reg gas_tank_empty;
    wire shut_off_computer;
    wire keep_driving;
    integer source_pattern, destination_pattern;
    integer checks = 0;

    TopModule dut (
        .cpu_overheated(cpu_overheated),
        .shut_off_computer(shut_off_computer),
        .arrived(arrived),
        .gas_tank_empty(gas_tank_empty),
        .keep_driving(keep_driving)
    );

    task apply_and_check(input [2:0] pattern);
        reg expected_shutdown;
        reg expected_driving;
        begin
            {cpu_overheated, arrived, gas_tank_empty} = pattern;
            // Truth table from the original conditions: stop on arrival
            // or an empty tank; shut down exactly when overheated.
            case (pattern)
                3'b000: begin expected_shutdown = 0; expected_driving = 1; end
                3'b001: begin expected_shutdown = 0; expected_driving = 0; end
                3'b010: begin expected_shutdown = 0; expected_driving = 0; end
                3'b011: begin expected_shutdown = 0; expected_driving = 0; end
                3'b100: begin expected_shutdown = 1; expected_driving = 1; end
                3'b101: begin expected_shutdown = 1; expected_driving = 0; end
                3'b110: begin expected_shutdown = 1; expected_driving = 0; end
                3'b111: begin expected_shutdown = 1; expected_driving = 0; end
                default: $fatal(1, "Invalid test pattern");
            endcase
            #1;
            if (shut_off_computer !== expected_shutdown ||
                keep_driving !== expected_driving)
                $fatal(1, "pattern=%b shutdown=%b expected=%b driving=%b expected=%b",
                       pattern, shut_off_computer, expected_shutdown,
                       keep_driving, expected_driving);
            checks = checks + 1;
        end
    endtask

    initial begin
        // First defined inputs must produce outputs without a reset or clock.
        apply_and_check(3'b010);
        // Exercise every ordered pair, including unchanged inputs and the
        // deassertions that exposed the original unintended storage.
        for (source_pattern = 0; source_pattern < 8; source_pattern = source_pattern + 1)
            for (destination_pattern = 0; destination_pattern < 8; destination_pattern = destination_pattern + 1) begin
                apply_and_check(source_pattern);
                apply_and_check(destination_pattern);
            end
        $display("PASS: %0d combinational truth-table and transition checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
