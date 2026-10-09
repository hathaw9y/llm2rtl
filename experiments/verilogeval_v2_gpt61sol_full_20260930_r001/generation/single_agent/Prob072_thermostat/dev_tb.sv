`timescale 1ns/1ps
module dev_tb;
    logic mode, too_cold, too_hot, fan_on;
    wire heater, aircon, fan;
    logic expected_heater, expected_aircon, expected_fan;
    integer i;
    TopModule dut (.*);
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {mode, too_cold, too_hot, fan_on} = i[3:0];
            expected_heater = 1'b0;
            expected_aircon = 1'b0;
            if (mode) expected_heater = too_cold;
            else expected_aircon = too_hot;
            expected_fan = fan_on;
            if (expected_heater || expected_aircon) expected_fan = 1'b1;
            #1;
            if ({heater, aircon, fan} !== {expected_heater, expected_aircon, expected_fan})
                $fatal(1, "FAIL input=%b output=%b expected=%b", {mode, too_cold, too_hot, fan_on}, {heater, aircon, fan}, {expected_heater, expected_aircon, expected_fan});
        end
        $display("PASS: all 16 binary input combinations");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
