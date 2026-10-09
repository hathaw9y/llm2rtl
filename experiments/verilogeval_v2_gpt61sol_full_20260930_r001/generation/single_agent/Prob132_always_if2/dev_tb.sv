module dev_tb;
    reg cpu_overheated, arrived, gas_tank_empty;
    wire shut_off_computer, keep_driving;
    integer i, j;
    TopModule dut (.*);
    initial begin
        for (j = 0; j < 2; j = j + 1) begin
            for (i = 0; i < 8; i = i + 1) begin
                {cpu_overheated, arrived, gas_tank_empty} = j ? (7-i) : i;
                #1;
                if (shut_off_computer !== cpu_overheated ||
                    keep_driving !== (!arrived && !gas_tank_empty))
                    $fatal(1, "FAIL input=%b%b%b output=%b%b", cpu_overheated,
                           arrived, gas_tank_empty, shut_off_computer, keep_driving);
            end
        end
        $display("PASS: all binary inputs checked in forward and reverse order");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: timeout");
    end
endmodule
