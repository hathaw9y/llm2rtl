module dev_tb;
    logic mode, too_cold, too_hot, fan_on;
    wire heater, aircon, fan;
    logic expected_heater, expected_aircon, expected_fan;
    integer vector_index;
    TopModule dut (.mode(mode), .too_cold(too_cold), .too_hot(too_hot),
                   .fan_on(fan_on), .heater(heater), .aircon(aircon), .fan(fan));
    initial begin
        for (vector_index = 0; vector_index < 16; vector_index = vector_index + 1) begin
            {mode, too_cold, too_hot, fan_on} = vector_index[3:0];
            expected_heater = 1'b0;
            expected_aircon = 1'b0;
            if (mode == 1'b1) begin
                if (too_cold == 1'b1) expected_heater = 1'b1;
            end else begin
                if (too_hot == 1'b1) expected_aircon = 1'b1;
            end
            expected_fan = 1'b0;
            if (fan_on || expected_heater || expected_aircon) expected_fan = 1'b1;
            #1;
            if ({heater, aircon, fan} !== {expected_heater, expected_aircon, expected_fan})
                $fatal(1, "FAIL vector %0d: got %b expected %b", vector_index,
                       {heater, aircon, fan}, {expected_heater, expected_aircon, expected_fan});
        end
        $display("PASS: all 16 binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: simulation timeout");
    end
endmodule
