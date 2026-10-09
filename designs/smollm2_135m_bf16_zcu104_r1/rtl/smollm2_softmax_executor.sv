`timescale 1ns/1ps

// Causal row-wise softmax for B10. Layout is [row, query_head, ceil(kv_len/8)]
// with eight BF16 scores per 128-bit word. The third pass reads each score
// before overwriting its word with the BF16 probability.
module smollm2_softmax_executor (
    input  logic aclk, aresetn,
    input  logic cmd_valid,
    output logic cmd_ready,
    input  logic [3:0] cmd_opcode,
    input  logic [2:0][3:0] cmd_bank,
    input  logic [111:0] cmd_payload,
    output logic done_valid,
    input  logic done_ready,
    output logic [3:0] done_tag,
    output logic [1:0] done_bank_count,
    output logic [2:0][3:0] done_bank,
    output logic done_error,
    output logic data_read_valid,
    input  logic data_read_ready,
    output logic [3:0] data_read_bank,
    output logic [15:0] data_read_addr,
    input  logic data_rsp_valid,
    input  logic [3:0] data_rsp_bank,
    input  logic [127:0] data_rsp_data,
    output logic data_write_valid,
    input  logic data_write_ready,
    output logic [3:0] data_write_bank,
    output logic [15:0] data_write_addr,
    output logic [15:0] data_write_strb,
    output logic [127:0] data_write_data
);
    typedef enum logic [4:0] {
        IDLE, MAX_REQ, MAX_WAIT, MAX_LANE, MAX_ADV,
        SUM_REQ, SUM_WAIT, EXP_NEXT, EXP_ROM, EXP_MUL, EXP_PACK,
        SUM_ACC, SUM_ADV, DIVIDE,
        OUT_REQ, OUT_WAIT, OUT_MUL, OUT_ROUND, OUT_PACK, OUT_ADV,
        OUT_WRITE, DONE
    } state_t;
    state_t state_r;
    logic [9:0] query_start_r;
    logic [5:0] rows_r, row_r;
    logic [10:0] kv_len_r;
    logic [7:0] head_words_r, word_r;
    logic [3:0] head_r;
    logic [2:0] lane_r;
    logic [127:0] input_word_r, output_word_r;
    logic signed [31:0] max_q_r;
    logic [40:0] sum_r, remainder_r;
    logic [5:0] div_bit_r;
    logic [30:0] reciprocal_r, lut_a_r, lut_b_r, exp_r, probability_r;
    logic [41:0] div_trial_w;
    logic [61:0] product_r;
    logic [41:0] interp_product_r;
    logic [9:0] lut_index_r;
    logic [10:0] lut_fraction_r;
    logic output_pass_r, error_r;
    logic [10:0] valid_len_w, column_w;
    logic [15:0] word_addr_w, lane_bits_w;
    logic signed [31:0] lane_q_w;
    logic [32:0] delta_w;

`include "smollm2_softmax_exp_lut.svh"

    function automatic logic signed [31:0] bf16_to_q16(input logic [15:0] v);
        integer exp_value, shift;
        logic [7:0] significand;
        logic [31:0] magnitude, chopped, remainder, half;
        begin
            significand = {(v[14:7] != 0), v[6:0]};
            exp_value = v[14:7] == 0 ? 1 : int'(v[14:7]);
            shift = exp_value - 118;
            if (shift >= 24) magnitude = 32'h7fffffff;
            else if (shift >= 0) magnitude = 32'(significand) << shift;
            else if (shift <= -32) magnitude = 0;
            else begin
                chopped = 32'(significand) >> -shift;
                remainder = 32'(significand) & ((32'd1 << -shift) - 1);
                half = 32'd1 << (-shift - 1);
                magnitude = chopped +
                    ((remainder > half || (remainder == half && chopped[0])) ? 1 : 0);
            end
            if (magnitude > 32'h7fffffff) magnitude = 32'h7fffffff;
            bf16_to_q16 = v[15] ? -$signed(magnitude) : $signed(magnitude);
        end
    endfunction

    function automatic logic [15:0] q30_to_bf16(input logic [30:0] value);
        integer highest, shift, exponent;
        logic [31:0] chopped, remainder, halfway;
        logic [8:0] rounded;
        begin
            highest = -1;
            for (int i = 0; i <= 30; i++) if (value[i]) highest = i;
            if (highest < 0) q30_to_bf16 = 16'd0;
            else begin
                shift = highest - 7;
                exponent = 127 + highest - 30;
                if (shift > 0) begin
                    chopped = value >> shift;
                    remainder = value & ((31'd1 << shift) - 1);
                    halfway = 31'd1 << (shift - 1);
                    rounded = {1'b0, chopped[7:0]} +
                        ((remainder > halfway ||
                          (remainder == halfway && chopped[0])) ? 9'd1 : 9'd0);
                end else rounded = 9'(value << -shift);
                if (rounded[8]) begin
                    rounded = 9'h080;
                    exponent = exponent + 1;
                end
                q30_to_bf16 = {1'b0, 8'(exponent), rounded[6:0]};
            end
        end
    endfunction

    assign cmd_ready = state_r == IDLE;
    assign done_valid = state_r == DONE;
    assign done_tag = 4'd10;
    assign done_bank_count = 2'd1;
    assign done_bank = {8'd0, 4'd10};
    assign done_error = error_r;
    assign valid_len_w = {1'b0, query_start_r} + {5'd0, row_r} + 11'd1;
    assign column_w = ({3'd0, word_r} << 3) + {8'd0, lane_r};
    assign word_addr_w = 16'((32'(row_r) * 9 + 32'(head_r)) *
                             32'(head_words_r) + 32'(word_r));
    assign lane_bits_w = input_word_r[16*lane_r +: 16];
    assign lane_q_w = bf16_to_q16(lane_bits_w);
    assign delta_w = {max_q_r[31], max_q_r} - {lane_q_w[31], lane_q_w};
    assign div_trial_w = {remainder_r, (div_bit_r == 6'd60)};
    assign data_read_valid = state_r == MAX_REQ || state_r == SUM_REQ ||
                             state_r == OUT_REQ;
    assign data_read_bank = 4'd10;
    assign data_read_addr = word_addr_w;
    assign data_write_valid = state_r == OUT_WRITE;
    assign data_write_bank = 4'd10;
    assign data_write_addr = word_addr_w;
    assign data_write_strb = 16'hffff;
    assign data_write_data = output_word_r;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE;
            query_start_r <= '0; rows_r <= '0; row_r <= '0;
            kv_len_r <= '0; head_words_r <= '0; word_r <= '0;
            head_r <= '0; lane_r <= '0;
            input_word_r <= '0; output_word_r <= '0;
            max_q_r <= '0; sum_r <= '0; remainder_r <= '0;
            div_bit_r <= '0; reciprocal_r <= '0;
            lut_a_r <= '0; lut_b_r <= '0; exp_r <= '0;
            probability_r <= '0; product_r <= '0; interp_product_r <= '0;
            lut_index_r <= '0; lut_fraction_r <= '0;
            output_pass_r <= 1'b0; error_r <= 1'b0;
        end else case (state_r)
            IDLE: if (cmd_valid) begin
                error_r <= 1'b0;
                if (cmd_opcode != 4'd7 || cmd_bank[0] != 4'd10 ||
                    cmd_bank[1] != 0 || cmd_bank[2] != 0 ||
                    cmd_payload[111:27] != 0 ||
                    cmd_payload[16:11] == 0 || cmd_payload[16:11] > 6'd32 ||
                    cmd_payload[10:0] == 0 || cmd_payload[10:0] > 11'd1024 ||
                    ({1'b0, cmd_payload[26:17]} +
                     {5'd0, cmd_payload[16:11]} > cmd_payload[10:0])) begin
                    error_r <= 1'b1;
                    state_r <= DONE;
                end else begin
                    query_start_r <= cmd_payload[26:17];
                    rows_r <= cmd_payload[16:11];
                    kv_len_r <= cmd_payload[10:0];
                    head_words_r <= 8'((cmd_payload[10:0] + 11'd7) >> 3);
                    row_r <= '0; head_r <= '0; word_r <= '0; lane_r <= '0;
                    max_q_r <= 32'sh80000000;
                    state_r <= MAX_REQ;
                end
            end
            MAX_REQ: if (data_read_ready) state_r <= MAX_WAIT;
            MAX_WAIT: if (data_rsp_valid) begin
                if (data_rsp_bank != 4'd10) begin error_r <= 1'b1; state_r <= DONE; end
                else begin input_word_r <= data_rsp_data; lane_r <= '0; state_r <= MAX_LANE; end
            end
            MAX_LANE: begin
                if (column_w < valid_len_w && column_w < kv_len_r) begin
                    if (lane_bits_w[14:7] == 8'hff) begin
                        error_r <= 1'b1; state_r <= DONE;
                    end else begin
                        if (lane_q_w > max_q_r) max_q_r <= lane_q_w;
                        state_r <= MAX_ADV;
                    end
                end else state_r <= MAX_ADV;
            end
            MAX_ADV: if (lane_r != 3'd7) begin
                lane_r <= lane_r + 1'b1; state_r <= MAX_LANE;
            end else if (word_r + 1'b1 != head_words_r) begin
                word_r <= word_r + 1'b1; state_r <= MAX_REQ;
            end else begin
                word_r <= '0; sum_r <= '0; output_pass_r <= 1'b0;
                state_r <= SUM_REQ;
            end
            SUM_REQ: if (data_read_ready) state_r <= SUM_WAIT;
            SUM_WAIT: if (data_rsp_valid) begin
                if (data_rsp_bank != 4'd10) begin error_r <= 1'b1; state_r <= DONE; end
                else begin input_word_r <= data_rsp_data; lane_r <= '0; state_r <= EXP_NEXT; end
            end
            EXP_NEXT: begin
                if (column_w >= valid_len_w || column_w >= kv_len_r) begin
                    if (output_pass_r) begin
                        output_word_r[16*lane_r +: 16] <= 16'd0;
                        state_r <= OUT_ADV;
                    end else state_r <= SUM_ADV;
                end else if (delta_w >= 33'(24 * 65536)) begin
                    exp_r <= '0;
                    state_r <= output_pass_r ? OUT_MUL : SUM_ACC;
                end else begin
                    lut_index_r <= 10'(delta_w >> 11);
                    lut_fraction_r <= delta_w[10:0];
                    state_r <= EXP_ROM;
                end
            end
            EXP_ROM: begin
                lut_a_r <= smollm2_exp_q30(lut_index_r);
                lut_b_r <= smollm2_exp_q30(lut_index_r + 1'b1);
                state_r <= EXP_MUL;
            end
            EXP_MUL: begin
                interp_product_r <= (lut_a_r - lut_b_r) * lut_fraction_r;
                state_r <= EXP_PACK;
            end
            EXP_PACK: begin
                exp_r <= lut_a_r - 31'((interp_product_r + 42'd1024) >> 11);
                state_r <= output_pass_r ? OUT_MUL : SUM_ACC;
            end
            SUM_ACC: begin
                sum_r <= sum_r + {10'd0, exp_r};
                state_r <= SUM_ADV;
            end
            SUM_ADV: if (lane_r != 3'd7) begin
                lane_r <= lane_r + 1'b1; state_r <= EXP_NEXT;
            end else if (word_r + 1'b1 != head_words_r) begin
                word_r <= word_r + 1'b1; state_r <= SUM_REQ;
            end else if (sum_r == 0) begin
                error_r <= 1'b1; state_r <= DONE;
            end else begin
                remainder_r <= '0; reciprocal_r <= '0;
                div_bit_r <= 6'd60; state_r <= DIVIDE;
            end
            DIVIDE: begin
                if (div_trial_w >= {1'b0, sum_r}) begin
                    remainder_r <= 41'(div_trial_w - {1'b0, sum_r});
                    if (div_bit_r <= 6'd30) reciprocal_r[div_bit_r] <= 1'b1;
                end else remainder_r <= div_trial_w[40:0];
                if (div_bit_r == 0) begin
                    word_r <= '0; output_pass_r <= 1'b1; state_r <= OUT_REQ;
                end else div_bit_r <= div_bit_r - 1'b1;
            end
            OUT_REQ: if (data_read_ready) state_r <= OUT_WAIT;
            OUT_WAIT: if (data_rsp_valid) begin
                if (data_rsp_bank != 4'd10) begin error_r <= 1'b1; state_r <= DONE; end
                else begin
                    input_word_r <= data_rsp_data; output_word_r <= '0;
                    lane_r <= '0; state_r <= EXP_NEXT;
                end
            end
            OUT_MUL: begin
                product_r <= exp_r * reciprocal_r;
                state_r <= OUT_ROUND;
            end
            OUT_ROUND: begin
                probability_r <= 31'((product_r >> 30) +
                    ((product_r[29:0] > 30'h20000000 ||
                      (product_r[29:0] == 30'h20000000 && product_r[30])) ? 1 : 0));
                state_r <= OUT_PACK;
            end
            OUT_PACK: begin
                output_word_r[16*lane_r +: 16] <= q30_to_bf16(probability_r);
                state_r <= OUT_ADV;
            end
            OUT_ADV: if (lane_r != 3'd7) begin
                lane_r <= lane_r + 1'b1; state_r <= EXP_NEXT;
            end else state_r <= OUT_WRITE;
            OUT_WRITE: if (data_write_ready) begin
                if (word_r + 1'b1 != head_words_r) begin
                    word_r <= word_r + 1'b1; state_r <= OUT_REQ;
                end else begin
                    word_r <= '0; max_q_r <= 32'sh80000000;
                    if (head_r == 4'd8) begin
                        head_r <= '0;
                        if (row_r + 1'b1 == rows_r) state_r <= DONE;
                        else begin row_r <= row_r + 1'b1; state_r <= MAX_REQ; end
                    end else begin head_r <= head_r + 1'b1; state_r <= MAX_REQ; end
                end
            end
            DONE: if (done_ready) state_r <= IDLE;
            default: state_r <= IDLE;
        endcase
    end
endmodule
