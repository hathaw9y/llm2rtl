`timescale 1ns/1ps
module dev_tb;
    logic [255:0] in;
    logic [7:0] sel;
    wire out;
    integer position;
    integer selection;
    integer checks = 0;

    TopModule dut (.in(in), .sel(sel), .out(out));

    task automatic check_output(input logic expected);
        #1;
        if (out !== expected)
            $fatal(1, "Mismatch: sel=%0d expected=%b actual=%b in=%h", sel, expected, out, in);
        checks = checks + 1;
    endtask

    initial begin
        in = '0;
        sel = 8'd0;
        for (selection = 0; selection < 256; selection = selection + 1) begin
            sel = selection[7:0];
            check_output(1'b0);
        end
        in = '1;
        for (selection = 0; selection < 256; selection = selection + 1) begin
            sel = selection[7:0];
            check_output(1'b1);
        end
        // Expected values derive from the location of the sole differing bit,
        // independently of the DUT's variable-index selection expression.
        for (position = 0; position < 256; position = position + 1) begin
            in = '0;
            in[position] = 1'b1;
            for (selection = 0; selection < 256; selection = selection + 1) begin
                sel = selection[7:0];
                check_output(selection == position);
            end
            in = '1;
            in[position] = 1'b0;
            for (selection = 0; selection < 256; selection = selection + 1) begin
                sel = selection[7:0];
                check_output(selection != position);
            end
        end
        $display("PASS: %0d combinational multiplexer checks", checks);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Timeout");
    end
endmodule
