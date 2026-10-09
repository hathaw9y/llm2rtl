`timescale 1ns/1ps
module dev_tb;
    reg [31:0] in;
    wire [31:0] out;
    reg [31:0] sequence_value;
    integer i;
    integer checks = 0;
    TopModule dut (.in(in), .out(out));

    task automatic check_vector(input reg [31:0] value);
        reg [31:0] expected;
        integer bit_index;
        begin
            // Independent oracle: move each bit to the opposite byte position.
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1)
                expected[(3 - bit_index / 8) * 8 + bit_index % 8] = value[bit_index];
            in = value;
            #1;
            if (out !== expected)
                $fatal(1, "Byte reversal mismatch: input=%h expected=%h actual=%h", value, expected, out);
            checks = checks + 1;
        end
    endtask

    initial begin
        check_vector(32'h00000000);
        check_vector(32'hffffffff);
        check_vector(32'h01234567);
        check_vector(32'h89abcdef);
        check_vector(32'hff00807f);
        check_vector(32'haaaaaaaa);
        check_vector(32'h55555555);
        for (i = 0; i < 32; i = i + 1) begin
            check_vector(32'h00000001 << i);
            check_vector(~(32'h00000001 << i));
        end
        sequence_value = 32'h12345678;
        for (i = 0; i < 1000; i = i + 1) begin
            sequence_value = {sequence_value[30:0], sequence_value[31] ^ sequence_value[21] ^ sequence_value[1] ^ sequence_value[0]};
            check_vector(sequence_value);
        end
        check_vector(32'hxxxxxxxx);
        check_vector(32'hzzzzzzzz);
        check_vector(32'h12xxzz34);
        for (i = 0; i < 32; i = i + 1) begin
            sequence_value = 32'h01234567;
            sequence_value[i] = 1'bx;
            check_vector(sequence_value);
            sequence_value[i] = 1'bz;
            check_vector(sequence_value);
        end
        $display("PASS: byte reversal verified for %0d vectors", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
