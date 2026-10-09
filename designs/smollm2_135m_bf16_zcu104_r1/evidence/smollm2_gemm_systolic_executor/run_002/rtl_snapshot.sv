`timescale 1ns/1ps

// One output-stationary BF16 processing element. A moves right, W moves down.
// The arithmetic order and rounding state match the scalar GEMM baseline.
module smollm2_bf16_systolic_pe (
    input  logic clk,
    input  logic resetn,
    input  logic clear,
    input  logic step,
    input  logic [15:0] a_in,
    input  logic a_valid_in,
    input  logic [15:0] w_in,
    input  logic w_valid_in,
    output logic [15:0] a_out,
    output logic a_valid_out,
    output logic [15:0] w_out,
    output logic w_valid_out,
    output logic signed [35:0] acc_out,
    output logic signed [11:0] scale_out,
    output logic nonfinite_out
);
    logic signed [35:0] term_r;
    logic signed [11:0] term_scale_r;
    logic term_valid_r, seen_r;

    function automatic logic signed [35:0] shift_toward_zero(
        input logic signed [35:0] value, input integer amount);
        logic [35:0] magnitude;
        begin
            magnitude = value[35] ? $unsigned(-value) : $unsigned(value);
            if (amount >= 36) magnitude = '0;
            else if (amount > 0) magnitude = magnitude >> amount;
            shift_toward_zero = value[35] ? -$signed(magnitude) : $signed(magnitude);
        end
    endfunction

    always_ff @(posedge clk) begin : pe_pipeline
        logic [7:0] exp_a, exp_w, sig_a, sig_w;
        logic [15:0] product;
        logic signed [35:0] term;
        if (!resetn || clear) begin
            a_out <= '0; w_out <= '0;
            a_valid_out <= 1'b0; w_valid_out <= 1'b0;
            term_r <= '0; term_scale_r <= '0; term_valid_r <= 1'b0;
            acc_out <= '0; scale_out <= '0; seen_r <= 1'b0;
            nonfinite_out <= 1'b0;
        end else if (step) begin
            a_out <= a_in; w_out <= w_in;
            a_valid_out <= a_valid_in; w_valid_out <= w_valid_in;
            term_valid_r <= a_valid_in && w_valid_in;
            if (a_valid_in && w_valid_in) begin
                exp_a = a_in[14:7]; exp_w = w_in[14:7];
                sig_a = exp_a == 0 ? {1'b0, a_in[6:0]} : {1'b1, a_in[6:0]};
                sig_w = exp_w == 0 ? {1'b0, w_in[6:0]} : {1'b1, w_in[6:0]};
                product = sig_a * sig_w;
                term = $signed({1'b0, product, 8'd0});
                if (a_in[15] ^ w_in[15]) term = -term;
                term_r <= term;
                term_scale_r <= 12'((exp_a == 0 ? 1 : 32'(exp_a)) +
                                    (exp_w == 0 ? 1 : 32'(exp_w)) - 276);
                if (exp_a == 8'hff || exp_w == 8'hff) nonfinite_out <= 1'b1;
            end
            if (term_valid_r && term_r != 0) begin
                if (!seen_r) begin
                    acc_out <= term_r;
                    scale_out <= term_scale_r;
                    seen_r <= 1'b1;
                end else if (term_scale_r > scale_out) begin
                    acc_out <= shift_toward_zero(acc_out,
                        $signed(term_scale_r) - $signed(scale_out)) + term_r;
                    scale_out <= term_scale_r;
                end else begin
                    acc_out <= acc_out + shift_toward_zero(term_r,
                        $signed(scale_out) - $signed(term_scale_r));
                end
            end
        end
    end
endmodule

// A 16x16 output-stationary systolic array. K is internally tiled by 16;
// 128-bit bank words are staged before each wavefront, so the ISA is unchanged.
module smollm2_gemm_systolic_executor (
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
    typedef enum logic [3:0] {IDLE, TILE_CLEAR, LOAD_REQ, LOAD_RSP,
        RUN, ROUND_ABS, ROUND_HIGH, ROUND_PACK, WRITE, DONE} state_t;
    state_t state_r;
    logic [2:0][3:0] bank_r;
    logic [15:0] n_start_r, n_total_r;
    logic [5:0] m_start_r, m_count_r;
    logic [10:0] k_total_r, k_base_r;
    logic [7:0] n_tile_r, col_base_r;
    logic [5:0] row_base_r;
    logic [4:0] rows_in_tile_w, cols_in_tile_w, k_in_tile_w;
    logic [4:0] load_row_r;
    logic [1:0] load_word_r;
    logic [5:0] run_cycle_r;
    logic [4:0] out_row_r, out_col_r;
    logic [15:0] a_tile [0:15][0:15];
    logic [15:0] w_tile [0:15][0:15];
    wire [15:0] a_wave [0:15][0:15];
    wire [15:0] w_wave [0:15][0:15];
    wire a_wave_valid [0:15][0:15];
    wire w_wave_valid [0:15][0:15];
    wire signed [35:0] pe_acc [0:15][0:15];
    wire signed [11:0] pe_scale [0:15][0:15];
    wire pe_nonfinite [0:15][0:15];
    logic [35:0] magnitude_r;
    logic sign_r;
    logic [5:0] high_r;
    logic signed [11:0] round_scale_r;
    logic [15:0] result_r;
    logic error_r;
    logic [31:0] act_base_w, weight_base_w, act_word_w, weight_word_w;
    logic act_needed_w, weight_needed_w, load_ready_w;
    logic [31:0] dst_index_w;
    logic nonfinite_any_w;

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

    function automatic logic [15:0] bf16_from_parts(
        input logic [35:0] mag, input logic sign,
        input logic [5:0] high, input logic signed [11:0] scale);
        logic [35:0] dropped, half, base;
        logic [8:0] rounded;
        integer exponent, shift, sub_shift;
        begin
            bf16_from_parts = 16'd0;
            if (mag != 0) begin
                exponent = $signed(scale) + $signed({1'b0, high}) + 127;
                if (exponent >= 255) bf16_from_parts = {sign, 8'hff, 7'd0};
                else if (exponent > 0) begin
                    shift = high - 7;
                    if (shift > 0) begin
                        base = mag >> shift;
                        dropped = mag & ((36'd1 << shift) - 1);
                        half = 36'd1 << (shift - 1);
                        rounded = {1'b0, base[7:0]} +
                            ((dropped > half) || ((dropped == half) && base[0]));
                    end else rounded = 9'(mag << (-shift));
                    if (rounded[8]) begin exponent = exponent + 1; rounded = 9'd128; end
                    if (exponent >= 255) bf16_from_parts = {sign, 8'hff, 7'd0};
                    else bf16_from_parts = {sign, 8'(exponent), rounded[6:0]};
                end else begin
                    sub_shift = -($signed(scale) + 133);
                    if (sub_shift >= 36) rounded = '0;
                    else if (sub_shift > 0) begin
                        base = mag >> sub_shift;
                        dropped = mag & ((36'd1 << sub_shift) - 1);
                        half = 36'd1 << (sub_shift - 1);
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
        rows_in_tile_w = (m_count_r - row_base_r >= 16) ? 5'd16 :
                         5'(m_count_r - row_base_r);
        cols_in_tile_w = (n_tile_r - col_base_r >= 16) ? 5'd16 :
                         5'(n_tile_r - col_base_r);
        k_in_tile_w = (k_total_r - k_base_r >= 16) ? 5'd16 :
                      5'(k_total_r - k_base_r);
        act_base_w = (32'(m_start_r) + 32'(row_base_r) + 32'(load_row_r)) *
                     32'(k_total_r) + 32'(k_base_r);
        weight_base_w = (32'(col_base_r) + 32'(load_row_r)) *
                        32'(k_total_r) + 32'(k_base_r);
        act_word_w = (act_base_w >> 3) + 32'(load_word_r);
        weight_word_w = (weight_base_w >> 3) + 32'(load_word_r);
        act_needed_w = load_row_r < rows_in_tile_w &&
                       act_word_w <= ((act_base_w + 32'(k_in_tile_w) - 1) >> 3);
        weight_needed_w = load_row_r < cols_in_tile_w &&
                          weight_word_w <= ((weight_base_w + 32'(k_in_tile_w) - 1) >> 3);
        load_ready_w = (!act_needed_w || act_read_ready) &&
                       (!weight_needed_w || weight_read_ready);
        act_read_valid = state_r == LOAD_REQ && act_needed_w && load_ready_w;
        weight_read_valid = state_r == LOAD_REQ && weight_needed_w && load_ready_w;
        act_read_bank = bank_r[0]; act_read_addr = 16'(act_word_w);
        weight_read_bank = bank_r[1]; weight_read_addr = 16'(weight_word_w);
        dst_index_w = 32'(row_base_r + out_row_r) * 32'(n_total_r) +
                      32'(n_start_r) + 32'(col_base_r) + 32'(out_col_r);
        dst_write_valid = state_r == WRITE;
        dst_write_bank = bank_r[2];
        dst_write_addr = 16'(dst_index_w >> 3);
        dst_write_strb = 16'h0003 << (2 * dst_index_w[2:0]);
        dst_write_data = 128'(result_r) << (16 * dst_index_w[2:0]);
        cmd_ready = state_r == IDLE;
        done_valid = state_r == DONE;
        done_tag = bank_r[0]; done_bank_count = 2'd3;
        done_bank = bank_r; done_error = error_r;
        nonfinite_any_w = 1'b0;
        for (int r = 0; r < 16; r++)
            for (int c = 0; c < 16; c++)
                if (r < rows_in_tile_w && c < cols_in_tile_w && pe_nonfinite[r][c])
                    nonfinite_any_w = 1'b1;
    end

    for (genvar r = 0; r < 16; r++) begin : gen_row
        for (genvar c = 0; c < 16; c++) begin : gen_col
            wire [15:0] a_in_w, w_in_w;
            wire a_valid_in_w, w_valid_in_w;
            if (c == 0) begin : gen_left
                assign a_in_w = ((run_cycle_r >= r) &&
                    (run_cycle_r - r < k_in_tile_w) && (r < rows_in_tile_w)) ?
                    a_tile[r][run_cycle_r-r] : 16'd0;
                assign a_valid_in_w = (run_cycle_r >= r) &&
                    (run_cycle_r-r < k_in_tile_w) && (r < rows_in_tile_w);
            end else begin : gen_right
                assign a_in_w = a_wave[r][c-1];
                assign a_valid_in_w = a_wave_valid[r][c-1];
            end
            if (r == 0) begin : gen_top
                assign w_in_w = ((run_cycle_r >= c) &&
                    (run_cycle_r-c < k_in_tile_w) && (c < cols_in_tile_w)) ?
                    w_tile[c][run_cycle_r-c] : 16'd0;
                assign w_valid_in_w = (run_cycle_r >= c) &&
                    (run_cycle_r-c < k_in_tile_w) && (c < cols_in_tile_w);
            end else begin : gen_bottom
                assign w_in_w = w_wave[r-1][c];
                assign w_valid_in_w = w_wave_valid[r-1][c];
            end
            smollm2_bf16_systolic_pe pe (
                .clk(aclk), .resetn(aresetn), .clear(state_r == TILE_CLEAR),
                .step(state_r == RUN), .a_in(a_in_w), .a_valid_in(a_valid_in_w),
                .w_in(w_in_w), .w_valid_in(w_valid_in_w),
                .a_out(a_wave[r][c]), .a_valid_out(a_wave_valid[r][c]),
                .w_out(w_wave[r][c]), .w_valid_out(w_wave_valid[r][c]),
                .acc_out(pe_acc[r][c]), .scale_out(pe_scale[r][c]),
                .nonfinite_out(pe_nonfinite[r][c]));
        end
    end

    always_ff @(posedge aclk) begin : controller
        logic [31:0] element_index;
        if (!aresetn) begin
            state_r <= IDLE; bank_r <= '0;
            n_start_r <= '0; n_total_r <= '0;
            m_start_r <= '0; m_count_r <= '0;
            k_total_r <= '0; n_tile_r <= '0;
            row_base_r <= '0; col_base_r <= '0; k_base_r <= '0;
            load_row_r <= '0; load_word_r <= '0; run_cycle_r <= '0;
            out_row_r <= '0; out_col_r <= '0;
            magnitude_r <= '0; sign_r <= 1'b0; high_r <= '0;
            round_scale_r <= '0; result_r <= '0; error_r <= 1'b0;
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
                    row_base_r <= '0; col_base_r <= '0; k_base_r <= '0;
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
                        error_r <= 1'b1; state_r <= DONE;
                    end else state_r <= TILE_CLEAR;
                end
                TILE_CLEAR: begin
                    k_base_r <= '0;
                    load_row_r <= '0; load_word_r <= '0;
                    state_r <= LOAD_REQ;
                end
                LOAD_REQ: if (load_ready_w) begin
                    if (act_needed_w || weight_needed_w) state_r <= LOAD_RSP;
                    else if (load_word_r == 2) begin
                        load_word_r <= '0;
                        if (load_row_r == 15) begin
                            run_cycle_r <= '0; state_r <= RUN;
                        end else load_row_r <= load_row_r + 1'b1;
                    end else load_word_r <= load_word_r + 1'b1;
                end
                LOAD_RSP: if ((!act_needed_w || act_rsp_valid) &&
                              (!weight_needed_w || weight_rsp_valid)) begin
                    if ((act_needed_w && act_rsp_bank != bank_r[0]) ||
                        (weight_needed_w && weight_rsp_bank != bank_r[1])) begin
                        error_r <= 1'b1; state_r <= DONE;
                    end else begin
                        for (int lane = 0; lane < 8; lane++) begin
                            element_index = (act_word_w << 3) + 32'(lane);
                            if (act_needed_w && element_index >= act_base_w &&
                                element_index < act_base_w + 32'(k_in_tile_w))
                                a_tile[load_row_r][element_index-act_base_w] <=
                                    act_rsp_data[16*lane +: 16];
                            element_index = (weight_word_w << 3) + 32'(lane);
                            if (weight_needed_w && element_index >= weight_base_w &&
                                element_index < weight_base_w + 32'(k_in_tile_w))
                                w_tile[load_row_r][element_index-weight_base_w] <=
                                    weight_rsp_data[16*lane +: 16];
                        end
                        if (load_word_r == 2) begin
                            load_word_r <= '0;
                            if (load_row_r == 15) begin
                                run_cycle_r <= '0; state_r <= RUN;
                            end else begin load_row_r <= load_row_r + 1'b1; state_r <= LOAD_REQ; end
                        end else begin load_word_r <= load_word_r + 1'b1; state_r <= LOAD_REQ; end
                    end
                end
                RUN: if (run_cycle_r == 6'(k_in_tile_w + 31)) begin
                    if (k_base_r + 11'(k_in_tile_w) < k_total_r) begin
                        k_base_r <= k_base_r + 11'(k_in_tile_w);
                        load_row_r <= '0; load_word_r <= '0;
                        state_r <= LOAD_REQ;
                    end else if (nonfinite_any_w) begin
                        error_r <= 1'b1; state_r <= DONE;
                    end else begin
                        out_row_r <= '0; out_col_r <= '0;
                        state_r <= ROUND_ABS;
                    end
                end else run_cycle_r <= run_cycle_r + 1'b1;
                ROUND_ABS: begin
                    sign_r <= pe_acc[out_row_r][out_col_r][35];
                    magnitude_r <= pe_acc[out_row_r][out_col_r][35] ?
                        $unsigned(-pe_acc[out_row_r][out_col_r]) :
                        $unsigned(pe_acc[out_row_r][out_col_r]);
                    round_scale_r <= pe_scale[out_row_r][out_col_r];
                    state_r <= ROUND_HIGH;
                end
                ROUND_HIGH: begin
                    high_r <= '0;
                    for (integer bit_index = 0; bit_index < 36; bit_index++)
                        if (magnitude_r[bit_index]) high_r <= 6'(bit_index);
                    state_r <= ROUND_PACK;
                end
                ROUND_PACK: begin
                    result_r <= bf16_from_parts(magnitude_r, sign_r, high_r,
                                                round_scale_r);
                    state_r <= WRITE;
                end
                WRITE: if (dst_write_ready) begin
                    if (out_col_r + 1 == cols_in_tile_w) begin
                        out_col_r <= '0;
                        if (out_row_r + 1 == rows_in_tile_w) begin
                            if (row_base_r + 6'(rows_in_tile_w) < m_count_r) begin
                                row_base_r <= row_base_r + 6'(rows_in_tile_w);
                                state_r <= TILE_CLEAR;
                            end else if (col_base_r + 8'(cols_in_tile_w) < n_tile_r) begin
                                col_base_r <= col_base_r + 8'(cols_in_tile_w);
                                row_base_r <= '0;
                                state_r <= TILE_CLEAR;
                            end else state_r <= DONE;
                        end else begin out_row_r <= out_row_r + 1'b1; state_r <= ROUND_ABS; end
                    end else begin out_col_r <= out_col_r + 1'b1; state_r <= ROUND_ABS; end
                end
                DONE: if (done_ready) state_r <= IDLE;
                default: state_r <= IDLE;
            endcase
        end
    end
endmodule
