`timescale 1ns/1ps
module dev_tb;
    logic mode, too_cold, too_hot, fan_on;
    wire heater, aircon, fan;
    integer checks = 0;
    integer vector_index;

    TopModule dut (
        .mode(mode), .too_cold(too_cold), .too_hot(too_hot),
        .fan_on(fan_on), .heater(heater), .aircon(aircon), .fan(fan)
    );

    task automatic check_vector(input logic [3:0] stimulus);
        logic expected_heater, expected_aircon, expected_fan;
        begin
            {mode, too_cold, too_hot, fan_on} = stimulus;
            // Oracle follows the original mode-specific prose.
            expected_heater = 1'b0;
            expected_aircon = 1'b0;
            if (stimulus[3] == 1'b1) begin
                if (stimulus[2] == 1'b1)
                    expected_heater = 1'b1;
            end else begin
                if (stimulus[1] == 1'b1)
                    expected_aircon = 1'b1;
            end
            expected_fan = 1'b0;
            if (expected_heater == 1'b1)
                expected_fan = 1'b1;
            if (expected_aircon == 1'b1)
                expected_fan = 1'b1;
            if (stimulus[0] == 1'b1)
                expected_fan = 1'b1;
            #1;
            if ({heater, aircon, fan} !==
                {expected_heater, expected_aircon, expected_fan})
                $fatal(1, "stimulus=%b actual=%b expected=%b", stimulus,
                       {heater, aircon, fan},
                       {expected_heater, expected_aircon, expected_fan});
            checks = checks + 1;
        end
    endtask

    initial begin
        for (vector_index = 0; vector_index < 16; vector_index = vector_index + 1)
            check_vector(vector_index[3:0]);
        for (vector_index = 15; vector_index >= 0; vector_index = vector_index - 1)
            check_vector(vector_index[3:0]);
        $display("PASS thermostat: %0d checks, all 16 binary combinations", checks);
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
