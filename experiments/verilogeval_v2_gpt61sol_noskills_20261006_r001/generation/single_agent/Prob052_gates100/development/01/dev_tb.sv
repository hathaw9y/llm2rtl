`timescale 1ns/1ps
module dev_tb;
    reg [99:0] in;
    wire out_and, out_or, out_xor;
    integer i, j, trial;
    integer checks = 0;
    reg [99:0] stimulus;
    TopModule dut(.in(in), .out_and(out_and), .out_or(out_or), .out_xor(out_xor));

    task check(input reg [99:0] value);
        reg expected_and, expected_or, expected_xor;
        integer k;
        begin
            expected_and = 1'b1;
            expected_or = 1'b0;
            expected_xor = 1'b0;
            for (k = 0; k < 100; k = k + 1) begin
                expected_and = expected_and & value[k];
                expected_or = expected_or | value[k];
                expected_xor = expected_xor ^ value[k];
            end
            in = value;
            #1;
            if ({out_and, out_or, out_xor} !== {expected_and, expected_or, expected_xor})
                $fatal(1, "Mismatch input=%h actual=%b expected=%b", value,
                       {out_and, out_or, out_xor}, {expected_and, expected_or, expected_xor});
            checks = checks + 1;
        end
    endtask

    initial begin
        check(100'b0);
        check({100{1'b1}});
        for (i = 0; i < 100; i = i + 1) begin
            stimulus = 100'b0;
            stimulus[i] = 1'b1;
            check(stimulus);
            check(~stimulus);
        end
        for (i = 0; i <= 100; i = i + 1) begin
            stimulus = 100'b0;
            for (j = 0; j < i; j = j + 1) stimulus[j] = 1'b1;
            check(stimulus);
        end
        for (trial = 0; trial < 500; trial = trial + 1) begin
            for (j = 0; j < 100; j = j + 1) stimulus[j] = $random;
            check(stimulus);
        end
        check({100{1'bx}});
        check({100{1'bz}});
        for (i = 0; i < 100; i = i + 1) begin
            stimulus = 100'b0; stimulus[i] = 1'bx; check(stimulus);
            stimulus = {100{1'b1}}; stimulus[i] = 1'bx; check(stimulus);
            stimulus = 100'b0; stimulus[i] = 1'bz; check(stimulus);
            stimulus = {100{1'b1}}; stimulus[i] = 1'bz; check(stimulus);
        end
        $display("PASS: %0d combinational checks", checks);
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
