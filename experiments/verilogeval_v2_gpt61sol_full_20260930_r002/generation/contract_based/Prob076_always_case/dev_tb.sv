`timescale 1ns/1ps
module dev_tb;
    logic [2:0] sel;
    logic [3:0] data [0:5];
    wire [3:0] out;
    integer s, lane, value, pattern;
    integer checks = 0;
    TopModule dut (.sel(sel), .data0(data[0]), .data1(data[1]),
                   .data2(data[2]), .data3(data[3]), .data4(data[4]),
                   .data5(data[5]), .out(out));

    task automatic check_output;
        logic [3:0] expected;
        begin
            #1;
            // Original specification: choose corresponding input for 0..5,
            // otherwise zero. This oracle uses indexing, not the DUT case.
            expected = 4'd0;
            if (sel < 3'd6) expected = data[sel];
            if (out !== expected)
                $fatal(1, "Mismatch sel=%0d out=%b expected=%b", sel, out, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Sweep each lane through all bit patterns with each selector held.
        // Other lanes carry distinct values, exposing swapped input mappings.
        for (s = 0; s < 8; s = s + 1) begin
            sel = s;
            for (lane = 0; lane < 6; lane = lane + 1) begin
                for (pattern = 0; pattern < 6; pattern = pattern + 1)
                    data[pattern] = (pattern * 3 + s) & 15;
                for (value = 0; value < 16; value = value + 1) begin
                    data[lane] = value;
                    check_output();
                end
            end
        end
        // Selector transitions across both valid and invalid boundaries.
        for (value = 0; value < 16; value = value + 1) begin
            for (lane = 0; lane < 6; lane = lane + 1)
                data[lane] = (value + lane) & 15;
            for (s = 7; s >= 0; s = s - 1) begin
                sel = s;
                check_output();
            end
        end
        // A mux copies the selected four-state payload as well.
        for (s = 0; s < 6; s = s + 1) begin
            sel = s;
            data[s] = 4'bx01z;
            check_output();
            data[s] = 4'bz10x;
            check_output();
        end
        sel = 3'd6;
        check_output();
        sel = 3'd7;
        check_output();
        $display("PASS: %0d combinational mux checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
