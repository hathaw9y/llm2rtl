`timescale 1ns/1ps
module dev_tb;
    logic [7:0] in;
    wire [31:0] out;
    integer value;
    integer signed_value;
    logic [31:0] expected;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check_four_state(input logic [7:0] pattern);
        logic [31:0] reference_bits;
        integer bit_index;
        begin
            in = pattern;
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin
                if (bit_index < 8)
                    reference_bits[bit_index] = pattern[bit_index];
                else
                    reference_bits[bit_index] = pattern[7];
            end
            #1;
            if (out !== reference_bits)
                $fatal(1, "Four-state mismatch: in=%b out=%b expected=%b", in, out, reference_bits);
            checks = checks + 1;
        end
    endtask

    initial begin
        // An undriven logic input starts unknown; no DUT initialization is required.
        #1;
        if (out !== 32'hxxxxxxxx)
            $fatal(1, "Initial unknown input not propagated: out=%b", out);
        checks = checks + 1;
        // Signed arithmetic oracle differs from the DUT replication expression.
        for (value = 0; value < 256; value = value + 1) begin
            in = value[7:0];
            if (value < 128)
                signed_value = value;
            else
                signed_value = value - 256;
            expected = signed_value;
            #1;
            if (out !== expected)
                $fatal(1, "Mismatch: input=%h expected=%h actual=%h", in, expected, out);
            checks = checks + 1;
        end
        check_four_state(8'bx0101101);
        check_four_state(8'bz0101101);
        check_four_state(8'b0x01z101);
        check_four_state(8'b1z01x101);
        check_four_state(8'bzzzzzzzz);
        check_four_state(8'bxxxxxxxx);
        check_four_state(8'h00);
        check_four_state(8'h80);
        $display("PASS: sign extension checked in %0d cases", checks);
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
