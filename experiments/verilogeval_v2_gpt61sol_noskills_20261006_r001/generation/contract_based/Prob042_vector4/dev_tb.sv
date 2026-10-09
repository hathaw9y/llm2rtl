`timescale 1ns/1ps
module dev_tb;
    reg [7:0] in;
    wire [31:0] out;
    integer i;
    integer signed_value;
    reg [31:0] expected;
    TopModule dut (.in(in), .out(out));

    task check_binary(input integer value);
        begin
            in = value;
            if (value >= 128)
                signed_value = value - 256;
            else
                signed_value = value;
            expected = signed_value;
            #1;
            if (out !== expected)
                $fatal(1, "input=%h expected=%h actual=%h", in, expected, out);
        end
    endtask

    initial begin
        check_binary(0);
        check_binary(127);
        check_binary(128);
        check_binary(255);
        for (i = 0; i < 256; i = i + 1)
            check_binary(i);
        // Literal expectations separately exercise four-state bit propagation.
        in = 8'bx0101010;
        #1;
        if (out !== 32'bxxxxxxxxxxxxxxxxxxxxxxxxx0101010)
            $fatal(1, "Unknown sign bit propagation mismatch");
        in = 8'bz1010101;
        #1;
        if (out !== 32'bzzzzzzzzzzzzzzzzzzzzzzzzz1010101)
            $fatal(1, "High-impedance sign bit propagation mismatch");
        in = 8'b0xz10101;
        #1;
        if (out !== 32'b0000000000000000000000000xz10101)
            $fatal(1, "Low-bit preservation mismatch");
        $display("PASS all 256 inputs, boundary transitions, and four-state propagation");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
