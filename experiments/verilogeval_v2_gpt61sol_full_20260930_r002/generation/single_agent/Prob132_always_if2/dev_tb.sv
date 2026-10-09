`timescale 1ns/1ps
module dev_tb;
    reg cpu_overheated;
    reg arrived;
    reg gas_tank_empty;
    wire shut_off_computer;
    wire keep_driving;
    integer previous_vector;
    integer next_vector;
    integer checks = 0;

    TopModule dut (
        .cpu_overheated(cpu_overheated),
        .shut_off_computer(shut_off_computer),
        .arrived(arrived),
        .gas_tank_empty(gas_tank_empty),
        .keep_driving(keep_driving)
    );

    task automatic apply_and_check(input reg [2:0] stimulus);
        reg expected_shutdown;
        reg expected_driving;
        begin
            {cpu_overheated, arrived, gas_tank_empty} = stimulus;
            // Independent truth table: drive only before arrival with fuel.
            case (stimulus[1:0])
                2'b00: expected_driving = 1'b1;
                default: expected_driving = 1'b0;
            endcase
            case (stimulus[2])
                1'b0: expected_shutdown = 1'b0;
                1'b1: expected_shutdown = 1'b1;
            endcase
            #1;
            if (shut_off_computer !== expected_shutdown)
                $fatal(1, "shutdown mismatch inputs=%b expected=%b actual=%b", stimulus, expected_shutdown, shut_off_computer);
            if (keep_driving !== expected_driving)
                $fatal(1, "driving mismatch inputs=%b expected=%b actual=%b", stimulus, expected_driving, keep_driving);
            checks = checks + 1;
        end
    endtask

    initial begin
        // First sample has both outputs deasserted without any prior assertion.
        apply_and_check(3'b010);
        // Explicit transitions from asserted outputs to deasserted outputs.
        apply_and_check(3'b100);
        apply_and_check(3'b010);
        apply_and_check(3'b000);
        apply_and_check(3'b001);
        // Exhaust every binary input combination and every ordered transition.
        for (previous_vector = 0; previous_vector < 8; previous_vector = previous_vector + 1)
            for (next_vector = 0; next_vector < 8; next_vector = next_vector + 1) begin
                apply_and_check(previous_vector[2:0]);
                apply_and_check(next_vector[2:0]);
            end
        $display("PASS: %0d combinational truth-table and transition checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "development test timeout");
    end
endmodule
