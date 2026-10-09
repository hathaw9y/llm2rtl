`timescale 1ns/1ps
module dev_tb;
    reg mode, too_cold, too_hot, fan_on;
    wire heater, aircon, fan;
    reg expected_heater, expected_aircon, expected_fan;
    integer i;
    integer checks = 0;

    TopModule dut (
        .mode(mode), .too_cold(too_cold), .too_hot(too_hot),
        .fan_on(fan_on), .heater(heater), .aircon(aircon), .fan(fan)
    );

    task check_combination(input reg [3:0] stimulus);
        begin
            {mode, too_cold, too_hot, fan_on} = stimulus;
            expected_heater = 0;
            expected_aircon = 0;
            if (mode == 1) begin
                if (too_cold == 1) expected_heater = 1;
            end else begin
                if (too_hot == 1) expected_aircon = 1;
            end
            expected_fan = 0;
            if (fan_on == 1) expected_fan = 1;
            if (expected_heater == 1) expected_fan = 1;
            if (expected_aircon == 1) expected_fan = 1;
            #1;
            if ({heater, aircon, fan} !==
                {expected_heater, expected_aircon, expected_fan})
                $fatal(1, "inputs=%b expected=%b observed=%b", stimulus,
                       {expected_heater, expected_aircon, expected_fan},
                       {heater, aircon, fan});
            checks = checks + 1;
        end
    endtask

    initial begin
        for (i = 0; i < 16; i = i + 1) check_combination(i[3:0]);
        for (i = 15; i >= 0; i = i - 1) check_combination(i[3:0]);
        $display("PASS: %0d thermostat checks", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
