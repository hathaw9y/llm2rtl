`timescale 1ns/1ps
module tb_smollm2_attention_executor;
    logic clk = 0;
    always #3.333 clk = ~clk;
    logic resetn = 0;
    logic [1:0] cmd_valid, cmd_ready, done_valid, done_error;
    logic [1:0][3:0] cmd_opcode, done_tag;
    logic [1:0][2:0][3:0] cmd_bank, done_bank;
    logic [1:0][111:0] payload;
    logic [1:0][1:0] done_bank_count;
    logic [1:0] a_req, b_req, dst_valid;
    logic [1:0][3:0] a_bank, b_bank, dst_bank, a_rsp_bank, b_rsp_bank;
    logic [1:0][15:0] a_addr, b_addr, dst_addr, dst_strb;
    logic [1:0][127:0] a_rsp_data, b_rsp_data, dst_data;
    logic [1:0] a_rsp_valid, b_rsp_valid;
    logic [127:0] q_prefill[0:2303], q_decode[0:71];
    logic [127:0] k_prefill[0:767], k_decode[0:791];
    logic [127:0] v_prefill[0:767], v_decode[0:791];
    logic [127:0] score_prefill[0:1151], score_decode[0:44];
    logic [127:0] prob_prefill[0:1151], prob_decode[0:44];
    logic [127:0] context_prefill[0:2303], context_decode[0:71];
    logic [127:0] q_mem[0:2303], k_mem[0:791], v_mem[0:791], p_mem[0:1151];
    logic [127:0] score_expect[0:1151], context_expect[0:2303];
    logic [127:0] score_actual[0:1151], context_actual[0:2303];
    integer score_count, context_count;

    for (genvar i=0; i<2; i++) begin : dut
        smollm2_attention_executor #(.MODE_VALUE(i != 0)) core (
            .aclk(clk), .aresetn(resetn),
            .cmd_valid(cmd_valid[i]), .cmd_ready(cmd_ready[i]),
            .cmd_opcode(cmd_opcode[i]), .cmd_bank(cmd_bank[i]),
            .cmd_payload(payload[i]), .done_valid(done_valid[i]),
            .done_ready(1'b1), .done_tag(done_tag[i]),
            .done_bank_count(done_bank_count[i]), .done_bank(done_bank[i]),
            .done_error(done_error[i]),
            .a_read_valid(a_req[i]), .a_read_ready(1'b1),
            .a_read_bank(a_bank[i]), .a_read_addr(a_addr[i]),
            .a_rsp_valid(a_rsp_valid[i]), .a_rsp_bank(a_rsp_bank[i]),
            .a_rsp_data(a_rsp_data[i]),
            .b_read_valid(b_req[i]), .b_read_ready(1'b1),
            .b_read_bank(b_bank[i]), .b_read_addr(b_addr[i]),
            .b_rsp_valid(b_rsp_valid[i]), .b_rsp_bank(b_rsp_bank[i]),
            .b_rsp_data(b_rsp_data[i]),
            .dst_write_valid(dst_valid[i]), .dst_write_ready(1'b1),
            .dst_write_bank(dst_bank[i]), .dst_write_addr(dst_addr[i]),
            .dst_write_strb(dst_strb[i]), .dst_write_data(dst_data[i])
        );
    end

    always @(posedge clk) begin
        a_rsp_valid <= resetn ? a_req : '0;
        b_rsp_valid <= resetn ? b_req : '0;
        if (a_req[0]) begin
            if (a_addr[0] >= 2304) $fatal(1, "Q address %d", a_addr[0]);
            a_rsp_data[0] <= q_mem[a_addr[0]];
            a_rsp_bank[0] <= 4'd4;
        end
        if (b_req[0]) begin
            if (b_addr[0] >= 792) $fatal(1, "K address %d", b_addr[0]);
            b_rsp_data[0] <= k_mem[b_addr[0]];
            b_rsp_bank[0] <= 4'd8;
        end
        if (a_req[1]) begin
            if (a_addr[1] >= 1152) $fatal(1, "P address %d", a_addr[1]);
            a_rsp_data[1] <= p_mem[a_addr[1]];
            a_rsp_bank[1] <= 4'd10;
        end
        if (b_req[1]) begin
            if (b_addr[1] >= 792) $fatal(1, "V address %d", b_addr[1]);
            b_rsp_data[1] <= v_mem[b_addr[1]];
            b_rsp_bank[1] <= 4'd9;
        end
        if (resetn && dst_valid[0]) begin
            if (dst_bank[0] != 10 || dst_addr[0] != score_count ||
                dst_strb[0] != 16'hffff) $fatal(1,"score write order");
            score_actual[score_count] <= dst_data[0];
            score_count <= score_count + 1;
        end
        if (resetn && dst_valid[1]) begin
            if (dst_bank[1] != 11 || dst_addr[1] != context_count ||
                dst_strb[1] != 16'hffff) $fatal(1,"context write order");
            context_actual[context_count] <= dst_data[1];
            context_count <= context_count + 1;
        end
    end

    function automatic integer ulp(input logic [15:0] a, b);
        integer aa, bb;
        begin
            aa = a[15] ? 65535 - int'(a) : int'(a) + 32768;
            bb = b[15] ? 65535 - int'(b) : int'(b) + 32768;
            ulp = aa > bb ? aa-bb : bb-aa;
        end
    endfunction

    task automatic run_case(input string label, input integer mode,
                            input integer q_start, input integer kv_len,
                            input integer q_index, input integer score_index,
                            input integer rows_count);
        integer score_words, mismatch, max_ulp, distance;
        begin
            score_words = rows_count*9*((kv_len+7)/8);
            for (integer i=0; i<72*rows_count; i++) begin
                q_mem[i] = mode == 2 ? q_decode[i] : q_prefill[q_index+i];
                context_expect[i] = mode == 2 ? context_decode[i] :
                                                     context_prefill[q_index+i];
            end
            for (integer i=0; i<kv_len*24; i++) begin
                k_mem[i] = mode == 2 ? k_decode[i] : k_prefill[i];
                v_mem[i] = mode == 2 ? v_decode[i] : v_prefill[i];
            end
            for (integer i=0; i<score_words; i++) begin
                score_expect[i] = mode == 2 ? score_decode[i] :
                                                    score_prefill[score_index+i];
                p_mem[i] = mode == 2 ? prob_decode[i] :
                                              prob_prefill[score_index+i];
            end
            @(negedge clk);
            score_count = 0; context_count = 0;
            cmd_opcode[0] = 6; cmd_bank[0] = {4'd10,4'd8,4'd4};
            cmd_opcode[1] = 8; cmd_bank[1] = {4'd11,4'd9,4'd10};
            payload[0] = (112'(q_start)<<17) | (112'(rows_count)<<11) | 112'(kv_len);
            payload[1] = payload[0];
            cmd_valid[0] = 1;
            @(negedge clk); cmd_valid[0] = 0;
            wait(done_valid[0]);
            if (done_error[0] || done_tag[0] != 4 ||
                done_bank_count[0] != 3 || done_bank[0] != {4'd10,4'd8,4'd4})
                $fatal(1,"score completion");
            @(negedge clk);
            if (score_count != score_words) $fatal(1,"score count %d",score_count);
            mismatch=0; max_ulp=0;
            for (integer i=0; i<score_words; i++)
                for (integer lane=0; lane<8; lane++) begin
                    distance=ulp(score_actual[i][16*lane+:16],
                                 score_expect[i][16*lane+:16]);
                    if (distance>max_ulp) max_ulp=distance;
                    if (distance>2) begin
                        if (mismatch<8) $display("%s score mismatch word=%d lane=%d got=%h expected=%h ulp=%d",
                                                 label,i,lane,score_actual[i][16*lane+:16],
                                                 score_expect[i][16*lane+:16],distance);
                        mismatch++;
                    end
                end
            if (mismatch) $fatal(1,"%s score mismatches=%d max_ulp=%d",label,mismatch,max_ulp);
            $display("PASS %s score compare=%d max_ulp=%d",label,score_words*8,max_ulp);
            cmd_valid[1]=1;
            @(negedge clk); cmd_valid[1]=0;
            wait(done_valid[1]);
            if (done_error[1] || done_tag[1] != 10 ||
                done_bank_count[1] != 3 || done_bank[1] != {4'd11,4'd9,4'd10})
                $fatal(1,"value completion");
            @(negedge clk);
            if (context_count != 72*rows_count) $fatal(1,"context count %d",context_count);
            mismatch=0; max_ulp=0;
            for (integer i=0; i<72*rows_count; i++)
                for (integer lane=0; lane<8; lane++) begin
                    distance=ulp(context_actual[i][16*lane+:16],
                                 context_expect[i][16*lane+:16]);
                    if (distance>max_ulp) max_ulp=distance;
                    if (distance>2) begin
                        if (mismatch<8) $display("%s value mismatch word=%d lane=%d got=%h expected=%h ulp=%d",
                                                 label,i,lane,context_actual[i][16*lane+:16],
                                                 context_expect[i][16*lane+:16],distance);
                        mismatch++;
                    end
                end
            if (mismatch) $fatal(1,"%s value mismatches=%d max_ulp=%d",label,mismatch,max_ulp);
            $display("PASS %s value compare=%d max_ulp=%d",label,576*rows_count,max_ulp);
        end
    endtask

    initial begin
        $readmemh("vectors/prefill32_q_words.hex",q_prefill);
        $readmemh("vectors/prefill32_k_cache_words.hex",k_prefill);
        $readmemh("vectors/prefill32_v_cache_words.hex",v_prefill);
        $readmemh("vectors/prefill32_score_words.hex",score_prefill);
        $readmemh("vectors/prefill32_probability_words.hex",prob_prefill);
        $readmemh("vectors/prefill32_context_words.hex",context_prefill);
        $readmemh("vectors/decode1_q_words.hex",q_decode);
        $readmemh("vectors/decode1_k_cache_words.hex",k_decode);
        $readmemh("vectors/decode1_v_cache_words.hex",v_decode);
        $readmemh("vectors/decode1_score_words.hex",score_decode);
        $readmemh("vectors/decode1_probability_words.hex",prob_decode);
        $readmemh("vectors/decode1_context_words.hex",context_decode);
        cmd_valid='0; cmd_opcode='0; cmd_bank='0; payload='0;
        score_count=0; context_count=0;
        repeat(5) @(negedge clk); resetn=1;
        run_case("prefill_first",0,0,32,0,0,1);
        run_case("prefill_last",1,31,32,31*72,31*36,1);
        run_case("decode1",2,32,33,0,0,1);
        run_case("prefill_full",0,0,32,0,0,32);
        $display("PASS smollm2_attention_executor");
        $finish;
    end
    initial begin #200000000; $fatal(1,"attention timeout"); end
endmodule
