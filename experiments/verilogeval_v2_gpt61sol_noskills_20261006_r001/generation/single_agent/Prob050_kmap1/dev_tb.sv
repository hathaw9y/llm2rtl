`timescale 1ns/1ps
module dev_tb;
    reg a, b, c;
    wire out;
    reg expected;
    integer i;
    TopModule dut (.a(a), .b(b), .c(c), .out(out));

    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, c} = i[2:0];
            // Literal entries from the supplied Karnaugh map.
            case ({a, b, c})
                3'b000: expected = 1'b0;
                3'b001: expected = 1'b1;
                3'b010: expected = 1'b1;
                3'b011: expected = 1'b1;
                3'b100: expected = 1'b1;
                3'b101: expected = 1'b1;
                3'b110: expected = 1'b1;
                3'b111: expected = 1'b1;
            endcase
            #1;
            if (out !== expected)
                $fatal(1, "abc=%b expected=%b observed=%b", {a,b,c}, expected, out);
        end
        // Return to the sole zero entry after the all-one input.
        {a, b, c} = 3'b000;
        #1;
        if (out !== 1'b0) $fatal(1, "Return to zero failed");
        $display("PASS all eight Karnaugh map entries and return to zero");
        $finish;
    end

    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
