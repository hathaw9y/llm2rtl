`timescale 1ns/1ps
module tb_smollm2_gemm_attention_modes;
    logic clk=0, resetn=0;
    always #3.333 clk=~clk;
    logic cmd_valid=0, cmd_ready, done_valid, done_error;
    logic [3:0] cmd_opcode, done_tag;
    logic [2:0][3:0] cmd_bank, done_bank;
    logic [111:0] cmd_payload;
    logic [1:0] done_bank_count;
    logic a_req, b_req, dst_valid;
    logic [3:0] a_bank, b_bank, dst_bank, a_rsp_bank, b_rsp_bank;
    logic [15:0] a_addr, b_addr, dst_addr, dst_strb;
    logic [255:0] a_rsp_data, b_rsp_data;
    logic [127:0] dst_data;
    logic a_rsp_valid=0, b_rsp_valid=0;
    logic [127:0] q_prefill[0:2303], q_decode[0:71];
    logic [127:0] k_prefill[0:767], k_decode[0:791];
    logic [127:0] v_prefill[0:767], v_decode[0:791];
    logic [127:0] score_prefill[0:1151], score_decode[0:44];
    logic [127:0] prob_prefill[0:1151], prob_decode[0:44];
    logic [127:0] context_prefill[0:2303], context_decode[0:71];
    logic [127:0] q_mem[0:2303], k_mem[0:4631], v_mem[0:4631], p_mem[0:1151];
    logic [127:0] score_expect[0:1151], context_expect[0:2303];
    logic [127:0] score_actual[0:1151], context_actual[0:2303];
    integer score_writes, context_writes;

    smollm2_gemm_systolic_wide_executor dut (
        .aclk(clk), .aresetn(resetn), .cmd_valid(cmd_valid), .cmd_ready(cmd_ready),
        .cmd_opcode(cmd_opcode), .cmd_bank(cmd_bank), .cmd_payload(cmd_payload),
        .done_valid(done_valid), .done_ready(1'b1), .done_tag(done_tag),
        .done_bank_count(done_bank_count), .done_bank(done_bank),
        .done_error(done_error), .act_read_valid(a_req), .act_read_ready(1'b1),
        .act_read_bank(a_bank), .act_read_addr(a_addr), .act_rsp_valid(a_rsp_valid),
        .act_rsp_bank(a_rsp_bank), .act_rsp_data(a_rsp_data),
        .weight_read_valid(b_req), .weight_read_ready(1'b1),
        .weight_read_bank(b_bank), .weight_read_addr(b_addr),
        .weight_rsp_valid(b_rsp_valid), .weight_rsp_bank(b_rsp_bank),
        .weight_rsp_data(b_rsp_data), .dst_write_valid(dst_valid),
        .dst_write_ready(1'b1), .dst_write_bank(dst_bank),
        .dst_write_addr(dst_addr), .dst_write_strb(dst_strb),
        .dst_write_data(dst_data));

    always @(posedge clk) begin
        a_rsp_valid <= resetn && a_req;
        b_rsp_valid <= resetn && b_req;
        if (a_req) begin
            a_rsp_bank <= a_bank;
            if (cmd_opcode==6) begin
                if (a_addr>=2304) $fatal(1,"Q read address %d",a_addr);
                a_rsp_data <= {128'd0,q_mem[a_addr]};
            end else begin
                if (a_addr>=1152) $fatal(1,"P read address %d",a_addr);
                a_rsp_data <= {128'd0,p_mem[a_addr]};
            end
        end
        if (b_req) begin
            b_rsp_bank <= b_bank;
            if (b_addr>=4632) $fatal(1,"K/V read address %d",b_addr);
            b_rsp_data <= cmd_opcode==6 ? {128'd0,k_mem[b_addr]} :
                                          {128'd0,v_mem[b_addr]};
        end
        if (resetn && dst_valid) begin
            if (cmd_opcode==6) begin
                if (dst_bank!=10 || dst_addr>=1152) $fatal(1,"score write address");
                for (int lane=0;lane<8;lane++)
                    if (dst_strb[2*lane +: 2]==2'b11)
                        score_actual[dst_addr][16*lane +: 16] <=
                            dst_data[16*lane +: 16];
                if (dst_strb[15:14]==2'b11) score_writes <= score_writes+1;
            end else begin
                if (dst_bank!=11 || dst_addr>=2304) $fatal(1,"context write address");
                for (int lane=0;lane<8;lane++)
                    if (dst_strb[2*lane +: 2]==2'b11)
                        context_actual[dst_addr][16*lane +: 16] <=
                            dst_data[16*lane +: 16];
                if (dst_strb[15:14]==2'b11) context_writes <= context_writes+1;
            end
        end
    end

    function automatic integer ulp(input logic [15:0] a,b);
        integer aa,bb;
        aa=a[15] ? 65535-int'(a) : int'(a)+32768;
        bb=b[15] ? 65535-int'(b) : int'(b)+32768;
        return aa>bb ? aa-bb : bb-aa;
    endfunction

    task automatic launch(input int op,start,rows,kv);
        @(negedge clk);
        cmd_opcode=4'(op);
        cmd_bank=op==6 ? {4'd10,4'd8,4'd4} : {4'd11,4'd9,4'd10};
        cmd_payload=(112'(start)<<17)|(112'(rows)<<11)|112'(kv);
        cmd_valid=1;
        @(posedge clk);
        if (!cmd_ready) $fatal(1,"command not ready");
        @(negedge clk); cmd_valid=0;
        wait(done_valid);
        if (done_error || done_bank!=cmd_bank || done_bank_count!=3 ||
            done_tag!=cmd_bank[0]) $fatal(1,"bad completion op=%d",op);
        @(negedge clk);
    endtask

    task automatic run_case(input string label,input int mode,start,kv,
                            q_index,score_index,rows);
        int score_words,context_words,errors,max_ulp,distance;
        score_words=rows*9*((kv+7)/8);
        context_words=rows*72;
        for(int i=0;i<context_words;i++) begin
            q_mem[i]=mode==2 ? q_decode[i] : q_prefill[q_index+i];
            context_expect[i]=mode==2 ? context_decode[i] :
                context_prefill[q_index+i];
            context_actual[i]='0;
        end
        for(int i=0;i<kv*24;i++) begin
            k_mem[i]=mode==2 ? k_decode[i] : k_prefill[i];
            v_mem[i]=mode==2 ? v_decode[i] : v_prefill[i];
        end
        for(int i=0;i<score_words;i++) begin
            score_expect[i]=mode==2 ? score_decode[i] :
                score_prefill[score_index+i];
            p_mem[i]=mode==2 ? prob_decode[i] : prob_prefill[score_index+i];
            score_actual[i]='0;
        end
        score_writes=0;context_writes=0;
        launch(6,start,rows,kv);
        if(score_writes!=score_words)
            $fatal(1,"%s score writes=%d expected=%d",label,score_writes,score_words);
        errors=0;max_ulp=0;
        for(int i=0;i<score_words;i++) for(int lane=0;lane<8;lane++) begin
            distance=ulp(score_actual[i][16*lane +:16],score_expect[i][16*lane +:16]);
            if(distance>max_ulp)max_ulp=distance;
            if(distance>8) begin
                if(errors<8)$display("%s score word=%d lane=%d got=%h expected=%h ulp=%d",
                    label,i,lane,score_actual[i][16*lane +:16],
                    score_expect[i][16*lane +:16],distance);
                errors++;
            end
        end
        if(errors)$fatal(1,"%s score errors=%d max_ulp=%d",label,errors,max_ulp);
        $display("PASS %s score compare=%d max_ulp=%d",label,score_words*8,max_ulp);
        launch(8,start,rows,kv);
        if(context_writes!=context_words)
            $fatal(1,"%s context writes=%d expected=%d",label,context_writes,context_words);
        errors=0;max_ulp=0;
        for(int i=0;i<context_words;i++)for(int lane=0;lane<8;lane++)begin
            distance=ulp(context_actual[i][16*lane +:16],context_expect[i][16*lane +:16]);
            if(distance>max_ulp)max_ulp=distance;
            if(distance>16)begin
                if(errors<8)$display("%s context word=%d lane=%d got=%h expected=%h ulp=%d",
                    label,i,lane,context_actual[i][16*lane +:16],
                    context_expect[i][16*lane +:16],distance);
                errors++;
            end
        end
        if(errors)$fatal(1,"%s context errors=%d max_ulp=%d",label,errors,max_ulp);
        $display("PASS %s context compare=%d max_ulp=%d",label,context_words*8,max_ulp);
    endtask

    task automatic run_tile_boundary;
        int score_words;
        score_words=9*((193+7)/8);
        for(int i=0;i<72;i++)q_mem[i]=128'h3f803f803f803f803f803f803f803f80;
        for(int i=0;i<193*24;i++)begin
            k_mem[i]=128'h3f803f803f803f803f803f803f803f80;
            v_mem[i]=128'h3f803f803f803f803f803f803f803f80;
        end
        for(int i=0;i<score_words;i++)begin
            p_mem[i]='0;
            score_actual[i]='0;
        end
        for(int head=0;head<9;head++)p_mem[head*25][15:0]=16'h3f80;
        for(int i=0;i<72;i++)context_actual[i]='0;
        score_writes=0;context_writes=0;
        launch(6,192,1,193);
        if(score_writes!=score_words)$fatal(1,"N tile score writes");
        for(int head=0;head<9;head++)for(int token=0;token<200;token++)begin
            if(score_actual[head*25+token/8][16*(token%8)+:16] !=
               (token<193 ? 16'h4100 : 16'h0000))
                $fatal(1,"N tile score head=%d token=%d got=%h",head,token,
                    score_actual[head*25+token/8][16*(token%8)+:16]);
        end
        launch(8,192,1,193);
        if(context_writes!=72)$fatal(1,"K tile context writes");
        for(int i=0;i<72;i++)
            if(context_actual[i] != 128'h3f803f803f803f803f803f803f803f80)
                $fatal(1,"K tile context word=%d got=%h",i,context_actual[i]);
        $display("PASS attention tile boundary N=193 K=193");
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
        repeat(5)@(negedge clk);resetn=1;
        run_case("prefill_first",0,0,32,0,0,1);
        run_case("prefill_last",1,31,32,31*72,31*36,1);
        run_case("decode1",2,32,33,0,0,1);
        run_case("prefill_full",0,0,32,0,0,32);
        run_tile_boundary();
        $display("PASS smollm2_gemm_attention_modes");$finish;
    end
    initial begin #500000000;$fatal(1,"attention GEMM timeout");end
endmodule
