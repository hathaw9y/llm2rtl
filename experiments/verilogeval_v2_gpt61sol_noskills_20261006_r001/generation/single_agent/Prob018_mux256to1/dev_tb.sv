`timescale 1ns/1ps
module dev_tb;
    reg [255:0] in;
    reg [7:0] sel;
    wire out;
    integer selected, hot, trial, bit_number;
    reg expected;
    integer checks = 0;
    TopModule dut(.in(in), .sel(sel), .out(out));

    task check_value(input reg value);
        begin
            #1;
            if (out !== value)
                $fatal(1, "sel=%0d expected=%b actual=%b", sel, value, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        // Every input must route to every selection correctly, with both polarities.
        for (hot = 0; hot < 256; hot = hot + 1) begin
            in = 256'b0;
            in[hot] = 1'b1;
            for (selected = 0; selected < 256; selected = selected + 1) begin
                sel = selected;
                check_value(selected == hot);
            end
            in = {256{1'b1}};
            in[hot] = 1'b0;
            for (selected = 0; selected < 256; selected = selected + 1) begin
                sel = selected;
                check_value(selected != hot);
            end
        end
        // Random data: form the oracle by scanning numbered inputs.
        for (trial = 0; trial < 16; trial = trial + 1) begin
            for (bit_number = 0; bit_number < 256; bit_number = bit_number + 1)
                in[bit_number] = $random;
            for (selected = 0; selected < 256; selected = selected + 1) begin
                sel = selected;
                expected = 1'bx;
                for (bit_number = 0; bit_number < 256; bit_number = bit_number + 1)
                    if (bit_number == selected) expected = in[bit_number];
                check_value(expected);
            end
        end
        // Data changes with selection held fixed, including four-state data.
        for (selected = 0; selected < 256; selected = selected + 1) begin
            sel = selected;
            in = 256'b0;
            check_value(1'b0);
            in[selected] = 1'b1;
            check_value(1'b1);
            in[selected] = 1'bx;
            check_value(1'bx);
            in[selected] = 1'bz;
            check_value(1'bz);
        end
        $display("PASS: %0d multiplexer checks", checks);
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
