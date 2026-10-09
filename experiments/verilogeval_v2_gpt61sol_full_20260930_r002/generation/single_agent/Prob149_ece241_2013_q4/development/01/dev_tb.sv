`timescale 1ns/1ps
module dev_tb;
    reg clk = 0;
    reg reset = 0;
    reg [2:0] s = 0;
    wire fr2, fr1, fr0, dfr;
    TopModule dut (.clk(clk), .reset(reset), .s(s),
                   .fr2(fr2), .fr1(fr1), .fr0(fr0), .dfr(dfr));
    always #5 clk = ~clk;

    integer previous_level = 0;
    reg expected_supplement = 1;
    reg [3:0] expected_outputs;
    integer checks = 0;
    integer a, b, c, k;

    function automatic [2:0] sensors(input integer level);
        case (level)
            0: sensors = 3'b000;
            1: sensors = 3'b001;
            2: sensors = 3'b011;
            3: sensors = 3'b111;
        endcase
    endfunction

    task automatic compare(input [3:0] expected);
        begin
            if ({fr2,fr1,fr0,dfr} !== expected)
                $fatal(1, "time=%0t sensors=%b expected=%b actual=%b", $time, s,
                       expected, {fr2,fr1,fr0,dfr});
            checks = checks + 1;
        end
    endtask

    task automatic step(input integer level, input reg resetting);
        begin
            @(negedge clk);
            s = sensors(level);
            reset = resetting;
            #1;
            compare(expected_outputs); // Inputs and reset must not act asynchronously.
            @(posedge clk);
            if (resetting) begin
                previous_level = 0;
                expected_supplement = 1;
                expected_outputs = 4'b1111;
            end else begin
                if (level == 0) expected_supplement = 1;
                else if (level == 3) expected_supplement = 0;
                else if (level > previous_level) expected_supplement = 1;
                else if (level < previous_level) expected_supplement = 0;
                case (level)
                    0: expected_outputs = {3'b111, expected_supplement};
                    1: expected_outputs = {3'b011, expected_supplement};
                    2: expected_outputs = {3'b001, expected_supplement};
                    3: expected_outputs = {3'b000, expected_supplement};
                endcase
                previous_level = level;
            end
            #1;
            compare(expected_outputs);
        end
    endtask

    initial begin
        // Establish the specified initial state only through a synchronous reset.
        reset = 1;
        s = 3'b111;
        @(posedge clk);
        #1;
        expected_outputs = 4'b1111;
        compare(expected_outputs);
        // Every ordered level triplet, including jumps, reversals, and holds.
        for (a = 0; a < 4; a = a + 1)
            for (b = 0; b < 4; b = b + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    step(3, 1);
                    step(a, 0);
                    step(b, 0);
                    step(c, 0);
                    for (k = 0; k < 3; k = k + 1) step(c, 0);
                end
        // Reset at every water level, with nonzero sensors during reset.
        for (a = 0; a < 4; a = a + 1) begin
            step(a, 0);
            step(3, 1);
            step(2, 1);
            step(a, 0);
        end
        $display("PASS: %0d reservoir checks", checks);
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "bounded test timeout");
    end
endmodule
