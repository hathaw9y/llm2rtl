`timescale 1ns/1ps
module dev_tb;
    logic x, y;
    wire z;
    integer checks = 0;
    integer previous_pair, next_pair;
    TopModule dut (.x(x), .y(y), .z(z));

    // Independent table from the original waveform and gate wiring.
    task automatic check_output;
        logic expected;
        begin
            case ({x,y})
                2'b00: expected = 1'b1;
                2'b01: expected = 1'b0;
                2'b10: expected = 1'b1;
                2'b11: expected = 1'b1;
                default: $fatal(1, "Unexpected nonbinary stimulus");
            endcase
            if (z !== expected)
                $fatal(1, "At %0t x=%b y=%b expected=%b actual=%b", $time, x, y, expected, z);
            checks = checks + 1;
        end
    endtask

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
        // Original timestamp spacing: each row begins exactly 5 ns apart.
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
        // Exhaust every ordered binary transition, including holds.
        for (previous_pair = 0; previous_pair < 4; previous_pair = previous_pair + 1)
            for (next_pair = 0; next_pair < 4; next_pair = next_pair + 1) begin
                {x,y} = previous_pair[1:0];
                #1;
                check_output();
                {x,y} = next_pair[1:0];
                #1;
                check_output();
            end
        $display("PASS: %0d original waveform and exhaustive transition checks", checks);
        $finish;
    end

    initial begin
        #200;
        $fatal(1, "Development timeout");
    end
endmodule
