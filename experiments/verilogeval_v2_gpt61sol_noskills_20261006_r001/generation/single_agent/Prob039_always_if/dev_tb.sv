`timescale 1ns/1ps
module dev_tb;
    reg a, b, sel_b1, sel_b2;
    wire out_assign, out_always;
    reg expected;
    integer vector;
    integer checks = 0;
    TopModule dut(.a(a), .b(b), .sel_b1(sel_b1), .sel_b2(sel_b2),
                  .out_assign(out_assign), .out_always(out_always));

    task check_outputs;
        begin
            // Truth-table oracle: only selector pair 11 chooses b.
            case ({sel_b1, sel_b2})
                2'b11: expected = b;
                default: expected = a;
            endcase
            if (out_assign !== expected || out_always !== expected)
                $fatal(1, "Mux mismatch a=%b b=%b selects=%b%b expected=%b assign=%b always=%b",
                       a, b, sel_b1, sel_b2, expected, out_assign, out_always);
            checks = checks + 1;
        end
    endtask

    initial begin
        for (vector = 0; vector < 16; vector = vector + 1) begin
            {a, b, sel_b1, sel_b2} = vector[3:0];
            #1;
            check_outputs;
        end
        // Reverse order exercises transitions from selected b back to a.
        for (vector = 15; vector >= 0; vector = vector - 1) begin
            {a, b, sel_b1, sel_b2} = vector[3:0];
            #1;
            check_outputs;
        end
        $display("PASS: %0d exhaustive combinational mux checks", checks);
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "Development test timeout");
    end
endmodule
