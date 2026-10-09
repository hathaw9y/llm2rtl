`timescale 1ns/1ps

// Bounded DDR DMA_LOAD -> test-only B2 fill -> GEMM checkpoint.
// A result tap records only accepted PL GEMM writes for PS comparison.
module smollm2_dma_gemm_board_probe #(
    parameter int DMA_DATA_WIDTH = 64,
    parameter bit ENABLE_PROFILE = 1'b0,
    parameter bit REAL_RMS = 1'b0,
    parameter bit REAL_ROPE = 1'b0,
    parameter bit REAL_SOFTMAX = 1'b0,
    parameter bit PROBE_SCORE = 1'b0,
    parameter bit REAL_ATTENTION = 1'b0,
    parameter bit REAL_ADD = 1'b0,
    parameter bit REAL_SILU = 1'b0,
    parameter bit FULL_LAYER_PROBE = 1'b0,
    parameter bit FULL_OUTPUT_TAP = 1'b0,
    parameter bit FULL_STAGE_TAPS = 1'b0,
    parameter bit FULL_FFN_TAP = 1'b0,
    parameter bit ENABLE_S2MM = 1'b0
) (
    input  logic aclk, aresetn,
    input  logic [31:0] host_data0, host_data1, host_data2, host_data3,
    input  logic [31:0] host_control,
    output logic [31:0] host_status,
    output logic [71:0] m_axis_mm2s_cmd_tdata,
    output logic m_axis_mm2s_cmd_tvalid,
    input  logic m_axis_mm2s_cmd_tready,
    input  logic [DMA_DATA_WIDTH-1:0] s_axis_mm2s_tdata,
    input  logic [DMA_DATA_WIDTH/8-1:0] s_axis_mm2s_tkeep,
    input  logic s_axis_mm2s_tvalid,
    output logic s_axis_mm2s_tready,
    input  logic s_axis_mm2s_tlast,
    input  logic [7:0] s_axis_mm2s_sts_tdata,
    input  logic s_axis_mm2s_sts_tkeep,
    input  logic s_axis_mm2s_sts_tvalid,
    output logic s_axis_mm2s_sts_tready,
    input  logic s_axis_mm2s_sts_tlast,
    input  logic datamover_mm2s_err,
    output logic [71:0] m_axis_s2mm_cmd_tdata,
    output logic m_axis_s2mm_cmd_tvalid,
    input  logic m_axis_s2mm_cmd_tready,
    output logic [DMA_DATA_WIDTH-1:0] m_axis_s2mm_tdata,
    output logic [DMA_DATA_WIDTH/8-1:0] m_axis_s2mm_tkeep,
    output logic m_axis_s2mm_tvalid,
    input  logic m_axis_s2mm_tready,
    output logic m_axis_s2mm_tlast,
    input  logic [7:0] s_axis_s2mm_sts_tdata,
    input  logic s_axis_s2mm_sts_tkeep,
    input  logic s_axis_s2mm_sts_tvalid,
    output logic s_axis_s2mm_sts_tready,
    input  logic s_axis_s2mm_sts_tlast,
    input  logic datamover_s2mm_err
);
    typedef enum logic [3:0] {
        HOST_IDLE, HOST_WRITE_CMD, HOST_START, HOST_SEND_B2,
        HOST_SEND_DONE, HOST_READ, HOST_READ_CAPTURE, HOST_ACK
    } host_state_t;
    host_state_t host_state_r;
    logic seq_seen_r, ack_seq_r, host_error_r;
    logic [3:0] host_bank_r;
    logic [15:0] host_addr_r, result_r;
    logic [127:0] host_data_r;
    logic cmd_dispatcher_start, probe_active_r;
    logic cmd_dispatcher_busy, cmd_dispatcher_done, cmd_dispatcher_error;
    logic [7:0] cmd_dispatcher_error_code;
    logic [18:0] profile_events;
    logic [15:0] profile_read_value;
    logic [9:0] current_pc, cmd_addrb;
    logic cmd_enb;
    logic [127:0] cmd_doutb;
    (* ram_style = "block" *) logic [127:0] command_bram [0:15];
    always_ff @(posedge aclk) begin
        if (host_state_r == HOST_WRITE_CMD)
            command_bram[host_addr_r[3:0]] <= host_data_r;
        if (cmd_enb) cmd_doutb <= command_bram[cmd_addrb[3:0]];
    end

    logic [0:12] bank_busy;
    logic [0:12][4:0] bank_owner_port;
    logic [12:0] bank_tensor_valid;
    logic [12:0][15:0] tensor_progress;
    logic [12:0] write_pending;
    logic bank_tensor_state_error, subsystem_error, ownership_error;
    logic [1:0] subsystem_error_code;
    logic [2:0] ownership_error_code, router_error_code, bridge_fault_code;
    logic router_error, bridge_fault, external_role_fault;
    logic [4:0] router_error_role;
    logic [3:0] router_error_bank, bridge_fault_bank;
    logic system_recovery_required;
    logic gemm_write_accepted;
    logic [3:0] gemm_write_bank;
    logic [15:0] gemm_write_addr, gemm_write_strb;
    logic [127:0] gemm_write_data;
    logic rms_write_accepted;
    logic [3:0] rms_write_bank;
    logic [15:0] rms_write_addr;
    logic [127:0] rms_write_data;
    logic rope_write_accepted;
    logic [3:0] rope_write_bank;
    logic [15:0] rope_write_addr;
    logic [127:0] rope_write_data;
    logic softmax_write_accepted;
    logic [3:0] softmax_write_bank;
    logic [15:0] softmax_write_addr;
    logic [127:0] softmax_write_data;
    logic score_write_accepted, value_write_accepted;
    logic [15:0] score_write_addr, value_write_addr;
    logic [15:0] score_write_strb, value_write_strb;
    logic [127:0] score_write_data, value_write_data;
    logic add_write_accepted;
    logic [3:0] add_write_bank;
    logic [15:0] add_write_addr;
    logic [127:0] add_write_data;
    logic [15:0] add_write_count_r;
    logic [4:0] add_tap_row_r;
    logic [6:0] add_tap_word_r;
    (* ram_style = "block" *) logic [127:0] add_result_tap [0:63];
    logic [127:0] full_output_tap_read_data;
    logic [127:0] stage_b1_tap_read_data, stage_b5_tap_read_data;
    logic [15:0] gemm_b1_write_count_r;
    logic [3:0] ffn_tap_bank_r;
    logic [15:0] ffn_tap_write_count_r;
    logic [127:0] ffn_tap_read_data;
    logic ffn_tap_write_enable;
    logic [12:0] ffn_tap_write_address;
    logic [15:0] ffn_tap_write_strb;
    logic [127:0] ffn_tap_write_data;
    logic ffn_tap_read_request;
    assign ffn_tap_read_request = FULL_FFN_TAP &&
        host_bank_r == ffn_tap_bank_r &&
        (host_bank_r == 4'd2 || host_bank_r == 4'd8 ||
         host_bank_r == 4'd9 || host_bank_r == 4'd10);
    always_comb begin
        ffn_tap_write_enable = 1'b0;
        ffn_tap_write_address = '0;
        ffn_tap_write_strb = '0;
        ffn_tap_write_data = '0;
        if (FULL_FFN_TAP) begin
            if (ffn_tap_bank_r == 4'd2 && rms_write_accepted &&
                rms_write_bank == 4'd2 && rms_write_addr < 16'd2304) begin
                ffn_tap_write_enable = 1'b1;
                ffn_tap_write_address = rms_write_addr[12:0];
                ffn_tap_write_strb = 16'hffff;
                ffn_tap_write_data = rms_write_data;
            end else if ((ffn_tap_bank_r == 4'd8 || ffn_tap_bank_r == 4'd9) &&
                gemm_write_accepted && gemm_write_bank == ffn_tap_bank_r &&
                gemm_write_addr < 16'd6144) begin
                ffn_tap_write_enable = 1'b1;
                ffn_tap_write_address = gemm_write_addr[12:0];
                ffn_tap_write_strb = gemm_write_strb;
                ffn_tap_write_data = gemm_write_data;
            end else if (ffn_tap_bank_r == 4'd10 && silu_write_accepted &&
                silu_write_bank == 4'd10 && silu_write_addr < 16'd6144) begin
                ffn_tap_write_enable = 1'b1;
                ffn_tap_write_address = silu_write_addr[12:0];
                ffn_tap_write_strb = 16'hffff;
                ffn_tap_write_data = silu_write_data;
            end
        end
    end
    if (FULL_FFN_TAP) begin : g_full_ffn_tap
        smollm2_full_ffn_tap tap (
            .clk(aclk), .write_enable(ffn_tap_write_enable),
            .write_address(ffn_tap_write_address),
            .write_strb(ffn_tap_write_strb), .write_data(ffn_tap_write_data),
            .read_enable(host_state_r == HOST_READ && ffn_tap_read_request),
            .read_address(host_addr_r[15:3]), .read_data(ffn_tap_read_data)
        );
    end else begin : g_no_full_ffn_tap
        assign ffn_tap_read_data = '0;
    end
    if (FULL_OUTPUT_TAP) begin : g_full_output_tap
        smollm2_full_output_tap full_output_tap (
            .clk(aclk),
            .write_enable(REAL_ADD && add_write_accepted && add_write_bank == 4'd0 &&
                          add_write_addr < 16'd2304),
            .write_address(add_write_addr[11:0]),
            .write_data(add_write_data),
            .read_enable(host_state_r == HOST_READ && host_bank_r == 4'd0),
            .read_address(host_addr_r[14:3]),
            .read_data(full_output_tap_read_data)
        );
    end else begin : g_no_full_output_tap
        assign full_output_tap_read_data = '0;
    end
    if (FULL_STAGE_TAPS) begin : g_full_stage_taps
        smollm2_full_gemm_tap b1_down_projection_tap (
            .clk(aclk),
            .write_enable(gemm_write_accepted && gemm_write_bank == 4'd1 &&
                          gemm_write_addr < 16'd2304),
            .write_address(gemm_write_addr[11:0]),
            .write_strb(gemm_write_strb),
            .write_data(gemm_write_data),
            .read_enable(host_state_r == HOST_READ && host_bank_r == 4'd1),
            .read_address(host_addr_r[14:3]),
            .read_data(stage_b1_tap_read_data)
        );
        smollm2_full_output_tap b5_attention_residual_tap (
            .clk(aclk),
            .write_enable(REAL_ADD && add_write_accepted && add_write_bank == 4'd5 &&
                          add_write_addr < 16'd2304),
            .write_address(add_write_addr[11:0]),
            .write_data(add_write_data),
            .read_enable(host_state_r == HOST_READ && host_bank_r == 4'd5),
            .read_address(host_addr_r[14:3]),
            .read_data(stage_b5_tap_read_data)
        );
    end else begin : g_no_full_stage_taps
        assign stage_b1_tap_read_data = '0;
        assign stage_b5_tap_read_data = '0;
    end
    logic silu_write_accepted;
    logic [3:0] silu_write_bank;
    logic [15:0] silu_write_addr;
    logic [127:0] silu_write_data;
    logic [15:0] silu_write_count_r;
    logic [4:0] silu_tap_row_r;
    logic [7:0] silu_tap_word_r;
    (* ram_style = "block" *) logic [127:0] silu_result_tap [0:63];
    logic [15:0] score_write_count_r, value_write_count_r;
    logic score_tap_match_w, value_tap_match_w;
    logic [5:0] score_tap_index_w, value_tap_index_w;
    logic [7:0] score_head_words_r, score_word_r;
    logic [3:0] score_head_r, value_head_r;
    logic [4:0] score_row_r, value_row_r;
    logic [2:0] value_word_r;
    (* ram_style = "block" *) logic [127:0] score_result_tap [0:63];
    (* ram_style = "block" *) logic [127:0] value_result_tap [0:63];

    always_comb begin
        score_tap_match_w = 1'b0;
        value_tap_match_w = 1'b0;
        score_tap_index_w = '0;
        value_tap_index_w = '0;
        for (int row=0; row<32; row++) begin
            if (score_write_addr == 16'(row*9*32'(score_head_words_r))) begin
                score_tap_match_w = 1'b1;
                score_tap_index_w = 6'(row*2);
            end else if (score_write_addr ==
                         16'(row*9*32'(score_head_words_r)+1)) begin
                score_tap_match_w = 1'b1;
                score_tap_index_w = 6'(row*2+1);
            end
            if (value_write_addr == 16'(row*72)) begin
                value_tap_match_w = 1'b1;
                value_tap_index_w = 6'(row*2);
            end else if (value_write_addr == 16'(row*72+1)) begin
                value_tap_match_w = 1'b1;
                value_tap_index_w = 6'(row*2+1);
            end
        end
    end
    logic [15:0] softmax_write_count_r;
    logic [7:0] softmax_head_words_r, softmax_word_r;
    logic [3:0] softmax_head_r;
    logic [4:0] softmax_row_r;
    (* ram_style = "block" *) logic [127:0] softmax_result_tap [0:63];
    logic [15:0] rope_q_write_count_r, rope_k_write_count_r;
    logic [4:0] rope_q_row_r, rope_k_row_r;
    logic [6:0] rope_q_word_r;
    logic [4:0] rope_k_word_r;
    (* ram_style = "block" *) logic [127:0] rope_q_result_tap [0:63];
    (* ram_style = "block" *) logic [127:0] rope_k_result_tap [0:63];
    logic [2:0] tap_lane_w;
    logic tap_lane_valid_w;
    logic [15:0] tap_index_w, tap_value_w;
    logic [15:0] tap_write_count_r;
    logic [15:0] rms_write_count_r;
    logic [4:0] rms_tap_row_r;
    logic [6:0] rms_tap_word_r;
    logic probe_cmd_valid, probe_cmd_ready, probe_done_valid;
    logic probe_done_ready, probe_write_valid, probe_write_ready;
    logic [15:0] probe_write_addr;
    logic [127:0] probe_write_data;
    (* ram_style = "block" *) logic [15:0] result_tap [0:511];
    (* ram_style = "block" *) logic [127:0] rms_result_tap [0:63];

    smollm2_gemm_dma_fabric_wide #(
        .DMA_DATA_WIDTH(DMA_DATA_WIDTH),
        .REAL_RMS(REAL_RMS), .REAL_ROPE(REAL_ROPE),
        .REAL_SOFTMAX(REAL_SOFTMAX), .PROBE_SCORE(PROBE_SCORE),
        .REAL_ATTENTION(REAL_ATTENTION), .REAL_ADD(REAL_ADD),
        .REAL_SILU(REAL_SILU)
    ) fabric (
        .m_axis_s2mm_cmd_tready(ENABLE_S2MM ? m_axis_s2mm_cmd_tready : 1'b0),
        .m_axis_s2mm_tready(ENABLE_S2MM ? m_axis_s2mm_tready : 1'b0),
        .s_axis_s2mm_sts_tdata(ENABLE_S2MM ? s_axis_s2mm_sts_tdata : 8'd0),
        .s_axis_s2mm_sts_tkeep(ENABLE_S2MM ? s_axis_s2mm_sts_tkeep : 1'b0),
        .s_axis_s2mm_sts_tvalid(ENABLE_S2MM ? s_axis_s2mm_sts_tvalid : 1'b0),
        .s_axis_s2mm_sts_tlast(ENABLE_S2MM ? s_axis_s2mm_sts_tlast : 1'b0),
        .*
    );
    generate if (ENABLE_PROFILE) begin : profiling
        smollm2_perf_counters #(.DMA_DATA_WIDTH(DMA_DATA_WIDTH)) counters (
            .aclk(aclk), .aresetn(aresetn), .clear(cmd_dispatcher_start),
            .events(profile_events),
            .load_valid(s_axis_mm2s_tvalid), .load_ready(s_axis_mm2s_tready),
            .load_keep(s_axis_mm2s_tkeep),
            .store_valid(m_axis_s2mm_tvalid), .store_ready(m_axis_s2mm_tready),
            .store_keep(m_axis_s2mm_tkeep),
            .read_index(host_control[6:0]), .read_value(profile_read_value)
        );
    end else begin : no_profiling
        assign profile_read_value = '0;
    end endgenerate
    assign cmd_dispatcher_start = host_state_r == HOST_START;
    assign probe_cmd_ready = !probe_active_r;
    assign probe_done_valid = host_state_r == HOST_SEND_DONE;
    assign probe_write_valid = host_state_r == HOST_SEND_B2;
    assign probe_write_addr = host_addr_r;
    assign probe_write_data = host_data_r;
    assign host_status = {ack_seq_r, (host_state_r != HOST_IDLE),
                          probe_active_r,
                          (host_error_r || datamover_mm2s_err ||
                           (ENABLE_S2MM && datamover_s2mm_err) ||
                           system_recovery_required || cmd_dispatcher_error),
                          cmd_dispatcher_done, bank_tensor_valid[3],
                          bank_tensor_valid[2], cmd_dispatcher_busy,
                          8'd0, result_r};

    always_comb begin
        tap_lane_w = '0;
        tap_lane_valid_w = 1'b0;
        for (int lane = 0; lane < 8; lane++) begin
            if (gemm_write_strb[2*lane +: 2] == 2'b11) begin
                tap_lane_w = 3'(lane);
                tap_lane_valid_w = 1'b1;
            end
        end
        tap_index_w = (gemm_write_addr << 3) + 16'(tap_lane_w);
        tap_value_w = gemm_write_data[16*tap_lane_w +: 16];
    end
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            host_state_r <= HOST_IDLE;
            seq_seen_r <= 1'b0; ack_seq_r <= 1'b0;
            host_error_r <= 1'b0; host_bank_r <= '0;
            host_addr_r <= '0; host_data_r <= '0;
            result_r <= '0; tap_write_count_r <= '0;
            gemm_b1_write_count_r <= '0;
            ffn_tap_bank_r <= 4'd15;
            ffn_tap_write_count_r <= '0;
            rms_write_count_r <= '0;
            rms_tap_row_r <= '0; rms_tap_word_r <= '0;
            rope_q_write_count_r <= '0; rope_k_write_count_r <= '0;
            rope_q_row_r <= '0; rope_k_row_r <= '0;
            rope_q_word_r <= '0; rope_k_word_r <= '0;
            softmax_write_count_r <= '0; softmax_head_words_r <= '0;
            softmax_word_r <= '0; softmax_head_r <= '0; softmax_row_r <= '0;
            score_write_count_r <= '0; value_write_count_r <= '0;
            add_write_count_r <= '0;
            add_tap_row_r <= '0; add_tap_word_r <= '0;
            silu_write_count_r <= '0;
            silu_tap_row_r <= '0; silu_tap_word_r <= '0;
            score_head_words_r <= '0; score_word_r <= '0;
            score_head_r <= '0; score_row_r <= '0;
            value_word_r <= '0; value_head_r <= '0; value_row_r <= '0;
            probe_active_r <= 1'b0;
        end else begin
            if (probe_cmd_valid && probe_cmd_ready)
                probe_active_r <= 1'b1;
            if (gemm_write_accepted && !REAL_ROPE) begin
                if (gemm_write_bank != 4'd4 || !tap_lane_valid_w ||
                    tap_index_w >= 16'd512)
                    host_error_r <= 1'b1;
                else begin
                    result_tap[tap_index_w[8:0]] <= tap_value_w;
                    tap_write_count_r <= tap_write_count_r + 1'b1;
                end
            end
            if (FULL_STAGE_TAPS && gemm_write_accepted &&
                gemm_write_bank == 4'd1)
                gemm_b1_write_count_r <= gemm_b1_write_count_r + 1'b1;
            if (REAL_ROPE && rope_write_accepted) begin
                if (rope_write_bank == 4'd4) begin
                    if (rope_write_addr !=
                        16'(32'(rope_q_row_r) * 72 +
                            32'(rope_q_word_r >> 3) * 8 +
                            32'(rope_q_word_r[2:1]) +
                            (rope_q_word_r[0] ? 4 : 0)))
                        host_error_r <= 1'b1;
                    if (rope_q_word_r == 0)
                        rope_q_result_tap[{rope_q_row_r, 1'b0}] <= rope_write_data;
                    if (rope_q_word_r == 2)
                        rope_q_result_tap[{rope_q_row_r, 1'b1}] <= rope_write_data;
                    rope_q_write_count_r <= rope_q_write_count_r + 1'b1;
                    if (rope_q_word_r == 7'd71) begin
                        rope_q_word_r <= '0; rope_q_row_r <= rope_q_row_r + 1'b1;
                    end else rope_q_word_r <= rope_q_word_r + 1'b1;
                end else if (rope_write_bank == 4'd5 ||
                             (FULL_LAYER_PROBE && rope_write_bank == 4'd8)) begin
                    if (rope_write_addr !=
                        16'(32'(rope_k_row_r) * 24 +
                            32'(rope_k_word_r >> 3) * 8 +
                            32'(rope_k_word_r[2:1]) +
                            (rope_k_word_r[0] ? 4 : 0)))
                        host_error_r <= 1'b1;
                    if (rope_k_word_r == 0)
                        rope_k_result_tap[{rope_k_row_r, 1'b0}] <= rope_write_data;
                    if (rope_k_word_r == 2)
                        rope_k_result_tap[{rope_k_row_r, 1'b1}] <= rope_write_data;
                    rope_k_write_count_r <= rope_k_write_count_r + 1'b1;
                    if (rope_k_word_r == 5'd23) begin
                        rope_k_word_r <= '0; rope_k_row_r <= rope_k_row_r + 1'b1;
                    end else rope_k_word_r <= rope_k_word_r + 1'b1;
                end else host_error_r <= 1'b1;
            end
            if (REAL_SOFTMAX && softmax_write_accepted) begin
                if (softmax_write_bank != 4'd10 ||
                    softmax_write_addr != softmax_write_count_r ||
                    softmax_head_words_r == 0)
                    host_error_r <= 1'b1;
                else begin
                    if (softmax_head_r == 0 && softmax_word_r < 2)
                        softmax_result_tap[{softmax_row_r, softmax_word_r[0]}]
                            <= softmax_write_data;
                    softmax_write_count_r <= softmax_write_count_r + 1'b1;
                    if (softmax_word_r + 1'b1 == softmax_head_words_r) begin
                        softmax_word_r <= '0;
                        if (softmax_head_r == 4'd8) begin
                            softmax_head_r <= '0;
                            softmax_row_r <= softmax_row_r + 1'b1;
                        end else softmax_head_r <= softmax_head_r + 1'b1;
                    end else softmax_word_r <= softmax_word_r + 1'b1;
                end
            end
            if (REAL_ATTENTION && score_write_accepted) begin
                if (score_head_words_r == 0) host_error_r <= 1'b1;
                else begin
                    if (score_tap_match_w)
                        for (int lane=0; lane<8; lane++)
                            if (score_write_strb[2*lane +: 2] == 2'b11)
                                score_result_tap[score_tap_index_w]
                                    [16*lane +: 16] <= score_write_data[16*lane +: 16];
                    if (score_write_strb[15:14] == 2'b11)
                        score_write_count_r <= score_write_count_r + 1'b1;
                end
            end
            if (REAL_ATTENTION && value_write_accepted) begin
                if (value_tap_match_w)
                    for (int lane=0; lane<8; lane++)
                        if (value_write_strb[2*lane +: 2] == 2'b11)
                            value_result_tap[value_tap_index_w]
                                [16*lane +: 16] <= value_write_data[16*lane +: 16];
                if (value_write_strb[15:14] == 2'b11)
                    value_write_count_r <= value_write_count_r + 1'b1;
            end
            if (REAL_ADD && add_write_accepted) begin
                if ((add_write_bank != 4'd5 &&
                     !(FULL_LAYER_PROBE && add_write_bank == 4'd0)) ||
                    add_write_addr != add_write_count_r ||
                    add_write_addr >= 16'd2304)
                    host_error_r <= 1'b1;
                else begin
                    if ((!FULL_OUTPUT_TAP || add_write_bank != 4'd0) &&
                        add_tap_word_r < 2)
                        add_result_tap[{add_tap_row_r, add_tap_word_r[0]}]
                            <= add_write_data;
                    add_write_count_r <= add_write_count_r + 1'b1;
                    if (add_tap_word_r == 7'd71) begin
                        add_tap_word_r <= '0;
                        add_tap_row_r <= add_tap_row_r + 1'b1;
                    end else add_tap_word_r <= add_tap_word_r + 1'b1;
                end
            end
            if (REAL_SILU && silu_write_accepted) begin
                if (silu_write_bank != 4'd10 ||
                    silu_write_addr != silu_write_count_r ||
                    silu_write_addr >= 16'd6144)
                    host_error_r <= 1'b1;
                else begin
                    if (silu_tap_word_r < 2)
                        silu_result_tap[{silu_tap_row_r, silu_tap_word_r[0]}]
                            <= silu_write_data;
                    silu_write_count_r <= silu_write_count_r + 1'b1;
                    if (silu_tap_word_r == 8'd191) begin
                        silu_tap_word_r <= '0;
                        silu_tap_row_r <= silu_tap_row_r + 1'b1;
                    end else silu_tap_word_r <= silu_tap_word_r + 1'b1;
                end
            end
            if (REAL_RMS && rms_write_accepted) begin
                if (rms_write_bank != 4'd2 || rms_write_addr != rms_write_count_r ||
                    rms_write_addr >= 16'd2304)
                    host_error_r <= 1'b1;
                else begin
                    if (rms_tap_word_r < 7'd2)
                        rms_result_tap[{rms_tap_row_r, rms_tap_word_r[0]}]
                            <= rms_write_data;
                    rms_write_count_r <= rms_write_count_r + 1'b1;
                    if (rms_tap_word_r == 7'd71) begin
                        rms_tap_word_r <= '0;
                        rms_tap_row_r <= rms_tap_row_r + 1'b1;
                    end else rms_tap_word_r <= rms_tap_word_r + 1'b1;
                end
            end
            if (ffn_tap_write_enable)
                ffn_tap_write_count_r <= ffn_tap_write_count_r + 1'b1;
            case (host_state_r)
                HOST_IDLE: if (host_control[31] != seq_seen_r) begin
                    seq_seen_r <= host_control[31];
                    host_bank_r <= host_control[27:24];
                    host_addr_r <= host_control[15:0];
                    host_data_r <= {host_data3, host_data2,
                                    host_data1, host_data0};
                    case (host_control[30:28])
                        3'd1: if (!cmd_dispatcher_busy && !probe_active_r &&
                                    host_control[15:0] < 16)
                            host_state_r <= HOST_WRITE_CMD;
                        else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        3'd2: if (!cmd_dispatcher_busy && !probe_active_r) begin
                            host_error_r <= 0;
                            tap_write_count_r <= '0;
                            gemm_b1_write_count_r <= '0;
                            rms_write_count_r <= '0;
                            rms_tap_row_r <= '0; rms_tap_word_r <= '0;
                            rope_q_write_count_r <= '0;
                            rope_k_write_count_r <= '0;
                            rope_q_row_r <= '0; rope_k_row_r <= '0;
                            rope_q_word_r <= '0; rope_k_word_r <= '0;
                            softmax_write_count_r <= '0;
                            softmax_word_r <= '0;
                            softmax_head_r <= '0; softmax_row_r <= '0;
                            score_write_count_r <= '0; value_write_count_r <= '0;
                            add_write_count_r <= '0;
                            add_tap_row_r <= '0; add_tap_word_r <= '0;
                            silu_write_count_r <= '0;
                            silu_tap_row_r <= '0; silu_tap_word_r <= '0;
                            score_word_r <= '0; score_head_r <= '0;
                            score_row_r <= '0; value_word_r <= '0;
                            value_head_r <= '0; value_row_r <= '0;
                            host_state_r <= HOST_START;
                        end else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        3'd3: if (probe_active_r &&
                                    ((!PROBE_SCORE &&
                                      host_control[27:24] == 4'd2 &&
                                      host_control[15:0] < 16'd2304) ||
                                     (PROBE_SCORE &&
                                      host_control[27:24] == 4'd10 &&
                                      host_control[15:0] < 16'd36864)))
                            host_state_r <= HOST_SEND_B2;
                        else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        3'd4: if (probe_active_r) host_state_r <= HOST_SEND_DONE;
                        else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        3'd5: if (cmd_dispatcher_done &&
                                    ((FULL_FFN_TAP &&
                                      host_control[27:24] == ffn_tap_bank_r &&
                                      ((host_control[27:24] == 4'd2 &&
                                        host_control[15:0] < 16'd18432) ||
                                       ((host_control[27:24] == 4'd8 ||
                                         host_control[27:24] == 4'd9 ||
                                         host_control[27:24] == 4'd10) &&
                                        host_control[15:0] < 16'd49152))) ||
                                     (FULL_STAGE_TAPS &&
                                      (host_control[27:24] == 4'd1 ||
                                       host_control[27:24] == 4'd5) &&
                                      host_control[15:0] < 16'd18432) ||
                                     (REAL_ADD &&
                                      (host_control[27:24] == 4'd5 ||
                                       (FULL_LAYER_PROBE &&
                                       host_control[27:24] == 4'd0)) &&
                                      host_control[15:0] <
                                      ((FULL_OUTPUT_TAP && host_control[27:24] == 4'd0)
                                       ? 16'd18432 : 16'd512)) ||
                                     (REAL_SILU && host_control[27:24] == 4'd14 &&
                                      host_control[15:0] < 16'd512) ||
                                     (REAL_ATTENTION &&
                                      (host_control[27:24] == 4'd11 ||
                                       host_control[27:24] == 4'd13) &&
                                      host_control[15:0] < 16'd512) ||
                                     (REAL_SOFTMAX &&
                                      host_control[27:24] == 4'd10 &&
                                      host_control[15:0] < 16'd512) ||
                                     (REAL_ROPE &&
                                      (host_control[27:24] == 4'd4 ||
                                       host_control[27:24] == 4'd5 ||
                                       (FULL_LAYER_PROBE &&
                                        host_control[27:24] == 4'd8)) &&
                                      host_control[15:0] < 16'd512) ||
                                     (REAL_RMS && host_control[27:24] == 4'd2 &&
                                      host_control[15:0] < 16'd512) ||
                                     (!REAL_ROPE && host_control[27:24] == 4'd4 &&
                                      host_control[15:0] < 16'd512)))
                            host_state_r <= HOST_READ;
                        else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        3'd6: begin
                            if (FULL_FFN_TAP && host_control[27:24] == ffn_tap_bank_r)
                                result_r <= ffn_tap_write_count_r;
                            else if (FULL_STAGE_TAPS && host_control[27:24] == 4'd1)
                                result_r <= gemm_b1_write_count_r;
                            else if (REAL_SILU && host_control[27:24] == 4'd14)
                                result_r <= silu_write_count_r;
                            else if (REAL_ADD &&
                                     (host_control[27:24] == 4'd5 ||
                                      (FULL_LAYER_PROBE &&
                                       host_control[27:24] == 4'd0)))
                                result_r <= add_write_count_r;
                            else if (REAL_ATTENTION && host_control[27:24] == 4'd13)
                                result_r <= score_write_count_r;
                            else if (REAL_ATTENTION && host_control[27:24] == 4'd11)
                                result_r <= value_write_count_r;
                            else if (REAL_SOFTMAX && host_control[27:24] == 4'd10)
                                result_r <= softmax_write_count_r;
                            else if (REAL_ROPE && host_control[27:24] == 4'd4)
                                result_r <= rope_q_write_count_r;
                            else if (REAL_ROPE &&
                                     (host_control[27:24] == 4'd5 ||
                                      (FULL_LAYER_PROBE &&
                                       host_control[27:24] == 4'd8)))
                                result_r <= rope_k_write_count_r;
                            else if (REAL_RMS && host_control[27:24] == 4'd2)
                                result_r <= rms_write_count_r;
                            else result_r <= tap_write_count_r;
                            host_state_r <= HOST_ACK;
                        end
                        3'd7: if (ENABLE_PROFILE && cmd_dispatcher_done &&
                                    !cmd_dispatcher_busy && host_control[27:24] == 0 &&
                                    host_control[15:0] < 96) begin
                            result_r <= profile_read_value;
                            host_state_r <= HOST_ACK;
                        end else if (FULL_FFN_TAP && !cmd_dispatcher_busy &&
                                    !probe_active_r &&
                                    (host_control[27:24] == 4'd2 ||
                                     host_control[27:24] == 4'd8 ||
                                     host_control[27:24] == 4'd9 ||
                                     host_control[27:24] == 4'd10 ||
                                     host_control[27:24] == 4'd15)) begin
                            ffn_tap_bank_r <= host_control[27:24];
                            ffn_tap_write_count_r <= '0;
                            host_state_r <= HOST_ACK;
                        end else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        default: begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                    endcase
                end
                HOST_WRITE_CMD: begin
                    if (REAL_ATTENTION && host_data_r[127:124] == 4'd6)
                        score_head_words_r <=
                            8'((host_data_r[10:0] + 11'd7) >> 3);
                    if (REAL_SOFTMAX && host_data_r[127:124] == 4'd7)
                        softmax_head_words_r <=
                            8'((host_data_r[10:0] + 11'd7) >> 3);
                    host_state_r <= HOST_ACK;
                end
                HOST_START: host_state_r <= HOST_ACK;
                HOST_SEND_B2: if (probe_write_ready) host_state_r <= HOST_ACK;
                HOST_SEND_DONE: if (probe_done_ready) begin
                    probe_active_r <= 1'b0;
                    host_state_r <= HOST_ACK;
                end
                HOST_READ: begin
                    if (ffn_tap_read_request ||
                        (FULL_OUTPUT_TAP && host_bank_r == 4'd0) ||
                        (FULL_STAGE_TAPS &&
                         (host_bank_r == 4'd1 || host_bank_r == 4'd5)))
                        host_state_r <= HOST_READ_CAPTURE;
                    else if (REAL_SILU && host_bank_r == 4'd14)
                        result_r <= silu_result_tap[host_addr_r[8:3]]
                                                 [16*host_addr_r[2:0] +: 16];
                    else if (REAL_ADD &&
                             (host_bank_r == 4'd5 ||
                              (FULL_LAYER_PROBE && host_bank_r == 4'd0)))
                        result_r <= add_result_tap[host_addr_r[8:3]]
                                                [16*host_addr_r[2:0] +: 16];
                    else if (REAL_ATTENTION && host_bank_r == 4'd13)
                        result_r <= score_result_tap[host_addr_r[8:3]]
                                                [16*host_addr_r[2:0] +: 16];
                    else if (REAL_ATTENTION && host_bank_r == 4'd11)
                        result_r <= value_result_tap[host_addr_r[8:3]]
                                                [16*host_addr_r[2:0] +: 16];
                    else if (REAL_SOFTMAX && host_bank_r == 4'd10)
                        result_r <= softmax_result_tap[host_addr_r[8:3]]
                                                  [16*host_addr_r[2:0] +: 16];
                    else if (REAL_RMS && host_bank_r == 4'd2)
                        result_r <= rms_result_tap[host_addr_r[8:3]]
                                               [16*host_addr_r[2:0] +: 16];
                    else if (REAL_ROPE && host_bank_r == 4'd4)
                        result_r <= rope_q_result_tap[host_addr_r[8:3]]
                                                  [16*host_addr_r[2:0] +: 16];
                    else if (REAL_ROPE &&
                             (host_bank_r == 4'd5 ||
                              (FULL_LAYER_PROBE && host_bank_r == 4'd8)))
                        result_r <= rope_k_result_tap[host_addr_r[8:3]]
                                                  [16*host_addr_r[2:0] +: 16];
                    else result_r <= result_tap[host_addr_r[8:0]];
                    if (!(ffn_tap_read_request ||
                          (FULL_OUTPUT_TAP && host_bank_r == 4'd0) ||
                          (FULL_STAGE_TAPS &&
                           (host_bank_r == 4'd1 || host_bank_r == 4'd5))))
                        host_state_r <= HOST_ACK;
                end
                HOST_READ_CAPTURE: begin
                    if (ffn_tap_read_request)
                        result_r <= ffn_tap_read_data[16*host_addr_r[2:0] +: 16];
                    else if (FULL_STAGE_TAPS && host_bank_r == 4'd1)
                        result_r <= stage_b1_tap_read_data[16*host_addr_r[2:0] +: 16];
                    else if (FULL_STAGE_TAPS && host_bank_r == 4'd5)
                        result_r <= stage_b5_tap_read_data[16*host_addr_r[2:0] +: 16];
                    else
                        result_r <= full_output_tap_read_data[16*host_addr_r[2:0] +: 16];
                    host_state_r <= HOST_ACK;
                end
                HOST_ACK: begin ack_seq_r <= seq_seen_r; host_state_r <= HOST_IDLE; end
                default: host_state_r <= HOST_IDLE;
            endcase
        end
    end
endmodule

module smollm2_full_ffn_tap (
    input logic clk,
    input logic write_enable,
    input logic [12:0] write_address,
    input logic [15:0] write_strb,
    input logic [127:0] write_data,
    input logic read_enable,
    input logic [12:0] read_address,
    output logic [127:0] read_data
);
    for (genvar lane = 0; lane < 8; lane++) begin : g_lane
        (* ram_style = "block" *) logic [15:0] words [0:6143];
        always_ff @(posedge clk) begin
            if (write_enable && write_strb[2*lane +: 2] == 2'b11)
                words[write_address] <= write_data[16*lane +: 16];
            if (read_enable)
                read_data[16*lane +: 16] <= words[read_address];
        end
    end
endmodule

module smollm2_full_gemm_tap (
    input logic clk,
    input logic write_enable,
    input logic [11:0] write_address,
    input logic [15:0] write_strb,
    input logic [127:0] write_data,
    input logic read_enable,
    input logic [11:0] read_address,
    output logic [127:0] read_data
);
    for (genvar lane = 0; lane < 8; lane++) begin : g_lane
        (* ram_style = "block" *) logic [15:0] words [0:2303];
        always_ff @(posedge clk) begin
            if (write_enable && write_strb[2*lane +: 2] == 2'b11)
                words[write_address] <= write_data[16*lane +: 16];
            if (read_enable)
                read_data[16*lane +: 16] <= words[read_address];
        end
    end
endmodule

module smollm2_full_output_tap (
    input logic clk,
    input logic write_enable,
    input logic [11:0] write_address,
    input logic [127:0] write_data,
    input logic read_enable,
    input logic [11:0] read_address,
    output logic [127:0] read_data
);
    (* ram_style = "block" *) logic [127:0] words [0:2303];
    always_ff @(posedge clk) begin
        if (write_enable) words[write_address] <= write_data;
        if (read_enable) read_data <= words[read_address];
    end
endmodule
