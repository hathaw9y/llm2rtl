`timescale 1ns/1ps
module dev_tb;
    logic p1a, p1b, p1c, p1d;
    logic p2a, p2b, p2c, p2d;
    wire p1y, p2y;
    integer vector_index;
    integer digit_index;
    integer encoding;
    integer checks = 0;
    logic [7:0] stimulus;

    TopModule dut (
        .p1a(p1a), .p1b(p1b), .p1c(p1c), .p1d(p1d),
        .p2a(p2a), .p2b(p2b), .p2c(p2c), .p2d(p2d),
        .p1y(p1y), .p2y(p2y)
    );

    // Independent truth-table oracle, based on the original NAND definition.
    function automatic logic expected_nand(input logic [3:0] inputs);
        integer i;
        begin
            if (inputs === 4'b1111)
                expected_nand = 1'b0;
            else begin
                expected_nand = 1'bx;
                for (i = 0; i < 4; i = i + 1)
                    if (inputs[i] === 1'b0)
                        expected_nand = 1'b1;
            end
        end
    endfunction

    task automatic check_outputs;
        logic expected1, expected2;
        begin
            expected1 = expected_nand({p1a, p1b, p1c, p1d});
            expected2 = expected_nand({p2a, p2b, p2c, p2d});
            if (p1y !== expected1 || p2y !== expected2)
                $fatal(1, "Mismatch inputs=%b/%b got=%b/%b expected=%b/%b",
                    {p1a,p1b,p1c,p1d}, {p2a,p2b,p2c,p2d},
                    p1y, p2y, expected1, expected2);
            checks = checks + 1;
        end
    endtask

    initial begin
        // No reset or initialization is specified; undriven logic starts X.
        #1;
        check_outputs();
        for (vector_index = 0; vector_index < 256; vector_index = vector_index + 1) begin
            {p1a,p1b,p1c,p1d,p2a,p2b,p2c,p2d} = vector_index[7:0];
            #1;
            check_outputs();
        end
        // Supplemental exhaustive four-state gate semantics.
        for (vector_index = 0; vector_index < 65536; vector_index = vector_index + 1) begin
            encoding = vector_index;
            for (digit_index = 0; digit_index < 8; digit_index = digit_index + 1) begin
                case (encoding % 4)
                    0: stimulus[digit_index] = 1'b0;
                    1: stimulus[digit_index] = 1'b1;
                    2: stimulus[digit_index] = 1'bx;
                    3: stimulus[digit_index] = 1'bz;
                endcase
                encoding = encoding / 4;
            end
            {p1a,p1b,p1c,p1d,p2a,p2b,p2c,p2d} = stimulus;
            #1;
            check_outputs();
        end
        $display("PASS: %0d NAND truth-table checks", checks);
        $finish;
    end

    initial begin
        #70000;
        $fatal(1, "Timeout");
    end
endmodule
