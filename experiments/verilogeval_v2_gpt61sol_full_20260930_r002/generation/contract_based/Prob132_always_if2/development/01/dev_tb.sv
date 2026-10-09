`timescale 1ns/1ps
module dev_tb;
    reg cpu_overheated;
    reg arrived;
    reg gas_tank_empty;
    wire shut_off_computer;
    wire keep_driving;
    integer previous_inputs;
    integer current_inputs;
    integer checks = 0;

    TopModule dut (
        .cpu_overheated(cpu_overheated),
        .shut_off_computer(shut_off_computer),
        .arrived(arrived),
        .gas_tank_empty(gas_tank_empty),
        .keep_driving(keep_driving)
    );

    task apply_and_check(input reg [2:0] values);
        reg [1:0] expected;
        begin
            // Independent table: {overheated, arrived, empty} -> {off, drive}.
            case (values)
                3'b000: expected = 2'b01;
                3'b001: expected = 2'b00;
                3'b010: expected = 2'b00;
                3'b011: expected = 2'b00;
                3'b100: expected = 2'b11;
                3'b101: expected = 2'b10;
                3'b110: expected = 2'b10;
                3'b111: expected = 2'b10;
                default: $fatal(1, "Invalid test input");
            endcase
            {cpu_overheated, arrived, gas_tank_empty} = values;
            #1;
            if ({shut_off_computer, keep_driving} !== expected)
                $fatal(1, "inputs=%b expected=%b observed=%b", values,
                       expected, {shut_off_computer, keep_driving});
            checks = checks + 1;
        end
    endtask

    initial begin
        // Cover every transition, detecting history-dependent latch behavior.
        for (previous_inputs = 0; previous_inputs < 8; previous_inputs = previous_inputs + 1)
            for (current_inputs = 0; current_inputs < 8; current_inputs = current_inputs + 1) begin
                apply_and_check(previous_inputs[2:0]);
                apply_and_check(current_inputs[2:0]);
            end
        $display("PASS: %0d truth-table and transition checks", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Test timeout");
    end
endmodule
