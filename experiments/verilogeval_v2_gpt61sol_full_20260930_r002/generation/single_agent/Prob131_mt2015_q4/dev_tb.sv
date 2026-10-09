`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    integer checks = 0;
    TopModule dut (.x(x), .y(y), .z(z));

    // Independent truth table derived from A and the observed B table:
    // xy  A B  OR AND  z
    // 00  0 1   1  0   1
    // 01  0 0   0  0   0
    // 10  1 0   1  0   1
    // 11  0 1   1  0   1
    task automatic check_output;
        logic expected;
        begin
            case ({x,y})
                2'b00: expected = 1'b1;
                2'b01: expected = 1'b0;
                2'b10: expected = 1'b1;
                2'b11: expected = 1'b1;
                default: $fatal(1, "Invalid test stimulus");
            endcase
            if (z !== expected)
                $fatal(1, "Mismatch at %0t x=%b y=%b expected=%b got=%b", $time, x, y, expected, z);
            checks = checks + 1;
        end
    endtask

    // Apply each listed waveform row exactly at its original timestamp.
    // Sample one picosecond later to allow combinational delta settling.
    task automatic waveform_row(input logic row_x, input logic row_y);
        begin
            x = row_x;
            y = row_y;
            #0.001;
            check_output();
            #4.999;
        end
    endtask

    initial begin
        waveform_row(0,0); // 0 ns
        waveform_row(0,0); // 5 ns
        waveform_row(0,0); // 10 ns
        waveform_row(0,0); // 15 ns
        waveform_row(0,0); // 20 ns
        waveform_row(1,0); // 25 ns
        waveform_row(1,0); // 30 ns
        waveform_row(0,1); // 35 ns
        waveform_row(0,1); // 40 ns
        waveform_row(1,1); // 45 ns
        waveform_row(1,1); // 50 ns
        waveform_row(0,0); // 55 ns
        waveform_row(0,1); // 60 ns
        waveform_row(0,1); // 65 ns
        waveform_row(1,1); // 70 ns
        waveform_row(0,1); // 75 ns
        waveform_row(0,1); // 80 ns
        waveform_row(0,1); // 85 ns
        waveform_row(1,0); // 90 ns

        // Exhaust all binary input transitions, including held inputs.
        for (integer from_value = 0; from_value < 4; from_value++) begin
            for (integer to_value = 0; to_value < 4; to_value++) begin
                {x,y} = from_value[1:0];
                #1;
                check_output();
                {x,y} = to_value[1:0];
                #1;
                check_output();
            end
        end
        $display("PASS %0d combinational checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Timeout");
    end
endmodule
