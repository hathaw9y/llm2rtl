`timescale 1ns/1ps

// Serial grouped-query attention dot products. MODE_VALUE=0 computes
// Q[B4] * K[B8]^T / sqrt(64) into B10; MODE_VALUE=1 computes
// probability[B10] * V[B9] into context[B11]. All memories use eight
// BF16 elements per 128-bit word. K/V are [token,3,64], Q/context
// [row,9,64], score/probability [row,9,ceil(kv_len/8)].
module smollm2_attention_executor #(
    parameter bit MODE_VALUE = 1'b0
) (
    input logic aclk, aresetn,
    input logic cmd_valid,
    output logic cmd_ready,
    input logic [3:0] cmd_opcode,
    input logic [2:0][3:0] cmd_bank,
    input logic [111:0] cmd_payload,
    output logic done_valid,
    input logic done_ready,
    output logic [3:0] done_tag,
    output logic [1:0] done_bank_count,
    output logic [2:0][3:0] done_bank,
    output logic done_error,
    output logic a_read_valid,
    input logic a_read_ready,
    output logic [3:0] a_read_bank,
    output logic [15:0] a_read_addr,
    input logic a_rsp_valid,
    input logic [3:0] a_rsp_bank,
    input logic [127:0] a_rsp_data,
    output logic b_read_valid,
    input logic b_read_ready,
    output logic [3:0] b_read_bank,
    output logic [15:0] b_read_addr,
    input logic b_rsp_valid,
    input logic [3:0] b_rsp_bank,
    input logic [127:0] b_rsp_data,
    output logic dst_write_valid,
    input logic dst_write_ready,
    output logic [3:0] dst_write_bank,
    output logic [15:0] dst_write_addr,
    output logic [15:0] dst_write_strb,
    output logic [127:0] dst_write_data
);
    typedef enum logic [3:0] {
        IDLE, START_ELEM, A_REQ, A_WAIT, B_REQ, B_WAIT,
        CONVERT, MULT, ACC, NEXT_RED, PACK, STORE_ELEM, WRITE_WORD, DONE
    } state_t;
    state_t state_r;
    logic [2:0][3:0] bank_r;
    logic [9:0] start_r;
    logic [5:0] rows_r, row_r;
    logic [10:0] kv_len_r, elem_r, red_r;
    logic [7:0] head_words_r;
    logic [3:0] head_r;
    logic [2:0] out_lane_r;
    logic [127:0] a_word_r, b_word_r, out_word_r;
    logic signed [63:0] product_r;
    logic signed [31:0] a_q_r, b_q_r;
    logic signed [79:0] accumulator_r;
    logic [15:0] packed_r;
    logic error_r;
    logic [10:0] output_count_w, reduction_count_w;
    logic [2:0] a_lane_w, b_lane_w;

    function automatic logic signed [31:0] bf16_q24(input logic [15:0] v);
        integer exponent, shift;
        logic [7:0] sig;
        logic [31:0] mag, chopped, rem, half;
        begin
            sig = {(v[14:7] != 0), v[6:0]};
            exponent = v[14:7] == 0 ? 1 : int'(v[14:7]);
            shift = exponent - 110;
            if (shift >= 24) mag = 32'h7fffffff;
            else if (shift >= 0) mag = 32'(sig) << shift;
            else if (shift <= -32) mag = 0;
            else begin
                chopped = 32'(sig) >> -shift;
                rem = 32'(sig) & ((32'd1 << -shift) - 1);
                half = 32'd1 << (-shift - 1);
                mag = chopped + (rem > half || (rem == half && chopped[0]));
            end
            if (mag > 32'h7fffffff) mag = 32'h7fffffff;
            bf16_q24 = v[15] ? -$signed(mag) : $signed(mag);
        end
    endfunction

    function automatic logic [15:0] q48_to_bf16(input logic signed [79:0] v);
        logic sign;
        logic [79:0] mag, chopped, remainder, halfway;
        logic [8:0] rounded;
        integer high, shift, exponent;
        begin
            sign = v[79];
            mag = sign ? -v : v;
            high = -1;
            for (int i = 0; i < 80; i++) if (mag[i]) high = i;
            if (high < 0) q48_to_bf16 = 16'd0;
            else begin
                shift = high - 7;
                exponent = 127 + high - 48 - (MODE_VALUE ? 0 : 3);
                if (shift > 0) begin
                    chopped = mag >> shift;
                    remainder = mag & ((80'd1 << shift) - 1);
                    halfway = 80'd1 << (shift - 1);
                    rounded = {1'b0, chopped[7:0]} +
                        (remainder > halfway ||
                         (remainder == halfway && chopped[0]));
                end else rounded = 9'(mag << -shift);
                if (rounded[8]) begin
                    rounded = 9'h080;
                    exponent++;
                end
                if (exponent >= 255) q48_to_bf16 = {sign,8'hff,7'd0};
                else if (exponent <= 0) q48_to_bf16 = {sign,15'd0};
                else q48_to_bf16 = {sign,8'(exponent),rounded[6:0]};
            end
        end
    endfunction

    assign cmd_ready = state_r == IDLE;
    assign done_valid = state_r == DONE;
    assign done_tag = bank_r[0];
    assign done_bank_count = 2'd3;
    assign done_bank = bank_r;
    assign done_error = error_r;
    assign output_count_w = MODE_VALUE ? 11'd64 : kv_len_r;
    assign reduction_count_w = MODE_VALUE ? kv_len_r : 11'd64;
    assign a_read_valid = state_r == A_REQ;
    assign a_read_bank = bank_r[0];
    assign a_read_addr = MODE_VALUE ?
        16'((32'(row_r)*9 + 32'(head_r))*32'(head_words_r) +
            (32'(red_r) >> 3)) :
        16'(32'(row_r)*72 + 32'(head_r)*8 + (32'(red_r) >> 3));
    assign b_read_valid = state_r == B_REQ;
    assign b_read_bank = bank_r[1];
    assign b_read_addr = MODE_VALUE ?
        16'(32'(red_r)*24 + (32'(head_r)/3)*8 + (32'(elem_r) >> 3)) :
        16'(32'(elem_r)*24 + (32'(head_r)/3)*8 + (32'(red_r) >> 3));
    assign a_lane_w = MODE_VALUE ? red_r[2:0] : red_r[2:0];
    assign b_lane_w = MODE_VALUE ? elem_r[2:0] : red_r[2:0];
    assign dst_write_valid = state_r == WRITE_WORD;
    assign dst_write_bank = bank_r[2];
    assign dst_write_addr = MODE_VALUE ?
        16'(32'(row_r)*72 + 32'(head_r)*8 + (32'(elem_r) >> 3)) :
        16'((32'(row_r)*9 + 32'(head_r))*32'(head_words_r) +
            (32'(elem_r) >> 3));
    assign dst_write_strb = 16'hffff;
    assign dst_write_data = out_word_r;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE; bank_r <= '0; start_r <= '0;
            rows_r <= '0; row_r <= '0; kv_len_r <= '0;
            head_words_r <= '0; head_r <= '0;
            elem_r <= '0; red_r <= '0; out_lane_r <= '0;
            a_word_r <= '0; b_word_r <= '0; out_word_r <= '0;
            a_q_r <= '0; b_q_r <= '0;
            product_r <= '0; accumulator_r <= '0; packed_r <= '0;
            error_r <= 1'b0;
        end else case (state_r)
            IDLE: if (cmd_valid) begin
                bank_r <= cmd_bank;
                start_r <= cmd_payload[26:17];
                rows_r <= cmd_payload[16:11];
                kv_len_r <= cmd_payload[10:0];
                head_words_r <= 8'((cmd_payload[10:0] + 11'd7) >> 3);
                row_r <= '0; head_r <= '0; elem_r <= '0;
                red_r <= '0; out_lane_r <= '0; out_word_r <= '0;
                accumulator_r <= '0; error_r <= 1'b0;
                if (cmd_opcode != (MODE_VALUE ? 4'd8 : 4'd6) ||
                    cmd_bank != (MODE_VALUE ? {4'd11,4'd9,4'd10} :
                                             {4'd10,4'd8,4'd4}) ||
                    cmd_payload[111:27] != 0 ||
                    cmd_payload[16:11] == 0 || cmd_payload[16:11] > 6'd32 ||
                    cmd_payload[10:0] == 0 || cmd_payload[10:0] > 11'd1024 ||
                    ({1'b0,cmd_payload[26:17]} +
                     {5'd0,cmd_payload[16:11]} > cmd_payload[10:0])) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else state_r <= START_ELEM;
            end
            START_ELEM: begin
                if (!MODE_VALUE && elem_r >
                    {1'b0,start_r} + {5'd0,row_r}) begin
                    packed_r <= 16'd0; state_r <= STORE_ELEM;
                end else state_r <= A_REQ;
            end
            A_REQ: if (a_read_ready) state_r <= A_WAIT;
            A_WAIT: if (a_rsp_valid) begin
                if (a_rsp_bank != bank_r[0]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin a_word_r <= a_rsp_data; state_r <= B_REQ; end
            end
            B_REQ: if (b_read_ready) state_r <= B_WAIT;
            B_WAIT: if (b_rsp_valid) begin
                if (b_rsp_bank != bank_r[1]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin b_word_r <= b_rsp_data; state_r <= CONVERT; end
            end
            CONVERT: begin
                if (a_word_r[16*a_lane_w+7 +: 8] == 8'hff ||
                    b_word_r[16*b_lane_w+7 +: 8] == 8'hff) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    a_q_r <= bf16_q24(a_word_r[16*a_lane_w +: 16]);
                    b_q_r <= bf16_q24(b_word_r[16*b_lane_w +: 16]);
                    state_r <= MULT;
                end
            end
            MULT: begin
                product_r <= a_q_r * b_q_r;
                state_r <= ACC;
            end
            ACC: begin
                accumulator_r <= accumulator_r + {{16{product_r[63]}},product_r};
                state_r <= NEXT_RED;
            end
            NEXT_RED: if (red_r + 1'b1 == reduction_count_w)
                state_r <= PACK;
            else begin red_r <= red_r + 1'b1; state_r <= A_REQ; end
            PACK: begin
                packed_r <= q48_to_bf16(accumulator_r);
                state_r <= STORE_ELEM;
            end
            STORE_ELEM: begin
                out_word_r[16*out_lane_r +: 16] <= packed_r;
                if (out_lane_r == 3'd7 || elem_r + 1'b1 == output_count_w)
                    state_r <= WRITE_WORD;
                else begin
                    elem_r <= elem_r + 1'b1;
                    out_lane_r <= out_lane_r + 1'b1;
                    red_r <= '0; accumulator_r <= '0;
                    state_r <= START_ELEM;
                end
            end
            WRITE_WORD: if (dst_write_ready) begin
                out_word_r <= '0;
                out_lane_r <= '0;
                red_r <= '0; accumulator_r <= '0;
                if (elem_r + 1'b1 != output_count_w) begin
                    elem_r <= elem_r + 1'b1;
                    state_r <= START_ELEM;
                end else begin
                    elem_r <= '0;
                    if (head_r == 4'd8) begin
                        head_r <= '0;
                        if (row_r + 1'b1 == rows_r) state_r <= DONE;
                        else begin row_r <= row_r + 1'b1; state_r <= START_ELEM; end
                    end else begin head_r <= head_r + 1'b1; state_r <= START_ELEM; end
                end
            end
            DONE: if (done_ready) state_r <= IDLE;
            default: state_r <= IDLE;
        endcase
    end
endmodule
