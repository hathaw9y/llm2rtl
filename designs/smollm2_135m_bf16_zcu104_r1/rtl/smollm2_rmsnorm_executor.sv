`timescale 1ns/1ps

// RMSNorm for one 1..32 row chunk of the SmolLM2 hidden vector (576 BF16s).
// Payload bits [5:0] carry the row count. Each input/gamma/output bank word
// contains eight BF16 values. Reduction uses signed Q16.16 internally:
// E[x*x] and epsilon are accumulated in Q32.32; sqrt and Q32 reciprocal are
// restoring, one bit per cycle. The normalized value is rounded to BF16
// before gamma multiplication, matching the model's cast boundary. The output
// path multiplies BF16 significands and adjusts exponents so small values
// retain their BF16 precision.
module smollm2_rmsnorm_executor (
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
    output logic src_read_valid,
    input  logic src_read_ready,
    output logic [3:0] src_read_bank,
    output logic [15:0] src_read_addr,
    input  logic src_rsp_valid,
    input  logic [3:0] src_rsp_bank,
    input  logic [127:0] src_rsp_data,
    output logic gamma_read_valid,
    input  logic gamma_read_ready,
    output logic [3:0] gamma_read_bank,
    output logic [15:0] gamma_read_addr,
    input  logic gamma_rsp_valid,
    input  logic [3:0] gamma_rsp_bank,
    input  logic [127:0] gamma_rsp_data,
    output logic dst_write_valid,
    input  logic dst_write_ready,
    output logic [3:0] dst_write_bank,
    output logic [15:0] dst_write_addr,
    output logic [15:0] dst_write_strb,
    output logic [127:0] dst_write_data
);
    localparam int HIDDEN = 576;
    localparam int WORDS_PER_ROW = 72;
    localparam logic [63:0] EPS_Q32 = 64'd42950; // round(1e-5 * 2^32)
    typedef enum logic [4:0] {
        IDLE, SUM_REQ, SUM_WAIT, SUM_MUL, SUM_ADD, MEAN_INIT,
        MEAN_STEP, SQRT_INIT, SQRT_STEP, DIV_INIT, DIV_STEP,
        OUT_SRC_REQ, OUT_SRC_WAIT, OUT_GAMMA_REQ, OUT_GAMMA_WAIT,
        OUT_NORM, OUT_NORM_SCAN, OUT_NORM_META, OUT_GAMMA,
        OUT_DECODE, OUT_MULT, OUT_PACK,
        OUT_WRITE, DONE
    } state_t;
    state_t state_r;
    logic [2:0][3:0] bank_r;
    logic [5:0] rows_r, row_r;
    logic [6:0] word_r;
    logic [2:0] lane_r;
    logic [127:0] src_word_r, gamma_word_r, output_word_r;
    logic [63:0] sum_r, mean_quot_r;
    logic [10:0] mean_rem_r;
    logic [5:0] mean_bit_r;
    logic [63:0] sqrt_rad_r, sqrt_rem_r;
    logic [31:0] sqrt_root_r;
    logic [5:0] sqrt_step_r;
    logic [32:0] div_rem_r;
    logic [48:0] div_quot_r;
    logic [5:0] div_step_r;
    logic [47:0] inv_r;
    logic signed [31:0] x_q_r;
    logic [15:0] norm_bf16_r;
    logic [55:0] norm_product_r;
    logic signed [10:0] norm_scale_r, gamma_scale_r;
    logic [5:0] norm_high_r;
    logic norm_zero_r, norm_round_r;
    logic [7:0] norm_top_r;
    logic signed [10:0] norm_exp_r;
    logic norm_sign_r, gamma_sign_r;
    logic [15:0] gamma_product_r;
    logic error_r;

    function automatic logic signed [31:0] bf16_to_q16(input logic [15:0] v);
        logic [31:0] mag;
        integer shift;
        begin
            shift = (v[14:7] == 0 ? 1 : int'(v[14:7])) - 118;
            mag = {24'd0, (v[14:7] == 0 ? 1'b0 : 1'b1), v[6:0]};
            if (shift >= 0) mag = mag << shift;
            else if (shift > -32) mag = mag >> -shift;
            else mag = 0;
            bf16_to_q16 = v[15] ? -$signed(mag) : $signed(mag);
        end
    endfunction

    function automatic logic [7:0] bf16_sig(input logic [15:0] v);
        bf16_sig = {(v[14:7] != 0), v[6:0]};
    endfunction

    function automatic logic [15:0] product_to_bf16(
        input logic sign,
        input logic [55:0] mantissa,
        input logic signed [10:0] scale
    );
        logic [55:0] sig, discarded, halfway;
        logic [8:0] rounded;
        integer high, shift, exponent;
        begin
            high = -1;
            for (int i = 0; i < 56; i++) if (mantissa[i]) high = i;
            if (high < 0) product_to_bf16 = {sign, 15'd0};
            else begin
                shift = high - 7;
                exponent = int'($signed(scale)) + high + 127;
                if (shift > 0) begin
                    sig = mantissa >> shift;
                    discarded = mantissa & ((56'd1 << shift) - 1);
                    halfway = 56'd1 << (shift - 1);
                    rounded = {1'b0, sig[7:0]} +
                        ((discarded > halfway ||
                          (discarded == halfway && sig[0])) ? 9'd1 : 9'd0);
                end else rounded = 9'((mantissa << -shift) & 56'hff);
                if (rounded[8]) begin rounded = 9'h080; exponent++;
                end
                if (exponent >= 255) product_to_bf16 = {sign, 8'hff, 7'd0};
                else if (exponent <= 0) product_to_bf16 = {sign, 15'd0};
                else product_to_bf16 = {sign, 8'(exponent), rounded[6:0]};
            end
        end
    endfunction

    assign cmd_ready = state_r == IDLE;
    assign done_valid = state_r == DONE;
    assign done_tag = bank_r[0];
    assign done_bank_count = 2'd3;
    assign done_bank = bank_r;
    assign done_error = error_r;
    assign src_read_valid = state_r == SUM_REQ || state_r == OUT_SRC_REQ;
    assign src_read_bank = bank_r[0];
    assign src_read_addr = 16'(32'(row_r) * WORDS_PER_ROW + 32'(word_r));
    assign gamma_read_valid = state_r == OUT_GAMMA_REQ;
    assign gamma_read_bank = bank_r[1];
    assign gamma_read_addr = 16'(word_r);
    assign dst_write_valid = state_r == OUT_WRITE;
    assign dst_write_bank = bank_r[2];
    assign dst_write_addr = 16'(32'(row_r) * WORDS_PER_ROW + 32'(word_r));
    assign dst_write_strb = 16'hffff;
    assign dst_write_data = output_word_r;

    always_ff @(posedge aclk) begin : controller
        logic [64:0] next_mean_rem;
        logic [63:0] next_sqrt_rem, trial;
        logic [32:0] next_div_rem;
        logic [63:0] square_value;
        logic [55:0] norm_sig, norm_discarded, norm_halfway;
        logic [8:0] norm_rounded;
        integer norm_high, norm_shift;
        if (!aresetn) begin
            state_r <= IDLE; bank_r <= '0; rows_r <= '0; row_r <= '0;
            word_r <= '0; lane_r <= '0; src_word_r <= '0;
            gamma_word_r <= '0; output_word_r <= '0;
            sum_r <= '0;
            mean_quot_r <= '0; mean_rem_r <= '0; mean_bit_r <= '0;
            sqrt_rad_r <= '0; sqrt_rem_r <= '0;
            sqrt_root_r <= '0; sqrt_step_r <= '0;
            div_rem_r <= '0; div_quot_r <= '0; div_step_r <= '0;
            inv_r <= '0; x_q_r <= '0;
            norm_bf16_r <= '0; gamma_product_r <= '0;
            norm_product_r <= '0; norm_scale_r <= '0;
            norm_high_r <= '0; norm_zero_r <= 1'b0;
            norm_round_r <= 1'b0; norm_top_r <= '0; norm_exp_r <= '0;
            gamma_scale_r <= '0; norm_sign_r <= '0; gamma_sign_r <= '0;
            error_r <= 1'b0;
        end else case (state_r)
            IDLE: if (cmd_valid) begin
                bank_r <= cmd_bank;
                rows_r <= cmd_payload[5:0];
                row_r <= '0; word_r <= '0; lane_r <= '0;
                sum_r <= '0; error_r <= 1'b0;
                if (cmd_opcode != 4'd4 || cmd_payload[111:6] != '0 ||
                    cmd_payload[5:0] == 0 || cmd_payload[5:0] > 32 ||
                    cmd_bank[0] == cmd_bank[1] ||
                    cmd_bank[0] == cmd_bank[2] ||
                    cmd_bank[1] == cmd_bank[2]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else state_r <= SUM_REQ;
            end
            SUM_REQ: if (src_read_ready) state_r <= SUM_WAIT;
            SUM_WAIT: if (src_rsp_valid) begin
                if (src_rsp_bank != bank_r[0]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    src_word_r <= src_rsp_data;
                    lane_r <= '0; state_r <= SUM_MUL;
                end
            end
            SUM_MUL: begin
                if (src_word_r[16*lane_r + 7 +: 8] == 8'hff ||
                    src_word_r[16*lane_r + 7 +: 8] > 8'd141) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    x_q_r <= bf16_to_q16(src_word_r[16*lane_r +: 16]);
                    state_r <= SUM_ADD;
                end
            end
            SUM_ADD: begin
                square_value = 64'($signed(x_q_r) * $signed(x_q_r));
                if (sum_r > 64'hffff_ffff_ffff_ffff - square_value) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else if (lane_r == 7) begin
                    sum_r <= sum_r + square_value;
                    lane_r <= '0;
                    if (word_r == 7'd71) state_r <= MEAN_INIT;
                    else begin word_r <= word_r + 1'b1; state_r <= SUM_REQ; end
                end else begin
                    sum_r <= sum_r + square_value;
                    lane_r <= lane_r + 1'b1; state_r <= SUM_MUL;
                end
            end
            MEAN_INIT: begin
                mean_rem_r <= '0; mean_quot_r <= '0;
                mean_bit_r <= 6'd63; state_r <= MEAN_STEP;
            end
            MEAN_STEP: begin
                next_mean_rem = {53'd0, mean_rem_r, sum_r[mean_bit_r]};
                if (next_mean_rem >= 65'(HIDDEN)) begin
                    mean_rem_r <= 11'(next_mean_rem - 65'(HIDDEN));
                    mean_quot_r[mean_bit_r] <= 1'b1;
                end else mean_rem_r <= 11'(next_mean_rem);
                if (mean_bit_r == 0) state_r <= SQRT_INIT;
                else mean_bit_r <= mean_bit_r - 1'b1;
            end
            SQRT_INIT: begin
                sqrt_rad_r <= mean_quot_r + EPS_Q32;
                sqrt_rem_r <= '0; sqrt_root_r <= '0;
                sqrt_step_r <= 6'd31; state_r <= SQRT_STEP;
            end
            SQRT_STEP: begin
                next_sqrt_rem = (sqrt_rem_r << 2) |
                    ((sqrt_rad_r >> (2*sqrt_step_r)) & 64'd3);
                trial = ({32'd0, sqrt_root_r} << 2) | 64'd1;
                if (next_sqrt_rem >= trial) begin
                    sqrt_rem_r <= next_sqrt_rem - trial;
                    sqrt_root_r <= (sqrt_root_r << 1) | 32'd1;
                end else begin
                    sqrt_rem_r <= next_sqrt_rem;
                    sqrt_root_r <= sqrt_root_r << 1;
                end
                if (sqrt_step_r == 0) state_r <= DIV_INIT;
                else sqrt_step_r <= sqrt_step_r - 1'b1;
            end
            DIV_INIT: begin
                if (sqrt_root_r == 0) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    div_rem_r <= '0; div_quot_r <= '0;
                    div_step_r <= 6'd48; state_r <= DIV_STEP;
                end
            end
            DIV_STEP: begin
                next_div_rem = {div_rem_r[31:0], (div_step_r == 48)};
                if (next_div_rem >= {1'b0, sqrt_root_r}) begin
                    div_rem_r <= next_div_rem - {1'b0, sqrt_root_r};
                    div_quot_r[div_step_r] <= 1'b1;
                end else div_rem_r <= next_div_rem;
                if (div_step_r == 0) begin
                    inv_r <= div_quot_r[47:0];
                    // The bit determined in this final division cycle is bit 0.
                    inv_r[0] <= next_div_rem >= {1'b0, sqrt_root_r};
                    word_r <= '0; state_r <= OUT_SRC_REQ;
                end else div_step_r <= div_step_r - 1'b1;
            end
            OUT_SRC_REQ: if (src_read_ready) state_r <= OUT_SRC_WAIT;
            OUT_SRC_WAIT: if (src_rsp_valid) begin
                if (src_rsp_bank != bank_r[0]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    src_word_r <= src_rsp_data;
                    state_r <= OUT_GAMMA_REQ;
                end
            end
            OUT_GAMMA_REQ: if (gamma_read_ready) state_r <= OUT_GAMMA_WAIT;
            OUT_GAMMA_WAIT: if (gamma_rsp_valid) begin
                if (gamma_rsp_bank != bank_r[1]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    gamma_word_r <= gamma_rsp_data; lane_r <= '0;
                    state_r <= OUT_NORM;
                end
            end
            OUT_NORM: begin
                norm_product_r <= bf16_sig(src_word_r[16*lane_r +: 16]) * inv_r;
                norm_scale_r <= 11'($signed({1'b0,
                    (src_word_r[16*lane_r + 7 +: 8] == 0 ? 8'd1 :
                     src_word_r[16*lane_r + 7 +: 8])}) - 11'sd166);
                norm_sign_r <= src_word_r[16*lane_r + 15];
                state_r <= OUT_NORM_SCAN;
            end
            OUT_NORM_SCAN: begin
                norm_high = -1;
                for (int i = 0; i < 56; i++)
                    if (norm_product_r[i]) norm_high = i;
                norm_zero_r <= norm_high < 0;
                norm_high_r <= 6'(norm_high);
                state_r <= OUT_NORM_META;
            end
            OUT_NORM_META: begin
                norm_shift = int'(norm_high_r) - 7;
                norm_exp_r <= 11'($signed(norm_scale_r) +
                                  $signed({1'b0, norm_high_r}) + 11'sd127);
                if (norm_shift > 0) begin
                    norm_sig = norm_product_r >> norm_shift;
                    norm_discarded = norm_product_r &
                                     ((56'd1 << norm_shift) - 1);
                    norm_halfway = 56'd1 << (norm_shift - 1);
                    norm_top_r <= norm_sig[7:0];
                    norm_round_r <= norm_discarded > norm_halfway ||
                        (norm_discarded == norm_halfway && norm_sig[0]);
                end else begin
                    norm_sig = norm_product_r << -norm_shift;
                    norm_top_r <= norm_sig[7:0];
                    norm_round_r <= 1'b0;
                end
                state_r <= OUT_GAMMA;
            end
            OUT_GAMMA: begin
                norm_rounded = {1'b0, norm_top_r} + 9'(norm_round_r);
                if (norm_zero_r || norm_exp_r <= 0)
                    norm_bf16_r <= {norm_sign_r, 15'd0};
                else if ($signed(norm_exp_r) + 11'(norm_rounded[8]) >= 255)
                    norm_bf16_r <= {norm_sign_r, 8'hff, 7'd0};
                else norm_bf16_r <= {norm_sign_r,
                    8'(norm_exp_r + 11'(norm_rounded[8])),
                    norm_rounded[8] ? 7'd0 : norm_rounded[6:0]};
                if (gamma_word_r[16*lane_r + 7 +: 8] == 8'hff ||
                    gamma_word_r[16*lane_r + 7 +: 8] > 8'd141) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else state_r <= OUT_DECODE;
            end
            OUT_DECODE: begin
                gamma_sign_r <= norm_bf16_r[15] ^
                                gamma_word_r[16*lane_r + 15];
                gamma_scale_r <= 11'(
                    $signed({1'b0, (norm_bf16_r[14:7] == 0 ? 8'd1 :
                                     norm_bf16_r[14:7])}) +
                    $signed({1'b0, (gamma_word_r[16*lane_r + 7 +: 8] == 0 ?
                                     8'd1 : gamma_word_r[16*lane_r + 7 +: 8])}) -
                    11'sd268);
                state_r <= OUT_MULT;
            end
            OUT_MULT: begin
                gamma_product_r <= bf16_sig(norm_bf16_r) *
                    bf16_sig(gamma_word_r[16*lane_r +: 16]);
                state_r <= OUT_PACK;
            end
            OUT_PACK: begin
                output_word_r[16*lane_r +: 16] <=
                    product_to_bf16(gamma_sign_r,
                                    {40'd0, gamma_product_r}, gamma_scale_r);
                if (lane_r == 7) state_r <= OUT_WRITE;
                else begin lane_r <= lane_r + 1'b1; state_r <= OUT_NORM; end
            end
            OUT_WRITE: if (dst_write_ready) begin
                if (word_r == 7'd71) begin
                    if (row_r + 1'b1 == rows_r) state_r <= DONE;
                    else begin
                        row_r <= row_r + 1'b1; word_r <= '0;
                        sum_r <= '0; state_r <= SUM_REQ;
                    end
                end else begin word_r <= word_r + 1'b1; state_r <= OUT_SRC_REQ; end
            end
            DONE: if (done_ready) state_r <= IDLE;
            default: state_r <= IDLE;
        endcase
    end
endmodule
