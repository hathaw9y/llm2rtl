`timescale 1ns/1ps
module dev_tb;
    logic mode, too_cold, too_hot, fan_on;
    wire heater, aircon, fan;
    integer source_case, target_case;
    integer checks = 0;
    TopModule dut (.mode(mode), .too_cold(too_cold),
        .too_hot(too_hot), .fan_on(fan_on),
        .heater(heater), .aircon(aircon), .fan(fan));

    task automatic check_case(input logic [3:0] inputs);
        logic expected_heater, expected_aircon, expected_fan;
        begin
            {mode, too_cold, too_hot, fan_on} = inputs;
            expected_heater = 1'b0;
            expected_aircon = 1'b0;
            if (inputs[3]) begin
                if (inputs[2]) expected_heater = 1'b1;
            end else begin
                if (inputs[1]) expected_aircon = 1'b1;
            end
            expected_fan = inputs[0];
            if (expected_heater || expected_aircon) expected_fan = 1'b1;
            #1;
            if ({heater, aircon, fan} !==
                {expected_heater, expected_aircon, expected_fan})
                $fatal(1, "inputs=%b actual=%b expected=%b", inputs,
                    {heater, aircon, fan},
                    {expected_heater, expected_aircon, expected_fan});
            checks = checks + 1;
        end
    endtask

    initial begin
        for (source_case = 0; source_case < 16; source_case = source_case + 1)
            for (target_case = 0; target_case < 16; target_case = target_case + 1) begin
                check_case(source_case[3:0]);
                check_case(target_case[3:0]);
            end
        $display("PASS: %0d thermostat checks, all input combinations and transitions", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
