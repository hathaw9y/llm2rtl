`timescale 1ns/1ps
module dev_tb;
    reg cpu_overheated, arrived, gas_tank_empty;
    wire shut_off_computer, keep_driving;
    integer i, j, checks;
    TopModule dut (
        .cpu_overheated(cpu_overheated),
        .shut_off_computer(shut_off_computer),
        .arrived(arrived),
        .gas_tank_empty(gas_tank_empty),
        .keep_driving(keep_driving)
    );

    // Enumerated expected outputs from the original conditions and
    // zero-valued missing branches; independent of the DUT statements.
    task check_binary(input [2:0] stimulus);
        reg [1:0] expected;
        begin
            case (stimulus)
                3'b000: expected = 2'b01;
                3'b001: expected = 2'b00;
                3'b010: expected = 2'b00;
                3'b011: expected = 2'b00;
                3'b100: expected = 2'b11;
                3'b101: expected = 2'b10;
                3'b110: expected = 2'b10;
                3'b111: expected = 2'b10;
            endcase
            {cpu_overheated, arrived, gas_tank_empty} = stimulus;
            #1;
            if ({shut_off_computer, keep_driving} !== expected)
                $fatal(1, "Input %b: expected %b, observed %b", stimulus,
                       expected, {shut_off_computer, keep_driving});
            checks = checks + 1;
        end
    endtask

    task check_four_state(input c, input a, input g,
                          input expected_shut, input expected_drive);
        begin
            cpu_overheated = c; arrived = a; gas_tank_empty = g;
            #1;
            if (shut_off_computer !== expected_shut ||
                keep_driving !== expected_drive)
                $fatal(1, "Four-state input %b%b%b mismatch", c, a, g);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        // Establish known stimulus before sampling: no initial output
        // value or reset is specified by the original problem.
        for (i = 0; i < 8; i = i + 1)
            check_binary(i[2:0]);
        for (i = 0; i < 8; i = i + 1)
            for (j = 0; j < 8; j = j + 1) begin
                check_binary(i[2:0]);
                check_binary(j[2:0]);
            end
        check_four_state(1'bx, 1'b0, 1'b0, 1'b0, 1'b1);
        check_four_state(1'bz, 1'b0, 1'b1, 1'b0, 1'b0);
        check_four_state(1'b1, 1'bx, 1'b0, 1'b1, 1'b0);
        check_four_state(1'b0, 1'bz, 1'b0, 1'b0, 1'b0);
        check_four_state(1'b0, 1'b0, 1'bx, 1'b0, 1'bx);
        check_four_state(1'b1, 1'b0, 1'bz, 1'b1, 1'bx);
        check_four_state(1'b0, 1'b1, 1'bx, 1'b0, 1'b0);
        check_four_state(1'b1, 1'b1, 1'bz, 1'b1, 1'b0);
        $display("PASS: %0d combinational checks", checks);
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
