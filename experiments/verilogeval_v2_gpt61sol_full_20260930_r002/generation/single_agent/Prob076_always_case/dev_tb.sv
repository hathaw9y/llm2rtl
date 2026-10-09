`timescale 1ns/1ps
module dev_tb;
    logic [2:0] sel;
    logic [3:0] inputs_data [0:5];
    wire [3:0] out;
    integer checks = 0;
    integer s, lane, value, k, trial;
    logic [3:0] expected;

    TopModule dut (.sel(sel), .data0(inputs_data[0]),
        .data1(inputs_data[1]), .data2(inputs_data[2]),
        .data3(inputs_data[3]), .data4(inputs_data[4]),
        .data5(inputs_data[5]), .out(out));

    task automatic check_output;
        begin
            // Allow combinational propagation; there is no clock or reset.
            #1;
            expected = 4'd0;
            if (sel < 6) expected = inputs_data[sel];
            if (out !== expected)
                $fatal(1, "selector=%0d expected=%h actual=%h", sel, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Sweep each input over its full range with distinct backgrounds.
        // This also checks that changes on unselected inputs do not leak out.
        for (s = 0; s < 8; s = s + 1) begin
            sel = s;
            for (lane = 0; lane < 6; lane = lane + 1) begin
                for (value = 0; value < 16; value = value + 1) begin
                    for (k = 0; k < 6; k = k + 1)
                        inputs_data[k] = (k * 3 + s) % 16;
                    inputs_data[lane] = value;
                    check_output();
                end
            end
        end
        // Select changes with fixed distinct inputs, including illegal 6/7.
        for (k = 0; k < 6; k = k + 1) inputs_data[k] = k + 1;
        for (s = 7; s >= 0; s = s - 1) begin
            sel = s;
            check_output();
        end
        for (trial = 0; trial < 4096; trial = trial + 1) begin
            sel = trial % 8;
            for (k = 0; k < 6; k = k + 1)
                inputs_data[k] = $urandom_range(15, 0);
            check_output();
        end
        $display("PASS: %0d mux checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
