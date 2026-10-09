`timescale 1ns/1ps
module tb_smollm2_rmsnorm_golden;
    logic aclk = 0, aresetn = 0;
    always #5 aclk = ~aclk;
    logic cmd_valid, cmd_ready, done_valid, done_ready, done_error;
    logic [3:0] cmd_opcode, done_tag;
    logic [2:0][3:0] cmd_bank, done_bank;
    logic [111:0] cmd_payload;
    logic [1:0] done_bank_count;
    logic src_read_valid, src_read_ready, src_rsp_valid;
    logic [3:0] src_read_bank, src_rsp_bank;
    logic [15:0] src_read_addr;
    logic [127:0] src_rsp_data;
    logic gamma_read_valid, gamma_read_ready, gamma_rsp_valid;
    logic [3:0] gamma_read_bank, gamma_rsp_bank;
    logic [15:0] gamma_read_addr;
    logic [127:0] gamma_rsp_data;
    logic dst_write_valid, dst_write_ready;
    logic [3:0] dst_write_bank;
    logic [15:0] dst_write_addr, dst_write_strb;
    logic [127:0] dst_write_data;
    logic [127:0] input_words [0:2303];
    logic [127:0] gamma_words [0:71];
    logic [127:0] expected_words [0:2303];
    int writes, mismatches, max_ulp;
    smollm2_rmsnorm_executor dut (.*);
    assign src_read_ready = 1'b1;
    assign gamma_read_ready = 1'b1;
    assign dst_write_ready = 1'b1;
    always_ff @(posedge aclk) begin
        src_rsp_valid <= src_read_valid && src_read_ready;
        src_rsp_bank <= src_read_bank;
        if (src_read_valid) src_rsp_data <= input_words[src_read_addr];
        gamma_rsp_valid <= gamma_read_valid && gamma_read_ready;
        gamma_rsp_bank <= gamma_read_bank;
        if (gamma_read_valid) gamma_rsp_data <= gamma_words[gamma_read_addr];
        if (aresetn && dst_write_valid && dst_write_ready) begin
            if (dst_write_bank != 4'd2 || dst_write_strb != 16'hffff ||
                dst_write_addr != writes) $fatal(1, "write protocol %0d", writes);
            for (int lane = 0; lane < 8; lane++) begin
                int actual, expected, ulp;
                actual = dst_write_data[16*lane +: 16];
                expected = expected_words[writes][16*lane +: 16];
                // Signed BF16 values are monotonically ordered after sign folding.
                actual = (actual & 16'h8000) ? 16'hffff - actual : actual + 16'h8000;
                expected = (expected & 16'h8000) ? 16'hffff - expected : expected + 16'h8000;
                ulp = actual > expected ? actual - expected : expected - actual;
                if (ulp > max_ulp) max_ulp <= ulp;
                if (ulp > 2) begin
                    mismatches <= mismatches + 1;
                    if (mismatches < 8)
                        $display("mismatch word=%0d lane=%0d got=%h expected=%h ulp=%0d",
                            writes, lane, dst_write_data[16*lane +: 16],
                            expected_words[writes][16*lane +: 16], ulp);
                end
            end
            writes <= writes + 1;
        end
    end
    task automatic run_rows(input int rows);
        int cycles;
        begin
            @(negedge aclk);
            writes = 0; mismatches = 0; max_ulp = 0;
            cmd_opcode = 4'd4; cmd_bank[0] = 4'd0;
            cmd_bank[1] = 4'd3; cmd_bank[2] = 4'd2;
            cmd_payload = 112'(rows); cmd_valid = 1;
            @(negedge aclk); cmd_valid = 0;
            cycles = 0;
            while (!done_valid && cycles < 300000) begin
                @(negedge aclk); cycles++;
            end
            if (!done_valid || done_error || writes != rows*72 || mismatches)
                $fatal(1, "RMS rows=%0d failed done=%b err=%b writes=%0d mismatches=%0d max_ulp=%0d",
                    rows, done_valid, done_error, writes, mismatches, max_ulp);
            $display("RMS golden rows=%0d elements=%0d max_ulp=%0d PASS",
                rows, writes*8, max_ulp);
            @(negedge aclk);
        end
    endtask
    initial begin
        string vector_dir;
        int only_one_row;
        if (!$value$plusargs("VECTOR_DIR=%s", vector_dir))
            vector_dir = "golden/rmsnorm";
        only_one_row = $test$plusargs("ONLY_ONE_ROW");
        $readmemh({vector_dir, "/input_words.hex"}, input_words,
                  0, only_one_row ? 71 : 2303);
        $readmemh({vector_dir, "/gamma_words.hex"}, gamma_words);
        $readmemh({vector_dir, "/expected_words.hex"}, expected_words,
                  0, only_one_row ? 71 : 2303);
        cmd_valid = 0; done_ready = 1; cmd_opcode = 0;
        cmd_bank = '0; cmd_payload = '0; writes = 0;
        src_rsp_valid = 0; gamma_rsp_valid = 0;
        repeat (5) @(negedge aclk);
        aresetn = 1;
        run_rows(1);
        if (!only_one_row) run_rows(32);
        $display("RMSNORM BF16 GOLDEN PASS");
        $finish;
    end
endmodule
