`timescale 1ns/1ps
module dev_tb;
    logic a, b;
    wire q;
    integer source_pair, target_pair;
    integer checks = 0;
    TopModule dut (.a(a), .b(b), .q(q));

    task automatic check_pair(input integer pair_index);
        logic expected;
        begin
            case (pair_index)
                0: begin a = 0; b = 0; expected = 0; end
                1: begin a = 0; b = 1; expected = 0; end
                2: begin a = 1; b = 0; expected = 0; end
                3: begin a = 1; b = 1; expected = 1; end
                default: $fatal(1, "Invalid test input");
            endcase
            #1;
            if (q !== expected)
                $fatal(1, "FAIL a=%b b=%b q=%b expected=%b", a, b, q, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (source_pair = 0; source_pair < 4; source_pair = source_pair + 1)
            for (target_pair = 0; target_pair < 4; target_pair = target_pair + 1) begin
                check_pair(source_pair);
                check_pair(target_pair);
            end
        $display("PASS: %0d checks, all four input pairs and sixteen pair transitions", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
