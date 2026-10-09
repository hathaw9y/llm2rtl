`timescale 1ns/1ps

// Scalar, full-K GEMM executor. One output element is reduced at a time.
// Bank words contain eight little-endian BF16 values.
module smollm2_gemm_executor (
    input  logic aclk,
    input  logic aresetn,
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

    output logic act_read_valid,
    input  logic act_read_ready,
    output logic [3:0] act_read_bank,
    output logic [15:0] act_read_addr,
    input  logic act_rsp_valid,
    input  logic [3:0] act_rsp_bank,
    input  logic [127:0] act_rsp_data,
    output logic weight_read_valid,
    input  logic weight_read_ready,
    output logic [3:0] weight_read_bank,
    output logic [15:0] weight_read_addr,
    input  logic weight_rsp_valid,
    input  logic [3:0] weight_rsp_bank,
    input  logic [127:0] weight_rsp_data,
    output logic dst_write_valid,
    input  logic dst_write_ready,
    output logic [3:0] dst_write_bank,
    output logic [15:0] dst_write_addr,
    output logic [15:0] dst_write_strb,
    output logic [127:0] dst_write_data
);
    typedef enum logic [3:0] {IDLE, READ, WAIT_RSP, PRODUCT, MAC, ROUND_ABS,
                              ROUND_HIGH, ROUND_PACK, WRITE, DONE} state_t;
    state_t state_r;
    logic [2:0][3:0] bank_r;
    logic [15:0] n_start_r, n_total_r;
    logic [5:0] m_start_r, m_count_r;
    logic [10:0] k_total_r;
    logic [7:0] n_tile_r;
    logic [5:0] row_r;
    logic [7:0] col_r;
    logic [10:0] k_r;
    logic [15:0] a_bf_r, w_bf_r, result_bf_r;
    logic signed [63:0] acc_r;
    logic signed [11:0] scale_r;
    logic signed [63:0] term_r;
    logic signed [11:0] term_scale_r;
    logic [63:0] magnitude_r;
    logic sign_r;
    logic [5:0] high_r;
    logic seen_r, error_r;
    logic [31:0] act_index_w, weight_index_w, dst_index_w;
    logic read_pair_ready_w;

    function automatic logic [15:0] capacity_words(input logic [3:0] bank);
        case (bank)
            4'd0, 4'd1, 4'd2, 4'd4, 4'd5, 4'd11: capacity_words = 16'd2304;
            4'd3, 4'd10: capacity_words = 16'd36864;
            4'd6: capacity_words = 16'd768;
            4'd7: capacity_words = 16'd512;
            4'd8, 4'd9: capacity_words = 16'd24576;
            4'd12: capacity_words = 16'd6144;
            default: capacity_words = 16'd0;
        endcase
    endfunction

    function automatic logic signed [63:0] shift_toward_zero(
        input logic signed [63:0] value, input integer amount);
        logic [63:0] magnitude;
        begin
            magnitude = value[63] ? $unsigned(-value) : $unsigned(value);
            if (amount >= 64) magnitude = '0;
            else if (amount > 0) magnitude = magnitude >> amount;
            shift_toward_zero = value[63] ? -$signed(magnitude) : $signed(magnitude);
        end
    endfunction

    function automatic logic [15:0] bf16_from_parts(
        input logic [63:0] mag, input logic sign,
        input logic [5:0] high, input logic signed [11:0] scale);
        logic [63:0] dropped, half, base;
        logic [8:0] rounded;
        integer exponent, shift, sub_shift;
        begin
            bf16_from_parts = 16'd0;
            if (mag != 0) begin
                exponent = $signed(scale) + $signed({1'b0, high}) + 127;
                if (exponent >= 255) begin
                    bf16_from_parts = {sign, 8'hff, 7'd0};
                end else if (exponent > 0) begin
                    shift = high - 7;
                    if (shift > 0) begin
                        base = mag >> shift;
                        dropped = mag & ((64'd1 << shift) - 1);
                        half = 64'd1 << (shift - 1);
                        rounded = {1'b0, base[7:0]} +
                            ((dropped > half) || ((dropped == half) && base[0]));
                    end else begin
                        rounded = 9'(mag << (-shift));
                    end
                    if (rounded[8]) begin
                        exponent = exponent + 1;
                        rounded = 9'd128;
                    end
                    if (exponent >= 255) bf16_from_parts = {sign, 8'hff, 7'd0};
                    else bf16_from_parts = {sign, 8'(exponent), rounded[6:0]};
                end else begin
                    // BF16 subnormal unit is 2^-133.
                    sub_shift = -($signed(scale) + 133);
                    if (sub_shift >= 64) rounded = '0;
                    else if (sub_shift > 0) begin
                        base = mag >> sub_shift;
                        dropped = mag & ((64'd1 << sub_shift) - 1);
                        half = 64'd1 << (sub_shift - 1);
                        rounded = 9'(base) +
                            ((dropped > half) || ((dropped == half) && base[0]));
                    end else rounded = 9'(mag << (-sub_shift));
                    if (rounded >= 9'd128) bf16_from_parts = {sign, 8'd1, 7'd0};
                    else bf16_from_parts = {sign, 8'd0, rounded[6:0]};
                end
            end
        end
    endfunction

    always_comb begin
        act_index_w = (32'(m_start_r) + 32'(row_r)) * 32'(k_total_r) + 32'(k_r);
        weight_index_w = 32'(col_r) * 32'(k_total_r) + 32'(k_r);
        dst_index_w = 32'(row_r) * 32'(n_total_r) + 32'(n_start_r) + 32'(col_r);
        read_pair_ready_w = act_read_ready && weight_read_ready;
        cmd_ready = (state_r == IDLE);
        done_valid = (state_r == DONE);
        done_tag = bank_r[0];
        done_bank_count = 2'd3;
        done_bank = bank_r;
        done_error = error_r;
        act_read_valid = (state_r == READ) && read_pair_ready_w;
        weight_read_valid = (state_r == READ) && read_pair_ready_w;
        act_read_bank = bank_r[0];
        weight_read_bank = bank_r[1];
        act_read_addr = 16'(act_index_w >> 3);
        weight_read_addr = 16'(weight_index_w >> 3);
        dst_write_valid = (state_r == WRITE);
        dst_write_bank = bank_r[2];
        dst_write_addr = 16'(dst_index_w >> 3);
        dst_write_strb = 16'h0003 << (2 * dst_index_w[2:0]);
        dst_write_data = 128'(result_bf_r) << (16 * dst_index_w[2:0]);
    end

    always_ff @(posedge aclk) begin : sequencer
        logic [7:0] exp_a, exp_b;
        logic [7:0] sig_a, sig_b;
        logic [15:0] product;
        logic signed [63:0] term;
        if (!aresetn) begin
            state_r <= IDLE;
            bank_r <= '0;
            n_start_r <= '0; n_total_r <= '0;
            m_start_r <= '0; m_count_r <= '0;
            k_total_r <= '0; n_tile_r <= '0;
            row_r <= '0; col_r <= '0; k_r <= '0;
            a_bf_r <= '0; w_bf_r <= '0; result_bf_r <= '0;
            acc_r <= '0; scale_r <= '0;
            term_r <= '0; term_scale_r <= '0;
            magnitude_r <= '0; sign_r <= 1'b0; high_r <= '0;
            seen_r <= 1'b0; error_r <= 1'b0;
        end else begin
            case (state_r)
                IDLE: if (cmd_valid) begin
                    bank_r <= cmd_bank;
                    n_start_r <= cmd_payload[62:47];
                    n_total_r <= cmd_payload[46:31];
                    m_start_r <= cmd_payload[30:25];
                    m_count_r <= cmd_payload[24:19];
                    k_total_r <= cmd_payload[18:8];
                    n_tile_r <= cmd_payload[7:0];
                    row_r <= '0; col_r <= '0; k_r <= '0;
                    acc_r <= '0; scale_r <= '0; seen_r <= 1'b0;
                    error_r <= 1'b0;
                    if (cmd_opcode != 4'd3 || cmd_payload[111:63] != '0 ||
                        cmd_payload[46:31] == 0 || cmd_payload[24:19] == 0 ||
                        cmd_payload[18:8] == 0 || cmd_payload[7:0] == 0 ||
                        (32'(cmd_payload[30:25]) + 32'(cmd_payload[24:19]) > 32) ||
                        (32'(cmd_payload[62:47]) + 32'(cmd_payload[7:0]) >
                         32'(cmd_payload[46:31])) ||
                        ((32'(cmd_payload[30:25]) + 32'(cmd_payload[24:19])) *
                         32'(cmd_payload[18:8]) > 32'(capacity_words(cmd_bank[0])) * 8) ||
                        (32'(cmd_payload[7:0]) * 32'(cmd_payload[18:8]) >
                         32'(capacity_words(cmd_bank[1])) * 8) ||
                        (32'(cmd_payload[24:19]) * 32'(cmd_payload[46:31]) >
                         32'(capacity_words(cmd_bank[2])) * 8)) begin
                        error_r <= 1'b1;
                        state_r <= DONE;
                    end else state_r <= READ;
                end
                READ: if (read_pair_ready_w) state_r <= WAIT_RSP;
                WAIT_RSP: if (act_rsp_valid && weight_rsp_valid) begin
                    if (act_rsp_bank != bank_r[0] || weight_rsp_bank != bank_r[1]) begin
                        error_r <= 1'b1;
                        state_r <= DONE;
                    end else begin
                        a_bf_r <= act_rsp_data[16*act_index_w[2:0] +: 16];
                        w_bf_r <= weight_rsp_data[16*weight_index_w[2:0] +: 16];
                        state_r <= PRODUCT;
                    end
                end
                PRODUCT: begin
                    exp_a = a_bf_r[14:7];
                    exp_b = w_bf_r[14:7];
                    sig_a = exp_a == 0 ? {1'b0, a_bf_r[6:0]} : {1'b1, a_bf_r[6:0]};
                    sig_b = exp_b == 0 ? {1'b0, w_bf_r[6:0]} : {1'b1, w_bf_r[6:0]};
                    product = sig_a * sig_b;
                    term = $signed({1'b0, product, 32'd0});
                    if (a_bf_r[15] ^ w_bf_r[15]) term = -term;
                    term_scale_r <= 12'((exp_a == 0 ? 1 : 32'(exp_a)) +
                                       (exp_b == 0 ? 1 : 32'(exp_b)) - 300);
                    if (exp_a == 8'hff || exp_b == 8'hff) begin
                        error_r <= 1'b1;
                        state_r <= DONE;
                    end else begin
                        term_r <= term;
                        state_r <= MAC;
                    end
                end
                MAC: begin
                        if (term_r != 0) begin
                            if (!seen_r) begin
                                acc_r <= term_r;
                                scale_r <= term_scale_r;
                                seen_r <= 1'b1;
                            end else if (term_scale_r > scale_r) begin
                                acc_r <= shift_toward_zero(acc_r,
                                    $signed(term_scale_r) - $signed(scale_r)) + term_r;
                                scale_r <= term_scale_r;
                            end else begin
                                acc_r <= acc_r + shift_toward_zero(term_r,
                                    $signed(scale_r) - $signed(term_scale_r));
                            end
                        end
                        if (k_r + 11'd1 == k_total_r) state_r <= ROUND_ABS;
                        else begin k_r <= k_r + 11'd1; state_r <= READ; end
                end
                ROUND_ABS: begin
                    sign_r <= acc_r[63];
                    magnitude_r <= acc_r[63] ? $unsigned(-acc_r) : $unsigned(acc_r);
                    state_r <= ROUND_HIGH;
                end
                ROUND_HIGH: begin
                    high_r <= '0;
                    for (integer bit_index = 0; bit_index < 64; bit_index++)
                        if (magnitude_r[bit_index]) high_r <= 6'(bit_index);
                    state_r <= ROUND_PACK;
                end
                ROUND_PACK: begin
                    result_bf_r <= bf16_from_parts(magnitude_r, sign_r,
                                                   high_r, scale_r);
                    state_r <= WRITE;
                end
                WRITE: if (dst_write_ready) begin
                    acc_r <= '0; scale_r <= '0; seen_r <= 1'b0; k_r <= '0;
                    if (col_r + 8'd1 == n_tile_r) begin
                        col_r <= '0;
                        if (row_r + 6'd1 == m_count_r) state_r <= DONE;
                        else begin row_r <= row_r + 6'd1; state_r <= READ; end
                    end else begin col_r <= col_r + 8'd1; state_r <= READ; end
                end
                DONE: if (done_ready) state_r <= IDLE;
                default: state_r <= IDLE;
            endcase
        end
    end
endmodule
