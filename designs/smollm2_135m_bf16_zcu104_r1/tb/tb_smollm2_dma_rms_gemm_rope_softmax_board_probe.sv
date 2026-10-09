`timescale 1ns/1ps
module tb_smollm2_dma_rms_gemm_rope_softmax_board_probe;
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
    logic [127:0] weight_words [0:13823];
    logic [127:0] prefill_coeff_words [0:255];
    logic [127:0] decode_coeff_words [0:7];
    logic [127:0] prefill_score_words [0:1151], prefill_prob_words [0:1151];
    logic [127:0] decode_score_words [0:44], decode_prob_words [0:44];
    logic [15:0] prefill_q_first16 [0:511], prefill_k_first16 [0:511];
    logic [15:0] decode_q_first16 [0:15], decode_k_first16 [0:15];
    logic [127:0] expected_words [0:2303];
    logic [127:0] decode_expected_words [0:71];
    logic seq = 0;
    smollm2_dma_gemm_board_probe #(.REAL_RMS(1'b1), .REAL_ROPE(1'b1), .REAL_SOFTMAX(1'b1), .PROBE_SCORE(1'b1)) dut (.*);

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
                2: value = weight_words[i];
                3: value = decode_words[i];
                4: value = prefill_coeff_words[i];
                5: value = decode_coeff_words[i];
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
    task automatic run_case(input int rows);
        logic [31:0] status;
        logic [127:0] gemm_record;
        int mismatches;
        begin
            for (int i = 0; i < 3; i++) begin
                gemm_record = (128'(16'h3234) << 112) |
                    (128'(i*192) << 47) | (128'(576) << 31) |
                    (128'(rows) << 19) | (128'(576) << 8) | 128'(192);
                write_record(4+i, gemm_record);
            end
            gemm_record = (128'(16'h3235) << 112) |
                (128'(192) << 31) | (128'(rows) << 19) |
                (128'(576) << 8) | 128'(192);
            write_record(0, dma_load(0, rows*1152, 'h1000));
            write_record(1, dma_load(3, 1152, 'h2000));
            write_record(2, (128'(16'h4032) << 112) | 128'(rows));
            write_record(3, dma_load(3, 221184, 'h3000));
            write_record(7, gemm_record);
            write_record(8, dma_load(7, rows*128, 'h4000));
            write_record(9, (128'(16'h5470) << 112) | 128'(rows));
            write_record(10, (128'(16'h5570) << 112) | 128'(rows));
            write_record(11, dma_load(8, (rows == 1 ? 33 : 32)*384, 'h5000));
            write_record(12, (128'(16'h648a) << 112) |
                (128'(rows == 1 ? 32 : 0) << 17) |
                (128'(rows) << 11) | 128'(rows == 1 ? 33 : 32));
            write_record(13, (128'(16'h7a00) << 112) |
                (128'(rows == 1 ? 32 : 0) << 17) |
                (128'(rows) << 11) | 128'(rows == 1 ? 33 : 32));
            write_record(14, '0);
            fork
                begin
                    host_op(2, 0, 0, '0, status);
                    wait (host_status[29]);
                    for (int i = 0; i < (rows == 1 ? 45 : 1152); i++)
                        host_op(3, 10, i,
                                rows == 1 ? decode_score_words[i] :
                                            prefill_score_words[i], status);
                    host_op(4, 10, 0, '0, status);
                    wait (host_status[27]);
                    if (host_status[28]) $fatal(1, "dispatcher error");
                    host_op(6, 4, 0, '0, status);
                    if (status[15:0] != rows*72) $fatal(1, "Q writes=%0d", status[15:0]);
                    host_op(6, 5, 0, '0, status);
                    if (status[15:0] != rows*24) $fatal(1, "K writes=%0d", status[15:0]);
                    host_op(6, 10, 0, '0, status);
                    if (status[15:0] != rows*9*(rows == 1 ? 5 : 4))
                        $fatal(1, "Softmax writes=%0d", status[15:0]);
                    mismatches = 0;
                    for (int row = 0; row < rows; row++) begin
                        for (int col = 0; col < 16; col++) begin
                            logic [15:0] expected;
                            expected = rows == 1 ? decode_q_first16[col] :
                                                   prefill_q_first16[row*16+col];
                            host_op(5, 4, row*16+col, '0, status);
                            if (ulp(status[15:0], expected) > 2) begin
                                if (mismatches < 8) $display("Q mismatch row=%0d col=%0d got=%h expected=%h", row, col, status[15:0], expected);
                                mismatches++;
                            end
                            expected = rows == 1 ? decode_k_first16[col] :
                                                   prefill_k_first16[row*16+col];
                            host_op(5, 5, row*16+col, '0, status);
                            if (ulp(status[15:0], expected) > 2) begin
                                if (mismatches < 8) $display("K mismatch row=%0d col=%0d got=%h expected=%h", row, col, status[15:0], expected);
                                mismatches++;
                            end
                        end
                    end
                    for (int row = 0; row < rows; row++) begin
                        for (int col = 0; col < 16; col++) begin
                            logic [127:0] expected_word;
                            logic [15:0] expected;
                            expected_word = rows == 1 ? decode_prob_words[col/8] :
                                prefill_prob_words[row*36 + col/8];
                            expected = expected_word[16*(col%8) +: 16];
                            host_op(5, 10, row*16+col, '0, status);
                            if (ulp(status[15:0], expected) > 2) begin
                                if (mismatches < 8) $display("Softmax mismatch row=%0d col=%0d got=%h expected=%h", row, col, status[15:0], expected);
                                mismatches++;
                            end
                        end
                    end
                    if (mismatches) $fatal(1, "rows=%0d mismatches=%0d", rows, mismatches);
                    $display("PASS DMA_LOAD RMSNORM GEMM ROPE SOFTMAX rows=%0d", rows);
                end
                begin
                    service_load('h1000, rows*72, rows == 1 ? 3 : 0);
                    service_load('h2000, 72, 1);
                    service_load('h3000, 13824, 2);
                    service_load('h4000, rows*8, rows == 1 ? 5 : 4);
                    service_load('h5000, (rows == 1 ? 33 : 32)*24, 6);
                end
            join
        end
    endtask
    initial begin
        $readmemh("vectors/prefill_input_words.hex", input_words);
        $readmemh("vectors/decode_input_words.hex", decode_words);
        $readmemh("vectors/gamma_words.hex", gamma_words);
        $readmemh("vectors/onehot192_words.hex", weight_words);
        $readmemh("vectors/prefill_coeff_words.hex", prefill_coeff_words);
        $readmemh("vectors/decode_coeff_words.hex", decode_coeff_words);
        $readmemh("vectors/prefill32_score_words.hex", prefill_score_words);
        $readmemh("vectors/prefill32_expected_words.hex", prefill_prob_words);
        $readmemh("vectors/decode1_score_words.hex", decode_score_words);
        $readmemh("vectors/decode1_expected_words.hex", decode_prob_words);
        $readmemh("vectors/prefill_q_first16.hex", prefill_q_first16);
        $readmemh("vectors/prefill_k_first16.hex", prefill_k_first16);
        $readmemh("vectors/decode_q_first16.hex", decode_q_first16);
        $readmemh("vectors/decode_k_first16.hex", decode_k_first16);
        repeat (4) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        run_case(1);
        run_case(32);
        $display("PASS smollm2_dma_rms_gemm_rope_softmax_board_probe");
        $finish;
    end
    initial begin
        #100000000;
        $fatal(1, "RMS+GEMM+ROPE integration timeout status=%h pc=%0d", host_status, dut.current_pc);
    end
endmodule
