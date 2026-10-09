`timescale 1ns/1ps
module tb_smollm2_softmax_executor;
    logic aclk = 0, aresetn = 0;
    always #3.333 aclk = ~aclk;
    logic cmd_valid = 0, cmd_ready;
    logic [3:0] cmd_opcode = 0;
    logic [2:0][3:0] cmd_bank = '0;
    logic [111:0] cmd_payload = '0;
    logic done_valid, done_ready = 0;
    logic [3:0] done_tag;
    logic [1:0] done_bank_count;
    logic [2:0][3:0] done_bank;
    logic done_error;
    logic data_read_valid, data_read_ready = 1;
    logic [3:0] data_read_bank, data_rsp_bank = 0;
    logic [15:0] data_read_addr;
    logic data_rsp_valid = 0;
    logic [127:0] data_rsp_data = 0;
    logic data_write_valid, data_write_ready = 1;
    logic [3:0] data_write_bank;
    logic [15:0] data_write_addr, data_write_strb;
    logic [127:0] data_write_data;
    logic [127:0] bank [0:1151];
    logic [127:0] prefill_score [0:1151], prefill_expected [0:1151];
    logic [127:0] decode_score [0:44], decode_expected [0:44];
    logic [127:0] long_score [0:1151], long_expected [0:1151];
    logic [2:0] response_pipe = 0;
    logic [127:0] response_data_pipe [0:2];
    logic [3:0] response_bank_pipe [0:2];
    int cycle_count = 0, write_count = 0;

    smollm2_softmax_executor dut (.*);

    always @(posedge aclk) begin
        if (!aresetn) begin
            response_pipe <= 0;
            data_rsp_valid <= 0;
            data_rsp_data <= 0;
            data_rsp_bank <= 0;
            cycle_count <= 0;
            write_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            data_read_ready <= cycle_count % 11 != 0;
            data_write_ready <= cycle_count % 13 != 0;
            response_pipe <= {response_pipe[1:0],
                              data_read_valid && data_read_ready};
            if (data_read_valid && data_read_ready) begin
                if (data_read_bank != 4'd10 || data_read_addr >= 1152)
                    $fatal(1, "bad softmax read bank=%0d addr=%0d", data_read_bank, data_read_addr);
                response_data_pipe[0] <= bank[data_read_addr];
                response_bank_pipe[0] <= data_read_bank;
            end
            response_data_pipe[1] <= response_data_pipe[0];
            response_data_pipe[2] <= response_data_pipe[1];
            response_bank_pipe[1] <= response_bank_pipe[0];
            response_bank_pipe[2] <= response_bank_pipe[1];
            data_rsp_valid <= response_pipe[2];
            data_rsp_data <= response_data_pipe[2];
            data_rsp_bank <= response_bank_pipe[2];
            if (data_write_valid && data_write_ready) begin
                if (data_write_bank != 4'd10 || data_write_addr >= 1152 ||
                    data_write_strb != 16'hffff || data_write_addr != write_count)
                    $fatal(1, "bad softmax write bank=%0d addr=%0d count=%0d",
                           data_write_bank, data_write_addr, write_count);
                bank[data_write_addr] <= data_write_data;
                write_count <= write_count + 1;
            end
        end
    end

    function automatic int ulp(input logic [15:0] actual, expected);
        int a, b;
        a = actual[15] ? 16'hffff - actual : int'(actual) + 16'h8000;
        b = expected[15] ? 16'hffff - expected : int'(expected) + 16'h8000;
        return a > b ? a-b : b-a;
    endfunction

    task automatic run_case(input string label, input int start, rows, kv_len, words);
        logic [127:0] source_word, golden_word;
        logic [15:0] got, expected;
        int mismatches, max_ulp;
        begin
            for (int i = 0; i < words; i++) begin
                if (label == "prefill32") source_word = prefill_score[i];
                else if (label == "decode1") source_word = decode_score[i];
                else source_word = long_score[i];
                bank[i] = source_word;
            end
            write_count = 0;
            @(negedge aclk);
            cmd_opcode = 7;
            cmd_bank = {4'd0, 4'd0, 4'd10};
            cmd_payload = (112'(start) << 17) | (112'(rows) << 11) | 112'(kv_len);
            cmd_valid = 1;
            do @(posedge aclk); while (!cmd_ready);
            #1; cmd_valid = 0;
            wait (done_valid);
            if (done_error || done_tag != 10 || done_bank_count != 1 ||
                done_bank != {4'd0, 4'd0, 4'd10} || write_count != words)
                $fatal(1, "%s done error=%b writes=%0d expected=%0d",
                       label, done_error, write_count, words);
            repeat (3) begin
                @(posedge aclk);
                if (!done_valid) $fatal(1, "done not held");
            end
            mismatches = 0; max_ulp = 0;
            for (int i = 0; i < words; i++) begin
                if (label == "prefill32") golden_word = prefill_expected[i];
                else if (label == "decode1") golden_word = decode_expected[i];
                else golden_word = long_expected[i];
                for (int lane = 0; lane < 8; lane++) begin
                    got = bank[i][16*lane +: 16];
                    expected = golden_word[16*lane +: 16];
                    if (ulp(got, expected) > max_ulp) max_ulp = ulp(got, expected);
                    if (ulp(got, expected) > 2) begin
                        if (mismatches < 8)
                            $display("%s mismatch word=%0d lane=%0d got=%h expected=%h ulp=%0d",
                                     label, i, lane, got, expected, ulp(got, expected));
                        mismatches++;
                    end
                end
            end
            if (mismatches != 0) $fatal(1, "%s mismatches=%0d", label, mismatches);
            $display("PASS SOFTMAX %s compare=%0d mismatches=0 max_ulp=%0d",
                     label, words*8, max_ulp);
            @(negedge aclk); done_ready = 1;
            @(posedge aclk); #1; done_ready = 0;
            @(posedge aclk);
        end
    endtask

    task automatic reject(input logic [3:0] op, bank,
                          input logic [111:0] payload);
        begin
            @(negedge aclk);
            cmd_opcode = op; cmd_bank = {4'd0, 4'd0, bank};
            cmd_payload = payload; cmd_valid = 1;
            do @(posedge aclk); while (!cmd_ready);
            #1; cmd_valid = 0;
            wait (done_valid);
            if (!done_error) $fatal(1, "invalid command accepted");
            @(negedge aclk); done_ready = 1;
            @(posedge aclk); #1; done_ready = 0;
        end
    endtask

    task automatic reject_nonfinite;
        begin
            bank[0] = {112'd0, 16'h7fc1};
            @(negedge aclk);
            cmd_opcode = 7; cmd_bank = {4'd0, 4'd0, 4'd10};
            cmd_payload = (112'(1) << 11) | 112'(1);
            cmd_valid = 1;
            do @(posedge aclk); while (!cmd_ready);
            #1; cmd_valid = 0;
            wait (done_valid);
            if (!done_error) $fatal(1, "nonfinite score accepted");
            @(negedge aclk); done_ready = 1;
            @(posedge aclk); #1; done_ready = 0;
        end
    endtask

    initial begin
        $readmemh("vectors/prefill32_score_words.hex", prefill_score);
        $readmemh("vectors/prefill32_expected_words.hex", prefill_expected);
        $readmemh("vectors/decode1_score_words.hex", decode_score);
        $readmemh("vectors/decode1_expected_words.hex", decode_expected);
        $readmemh("vectors/context1024_score_words.hex", long_score);
        $readmemh("vectors/context1024_expected_words.hex", long_expected);
        repeat (4) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        run_case("prefill32", 0, 32, 32, 1152);
        run_case("decode1", 32, 1, 33, 45);
        run_case("context1024", 1023, 1, 1024, 1152);
        reject(7, 10, 112'(32));
        reject(7, 9, (112'(1) << 11) | 112'(1));
        reject(7, 10, (112'(1023) << 17) | (112'(2) << 11) | 112'(1024));
        reject(7, 10, (112'(1) << 27) | (112'(1) << 11) | 112'(1));
        reject_nonfinite();
        $display("PASS smollm2_softmax_executor");
        $finish;
    end
    initial begin
        #100000000;
        $fatal(1, "softmax timeout state=%0d writes=%0d", dut.state_r, write_count);
    end
endmodule
