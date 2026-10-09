`timescale 1ns/1ps
module tb_smollm2_rope_executor;
    logic aclk = 0;
    always #5 aclk = ~aclk;
    logic aresetn = 0, cmd_valid = 0, cmd_ready;
    logic [3:0] cmd_opcode = 5;
    logic [2:0][3:0] cmd_bank;
    logic [111:0] cmd_payload;
    logic done_valid, done_ready = 1;
    logic [3:0] done_tag;
    logic [1:0] done_bank_count;
    logic [2:0][3:0] done_bank;
    logic done_error;
    logic data_read_valid, data_read_ready;
    logic [3:0] data_read_bank;
    logic [15:0] data_read_addr;
    logic data_rsp_valid = 0;
    logic [3:0] data_rsp_bank = 0;
    logic [127:0] data_rsp_data = 0;
    logic coeff_read_valid, coeff_read_ready;
    logic [3:0] coeff_read_bank;
    logic [15:0] coeff_read_addr;
    logic coeff_rsp_valid = 0;
    logic [3:0] coeff_rsp_bank = 0;
    logic [127:0] coeff_rsp_data = 0;
    logic data_write_valid, data_write_ready;
    logic [3:0] data_write_bank;
    logic [15:0] data_write_addr, data_write_strb;
    logic [127:0] data_write_data;
    logic [127:0] data_mem [0:2303];
    logic [127:0] coeff_mem [0:255];
    logic [127:0] expected_mem [0:2303];
    integer cycle = 0, writes = 0;
    integer rows, words, bad, exact_bad, distance;
    integer k_bank;
    string case_dir, kind, path, negative;
    logic [15:0] actual_v, expected_v;

    smollm2_rope_executor dut (.*);
    assign data_read_ready = cycle % 4 != 0;
    assign coeff_read_ready = cycle % 5 != 0;
    assign data_write_ready = cycle % 7 != 0;

    function automatic integer ordered(input logic [15:0] v);
        ordered = v[15] ? int'(~v) & 16'hffff : int'(v | 16'h8000);
    endfunction

    always @(posedge aclk) begin
        cycle <= cycle + 1;
        data_rsp_valid <= data_read_valid && data_read_ready;
        if (data_read_valid && data_read_ready) begin
            if (data_read_bank != cmd_bank[0] || data_read_addr >= words)
                $fatal(1, "bad data read bank=%d addr=%d", data_read_bank, data_read_addr);
            data_rsp_bank <= data_read_bank;
            data_rsp_data <= data_mem[data_read_addr];
        end
        coeff_rsp_valid <= coeff_read_valid && coeff_read_ready;
        if (coeff_read_valid && coeff_read_ready) begin
            if (coeff_read_bank != 7 || coeff_read_addr >= rows * 8)
                $fatal(1, "bad coeff read bank=%d addr=%d", coeff_read_bank, coeff_read_addr);
            coeff_rsp_bank <= coeff_read_bank;
            coeff_rsp_data <= coeff_mem[coeff_read_addr];
        end
        if (data_write_valid && data_write_ready) begin
            if (data_write_bank != cmd_bank[0] || data_write_addr >= words ||
                data_write_strb != 16'hffff)
                $fatal(1, "bad data write bank=%d addr=%d", data_write_bank, data_write_addr);
            data_mem[data_write_addr] <= data_write_data;
            writes <= writes + 1;
        end
        if (cycle > 120000) $fatal(1, "ROPE timeout");
    end

    initial begin
        if (!$value$plusargs("CASE=%s", case_dir)) $fatal(1, "missing CASE");
        if (!$value$plusargs("KIND=%s", kind)) $fatal(1, "missing KIND");
        if (!$value$plusargs("ROWS=%d", rows)) $fatal(1, "missing ROWS");
        if (!$value$plusargs("NEGATIVE=%s", negative)) negative = "none";
        if (!$value$plusargs("KBANK=%d", k_bank)) k_bank = 5;
        if (kind == "k" && k_bank != 5 && k_bank != 8)
            $fatal(1, "bad test K bank %0d", k_bank);
        cmd_bank = kind == "q" ? {4'd0, 4'd7, 4'd4} :
                   {4'd0, 4'd7, 4'(k_bank)};
        cmd_payload = 112'(rows);
        words = rows * (kind == "q" ? 72 : 24);
        path = {case_dir, "/", kind, "_input_words.hex"};
        $readmemh(path, data_mem, 0, words - 1);
        path = {case_dir, "/coeff_words.hex"};
        $readmemh(path, coeff_mem, 0, rows * 8 - 1);
        path = {case_dir, "/", kind, "_expected_words.hex"};
        $readmemh(path, expected_mem, 0, words - 1);
        if (negative == "zero_rows") cmd_payload = '0;
        if (negative == "too_many_rows") cmd_payload = 112'd33;
        if (negative == "wrong_bank") cmd_bank[1] = 4'd6;
        if (negative == "nan_input") data_mem[0][15:0] = 16'h7fc0;
        repeat (3) @(negedge aclk);
        aresetn = 1;
        cmd_valid = 1;
        @(negedge aclk);
        cmd_valid = 0;
        wait (done_valid);
        @(negedge aclk);
        if (negative != "none") begin
            if (!done_error || done_tag != cmd_bank[0] ||
                done_bank_count != 2 || done_bank != cmd_bank || writes != 0)
                $fatal(1, "bad error response for %s", negative);
            $display("PASS ROPE rejects %s", negative);
            $finish;
        end
        if (done_error || done_tag != cmd_bank[0] ||
            done_bank_count != 2 || done_bank != cmd_bank)
            $fatal(1, "bad completion response");
        if (writes != words) $fatal(1, "writes=%d expected=%d", writes, words);
        bad = 0; exact_bad = 0;
        for (integer w = 0; w < words; w++) begin
            for (integer lane = 0; lane < 8; lane++) begin
                actual_v = data_mem[w][16*lane +: 16];
                expected_v = expected_mem[w][16*lane +: 16];
                if (actual_v != expected_v) begin
                    exact_bad++;
                    distance = ordered(actual_v) - ordered(expected_v);
                    if (distance < 0) distance = -distance;
                    if (distance > 2) begin
                        bad++;
                        if (bad < 8) $display("mismatch word=%d lane=%d actual=%h expected=%h ulp=%d",
                                               w, lane, actual_v, expected_v, distance);
                    end
                end
            end
        end
        if (bad != 0) $fatal(1, "ROPE >2 ULP errors=%d", bad);
        $display("PASS ROPE %s rows=%d compared=%d exact_mismatch=%d over2ulp=%d cycles=%d",
                 kind, rows, words * 8, exact_bad, bad, cycle);
        $finish;
    end
endmodule
