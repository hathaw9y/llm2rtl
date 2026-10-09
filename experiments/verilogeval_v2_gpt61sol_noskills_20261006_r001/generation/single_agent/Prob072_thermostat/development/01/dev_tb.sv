`timescale 1ns/1ps
module dev_tb;
    reg mode, too_cold, too_hot, fan_on;
    wire heater, aircon, fan;
    reg expected_heater, expected_aircon, expected_fan;
    integer i;

    TopModule dut (
        .mode(mode), .too_cold(too_cold), .too_hot(too_hot),
        .fan_on(fan_on), .heater(heater), .aircon(aircon), .fan(fan)
    );

    task check_outputs;
        begin
            expected_heater = 0;
            expected_aircon = 0;
            if (mode == 1) begin
                if (too_cold == 1) expected_heater = 1;
            end else begin
                if (too_hot == 1) expected_aircon = 1;
            end
            expected_fan = 0;
            if (fan_on == 1 || expected_heater == 1 || expected_aircon == 1)
                expected_fan = 1;
            if ({heater, aircon, fan} !==
                {expected_heater, expected_aircon, expected_fan})
                $fatal(1, "Mismatch inputs=%b%b%b%b actual=%b%b%b expected=%b%b%b",
                    mode, too_cold, too_hot, fan_on, heater, aircon, fan,
                    expected_heater, expected_aircon, expected_fan);
        end
    endtask

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {mode, too_cold, too_hot, fan_on} = i[3:0];
            #1;
            check_outputs;
        end
        // Reverse traversal checks removal of every request as well as assertion.
        for (i = 15; i >= 0; i = i - 1) begin
            {mode, too_cold, too_hot, fan_on} = i[3:0];
            #1;
            check_outputs;
        end
        $display("PASS all thermostat input combinations in both directions");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
