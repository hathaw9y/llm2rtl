`timescale 1ns/1ps
module dev_tb;
    reg c, d;
    wire [3:0] mux_in;
    reg [3:0] expected;
    integer cd, ab;
    reg selected;
    TopModule dut (.c(c), .d(d), .mux_in(mux_in));

    initial begin
        for (cd = 0; cd < 4; cd = cd + 1) begin
            {c, d} = cd[1:0];
            #1;
            // Literal K-map rows, ordered by binary ab = 00,01,10,11.
            case (cd)
                0: expected = 4'b0100;
                1: expected = 4'b0001;
                2: expected = 4'b0101;
                3: expected = 4'b1101;
            endcase
            if (mux_in !== expected)
                $fatal(1, "cd=%b: got %b expected %b", {c,d}, mux_in, expected);
            for (ab = 0; ab < 4; ab = ab + 1) begin
                selected = mux_in[ab];
                if (selected !== expected[ab])
                    $fatal(1, "K-map mismatch cd=%b ab=%b", {c,d}, ab[1:0]);
            end
        end
        $display("PASS exhaustive K-map checks");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Timeout");
    end
endmodule
