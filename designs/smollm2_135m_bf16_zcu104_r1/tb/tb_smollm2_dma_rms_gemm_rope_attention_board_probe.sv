`timescale 1ns/1ps
module tb_smollm2_dma_rms_gemm_rope_attention_board_probe;
    logic aclk = 0, aresetn = 0;
    always #3.333 aclk = ~aclk;
    logic [31:0] host_data0 = 0, host_data1 = 0;
    logic [31:0] host_data2 = 0, host_data3 = 0;
    logic [31:0] host_control = 0, host_status;
    logic [71:0] m_axis_mm2s_cmd_tdata;
    logic m_axis_mm2s_cmd_tvalid, m_axis_mm2s_cmd_tready = 0;
    logic [63:0] s_axis_mm2s_tdata = 0;
    logic [7:0] s_axis_mm2s_tkeep = 0;
    logic s_axis_mm2s_tvalid = 0, s_axis_mm2s_tready;
    logic s_axis_mm2s_tlast = 0;
    logic [7:0] s_axis_mm2s_sts_tdata = 0;
    logic s_axis_mm2s_sts_tkeep = 0, s_axis_mm2s_sts_tvalid = 0;
    logic s_axis_mm2s_sts_tready, s_axis_mm2s_sts_tlast = 0;
    logic datamover_mm2s_err = 0;
    logic [127:0] input_words [0:2303];
    logic [127:0] decode_words [0:71];
    logic [127:0] gamma_words [0:71];
    logic [127:0] weight_words [0:41471];
    logic [127:0] prefill_k_words [0:767], decode_k_words [0:791];
    logic [127:0] prefill_v_words [0:767], decode_v_words [0:791];
    logic [127:0] prefill_q_words [0:2303], decode_q_words [0:71];
    logic [127:0] prefill_context_words [0:2303], decode_context_words [0:71];
    logic [127:0] identity_words [0:41471];
    logic [127:0] prefill_residual_words [0:2303], decode_residual_words [0:71];
    logic [127:0] focused_score_words [0:8], focused_prob_words [0:8];
    logic [127:0] focused_context_words [0:71];
    logic [127:0] prefill_coeff_words [0:255];
    logic [127:0] decode_coeff_words [0:7];
    logic [127:0] prefill_score_words [0:1151], prefill_prob_words [0:1151];
    logic [127:0] decode_score_words [0:44], decode_prob_words [0:44];
    logic [15:0] prefill_q_first16 [0:511], prefill_k_first16 [0:511];
    logic [15:0] decode_q_first16 [0:15], decode_k_first16 [0:15];
    logic [127:0] expected_words [0:2303];
    logic [127:0] decode_expected_words [0:71];
    logic seq = 0;
    logic decode_full_case = 0;
    smollm2_dma_gemm_board_probe #(.REAL_RMS(1'b1), .REAL_ROPE(1'b1), .REAL_SOFTMAX(1'b1), .PROBE_SCORE(1'b0), .REAL_ATTENTION(1'b1), .REAL_ADD(1'b1)) dut (.*);

    task automatic host_op(input int op, bank, addr,
                           input logic [127:0] payload,
                           output logic [31:0] status);
        @(negedge aclk);
        {host_data3, host_data2, host_data1, host_data0} = payload;
        seq = !seq;
        host_control = {seq, 3'(op), 4'(bank), 8'd0, 16'(addr)};
        do @(posedge aclk); while (host_status[31] != seq || host_status[30]);
        #1; status = host_status;
        if (status[28]) $fatal(1, "host op=%0d bank=%0d error=%h", op, bank, status);
    endtask
    task automatic write_record(input int index, input logic [127:0] value);
        logic [31:0] status;
        host_op(1, 0, index, value, status);
    endtask
    task automatic send_beat(input logic [63:0] data, input logic last);
        @(negedge aclk);
        s_axis_mm2s_tdata = data; s_axis_mm2s_tkeep = 8'hff;
        s_axis_mm2s_tlast = last; s_axis_mm2s_tvalid = 1;
        do @(posedge aclk); while (!s_axis_mm2s_tready);
        #1; s_axis_mm2s_tvalid = 0;
    endtask
    task automatic service_load(input int addr, words, source);
        logic [3:0] tag;
        logic [127:0] value;
        wait (m_axis_mm2s_cmd_tvalid);
        @(negedge aclk); m_axis_mm2s_cmd_tready = 1;
        @(posedge aclk);
        if (!m_axis_mm2s_cmd_tvalid ||
            m_axis_mm2s_cmd_tdata[63:32] != addr ||
            m_axis_mm2s_cmd_tdata[22:0] != words*16)
            $fatal(1, "DMA command addr=%h btt=%0d", m_axis_mm2s_cmd_tdata[63:32],
                   m_axis_mm2s_cmd_tdata[22:0]);
        tag = m_axis_mm2s_cmd_tdata[67:64];
        #1; m_axis_mm2s_cmd_tready = 0;
        for (int i = 0; i < words; i++) begin
            case (source)
                0: value = input_words[i];
                1: value = gamma_words[i];
                2: value = weight_words[((addr - 'h3000) / 'h1000)*13824+i];
                3: value = decode_words[i];
                4: value = prefill_coeff_words[i];
                5: value = decode_coeff_words[i];
                6: value = prefill_k_words[i];
                7: value = decode_k_words[i];
                8: value = prefill_v_words[i];
                9: value = decode_v_words[i];
                10: value = identity_words[((addr - 'h9000) / 'h1000)*13824+i];
                default: value = '0;
            endcase
            send_beat(value[63:0], 0);
            send_beat(value[127:64], i == words-1);
        end
        repeat (4) @(posedge aclk);
        @(negedge aclk);
        s_axis_mm2s_sts_tdata = {4'h8, tag};
        s_axis_mm2s_sts_tkeep = 1; s_axis_mm2s_sts_tlast = 1;
        s_axis_mm2s_sts_tvalid = 1;
        do @(posedge aclk); while (!s_axis_mm2s_sts_tready);
        #1; s_axis_mm2s_sts_tvalid = 0;
    endtask
    function automatic logic [127:0] dma_load(input int bank, bytes, addr);
        return (128'(1) << 124) | (128'(bank) << 120) |
               (128'(bytes) << 57) | (128'(addr) << 25);
    endfunction
    function automatic int ulp(input logic [15:0] actual, expected);
        int a, b;
        a = actual[15] ? 16'hffff - actual : int'(actual) + 16'h8000;
        b = expected[15] ? 16'hffff - expected : int'(expected) + 16'h8000;
        return a > b ? a-b : b-a;
    endfunction
    function automatic logic [127:0] shape(input int op, start, rows, kv);
        logic [127:0] banks;
        banks = op == 6 ? (128'(4)<<120)|(128'(8)<<116)|(128'(10)<<112) :
                op == 8 ? (128'(10)<<120)|(128'(9)<<116)|(128'(11)<<112) :
                          (128'(10)<<120);
        return (128'(op)<<124)|banks|(128'(start)<<17)|(128'(rows)<<11)|128'(kv);
    endfunction
    task automatic compare_first(input int bank, rows, writes,
                                 input int kind, tolerance);
        logic [31:0] status;
        logic [127:0] word_value;
        logic [15:0] expected;
        int errors;
        begin
            host_op(6,bank,0,'0,status);
            if (status[15:0] != writes) $fatal(1,"kind=%d writes=%d expected=%d",kind,status[15:0],writes);
            errors=0;
            for (int row=0;row<rows;row++)
            for (int col=0;col<((rows==1 && !decode_full_case &&
                                 (kind==1 || kind==2))?8:16);col++) begin
                case(kind)
                    0: word_value=rows==1 ? decode_q_words[col/8] : prefill_q_words[row*72+col/8];
                    1: word_value=rows==1 ? (decode_full_case ?
                        decode_score_words[col/8] : focused_score_words[col/8]) :
                        prefill_score_words[row*36+col/8];
                    2: word_value=rows==1 ? (decode_full_case ?
                        decode_prob_words[col/8] : focused_prob_words[col/8]) :
                        prefill_prob_words[row*36+col/8];
                    3: word_value=rows==1 ? (decode_full_case ?
                        decode_context_words[col/8] : focused_context_words[col/8]) :
                        prefill_context_words[row*72+col/8];
                    default: word_value=rows==1 ?
                        decode_residual_words[col/8] :
                        prefill_residual_words[row*72+col/8];
                endcase
                expected=word_value[16*(col%8)+:16];
                host_op(5,bank,row*16+col,'0,status);
                if (ulp(status[15:0],expected)>tolerance) begin
                    if (errors<8) $display("kind=%d row=%d col=%d got=%h expected=%h",kind,row,col,status[15:0],expected);
                    errors++;
                end
            end
            if(errors) $fatal(1,"kind=%d errors=%d",kind,errors);
            $display("PASS kind=%d rows=%d compare=%d mismatches=0",kind,rows,
                     (rows==1 && !decode_full_case && (kind==1 || kind==2))?
                     8:rows*16);
        end
    endtask
    task automatic run_case(input int rows, input bit full_decode);
        logic [31:0] status;
        logic [127:0] gemm_record;
        int kv, start, score_words;
        begin
            decode_full_case=full_decode;
            start=full_decode ? 32 : 0;
            kv=full_decode ? 33 : rows;
            score_words=rows*9*((kv+7)/8);
            write_record(0,dma_load(0,rows*1152,'h1000));
            write_record(1,dma_load(3,1152,'h2000));
            write_record(2,(128'(16'h4032)<<112)|128'(rows));
            for(int tile=0;tile<3;tile++) begin
                write_record(3+2*tile,dma_load(3,221184,'h3000+tile*'h1000));
                gemm_record=(128'(16'h3234)<<112)|
                    (128'(tile*192)<<47)|(128'(576)<<31)|
                    (128'(rows)<<19)|(128'(576)<<8)|128'(192);
                write_record(4+2*tile,gemm_record);
            end
            write_record(9,dma_load(7,rows*128,'h6000));
            write_record(10,(128'(16'h5470)<<112)|128'(rows));
            write_record(11,'0);
            fork
                begin
                    host_op(2,0,0,'0,status);
                    wait(host_status[27]);
                    if(host_status[28]) $fatal(1,"Q dispatcher error %h",host_status);
                end
                begin
                    service_load('h1000,rows*72,rows==1?3:0);
                    service_load('h2000,72,1);
                    for(int tile=0;tile<3;tile++) service_load('h3000+tile*'h1000,13824,2);
                    service_load('h6000,rows*8,rows==1?5:4);
                end
            join
            $display("Q chunk DONE rows=%d",rows);
            compare_first(4,rows,rows*72,0,8);
            write_record(0,dma_load(8,kv*384,'h7000));
            write_record(1,dma_load(9,kv*384,'h8000));
            write_record(2,shape(6,start,rows,kv));
            write_record(3,shape(7,start,rows,kv));
            write_record(4,shape(8,start,rows,kv));
            write_record(5,'0);
            $display("attention records loaded rows=%d pc=%d status=%h",rows,dut.current_pc,host_status);
            fork
                begin
                    host_op(2,0,0,'0,status);
                    wait(host_status[27]);
                    if(host_status[28]) $fatal(1,"attention dispatcher error %h",host_status);
                end
                begin
                    service_load('h7000,kv*24,rows==1?7:6);
                    service_load('h8000,kv*24,rows==1?9:8);
                end
            join
            $display("attention chunk DONE rows=%d",rows);
            compare_first(13,rows,score_words,1,16);
            compare_first(10,rows,score_words,2,16);
            compare_first(11,rows,rows*72,3,16);
            $display("PASS ATTN_SCORE SOFTMAX ATTN_VALUE rows=%d",rows);
        end
    endtask
    task automatic run_add_case(input int rows);
        logic [31:0] status;
        logic [127:0] gemm_record;
        begin
            $display("ADD records begin rows=%0d",rows);
            for (int tile=0;tile<3;tile++) begin
                write_record(tile*2,dma_load(3,221184,'h9000+tile*'h1000));
                gemm_record=(128'(16'h3b31)<<112)|
                    (128'(tile*192)<<47)|(128'(576)<<31)|
                    (128'(rows)<<19)|(128'(576)<<8)|128'(192);
                write_record(tile*2+1,gemm_record);
            end
            write_record(6,(128'(16'h9015)<<112)|128'(rows));
            write_record(7,'0);
            $display("ADD records loaded rows=%0d",rows);
            fork
                begin
                    host_op(2,0,0,'0,status);
                    wait(host_status[27]);
                    if(host_status[28]) $fatal(1,"ADD dispatcher error %h",host_status);
                end
                begin
                    for(int tile=0;tile<3;tile++)
                        service_load('h9000+tile*'h1000,13824,10);
                end
            join
            compare_first(5,rows,rows*72,4,16);
            $display("PASS GEMM identity plus ADD rows=%d",rows);
        end
    endtask
    initial begin
        $readmemh("vectors/prefill_input_words.hex",input_words);
        $readmemh("vectors/decode_input_words.hex",decode_words);
        $readmemh("vectors/gamma_words.hex",gamma_words);
        $readmemh("vectors/q_weight_tiles_words.hex",weight_words);
        $readmemh("vectors/prefill_coeff_words.hex",prefill_coeff_words);
        $readmemh("vectors/decode_coeff_words.hex",decode_coeff_words);
        $readmemh("vectors/prefill32_k_cache_words.hex",prefill_k_words);
        $readmemh("vectors/decode1_k_cache_words.hex",decode_k_words);
        $readmemh("vectors/prefill32_v_cache_words.hex",prefill_v_words);
        $readmemh("vectors/decode1_v_cache_words.hex",decode_v_words);
        $readmemh("vectors/prefill32_score_words.hex",prefill_score_words);
        $readmemh("vectors/decode1_score_words.hex",decode_score_words);
        $readmemh("vectors/prefill32_probability_words.hex",prefill_prob_words);
        $readmemh("vectors/decode1_probability_words.hex",decode_prob_words);
        $readmemh("vectors/prefill32_context_words.hex",prefill_context_words);
        $readmemh("vectors/decode1_context_words.hex",decode_context_words);
        $readmemh("vectors/prefill_residual_expected_words.hex",prefill_residual_words);
        $readmemh("vectors/decode_residual_expected_words.hex",decode_residual_words);
        for (int i=0;i<41472;i++) identity_words[i]='0;
        for (int tile=0;tile<3;tile++)
            for (int col=0;col<192;col++)
                identity_words[tile*13824+col*72+(tile*192+col)/8]
                    [16*((tile*192+col)%8)+:16]=16'h3f80;
        $readmemh("vectors/focused_score_words.hex",focused_score_words);
        $readmemh("vectors/focused_probability_words.hex",focused_prob_words);
        $readmemh("vectors/focused_context_words.hex",focused_context_words);
        $readmemh("vectors/prefill_q_expected_words.hex",prefill_q_words);
        $readmemh("vectors/decode_q_expected_words.hex",decode_q_words);
        repeat(4) @(posedge aclk);
        @(negedge aclk); aresetn=1;
        run_case(32,0);
        run_add_case(32);
        run_case(1,0);
        run_case(1,1);
        run_add_case(1);
        $display("PASS smollm2_dma_rms_gemm_rope_attention_board_probe");
        $finish;
    end
    initial begin #500000000; $fatal(1,"attention integration timeout status=%h pc=%0d",host_status,dut.current_pc); end
    logic fault_seen = 0;
    always @(posedge aclk) if (aresetn) begin
        if (host_status[28] && !fault_seen) begin
            fault_seen <= 1;
            $display("FAULT pc=%d code=%h state=%d host=%b recovery=%b tensor=%b owner=%b router=%b bridge=%b external=%b valid10=%b busy10=%b score_done=%b score_err=%b soft_ready=%b",
                     dut.current_pc,dut.cmd_dispatcher_error_code,
                     dut.fabric.fabric.dispatcher.state_r,
                     dut.host_error_r,dut.system_recovery_required,
                     dut.bank_tensor_state_error,dut.ownership_error,
                     dut.router_error,dut.bridge_fault,dut.external_role_fault,
                     dut.bank_tensor_valid[10],dut.bank_busy[10],
                     dut.fabric.score_done_valid,dut.fabric.score_done_error,
                     dut.fabric.softmax_cmd_ready);
            $fatal(1,"integration fault");
        end
    end
endmodule
