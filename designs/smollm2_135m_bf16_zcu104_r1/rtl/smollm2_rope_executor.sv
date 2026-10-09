`timescale 1ns/1ps

// SmolLM2 rotary embedding, 1..32 rows, in-place Q (B4, 9 heads) or K
// (B5, 3 heads). A row has 64 BF16 values per head. B7 holds, for each row,
// 32 BF16 cos values followed by 32 BF16 sin values. The two data words of
// each half-head pair are read before either word is overwritten.
module smollm2_rope_executor (
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
    output logic coeff_read_valid,
    input  logic coeff_read_ready,
    output logic [3:0] coeff_read_bank,
    output logic [15:0] coeff_read_addr,
    input  logic coeff_rsp_valid,
    input  logic [3:0] coeff_rsp_bank,
    input  logic [127:0] coeff_rsp_data,
    output logic data_write_valid,
    input  logic data_write_ready,
    output logic [3:0] data_write_bank,
    output logic [15:0] data_write_addr,
    output logic [15:0] data_write_strb,
    output logic [127:0] data_write_data
);
    typedef enum logic [4:0] {
        IDLE, LOW_REQ, LOW_WAIT, HIGH_REQ, HIGH_WAIT,
        COS_REQ, COS_WAIT, SIN_REQ, SIN_WAIT,
        MULT, MULT_PACK, ADD, ABS, NORM, PACK,
        LOW_WRITE, HIGH_WRITE, DONE
    } state_t;
    state_t state_r;
    logic [2:0][3:0] bank_r;
    logic [5:0] rows_r, row_r;
    logic [3:0] head_r, head_count_r;
    logic [1:0] pair_r;
    logic [2:0] lane_r;
    logic [127:0] low_r, high_r, cos_r, sin_r;
    logic [127:0] low_out_r, high_out_r;
    logic [15:0] p_lc_r, p_hs_r, p_hc_r, p_ls_r;
    logic [26:0] raw_lc_r, raw_hs_r, raw_hc_r, raw_ls_r;
    logic [40:0] low_sum_r, high_sum_r;
    logic [31:0] low_mag_r, high_mag_r;
    logic low_sign_r, high_sign_r;
    logic signed [10:0] low_scale_r, high_scale_r;
    logic signed [5:0] low_high_r, high_high_r;
    logic error_r;
    logic [15:0] low_addr_w, high_addr_w;

    // A finite BF16 value is significand * 2^(effective_exponent - 134).
    // This rounds a nonnegative integer times 2^scale to BF16, ties to even.
    // Subnormal output underflows to signed zero, matching the RMSNorm
    // executor's current numerical domain.
    function automatic logic signed [5:0] highest_one(
        input logic [31:0] magnitude
    );
        begin
            highest_one = -1;
            for (int i = 0; i < 32; i++) if (magnitude[i]) highest_one = 6'(i);
        end
    endfunction

    function automatic logic [15:0] pack_scaled_with_high(
        input logic sign, input logic [31:0] magnitude,
        input integer scale, input logic signed [5:0] high_bit
    );
        integer high, shift, exponent;
        logic [31:0] chopped, remainder, halfway;
        logic [8:0] rounded;
        begin
            high = int'($signed(high_bit));
            if (high < 0) pack_scaled_with_high = {sign, 15'd0};
            else begin
                exponent = scale + high + 127;
                shift = high - 7;
                if (shift > 0) begin
                    chopped = magnitude >> shift;
                    remainder = magnitude & ((32'd1 << shift) - 1);
                    halfway = 32'd1 << (shift - 1);
                    rounded = {1'b0, chopped[7:0]} +
                        ((remainder > halfway ||
                          (remainder == halfway && chopped[0])) ? 9'd1 : 9'd0);
                end else rounded = 9'((magnitude << -shift) & 32'hff);
                if (rounded[8]) begin
                    rounded = 9'h080;
                    exponent = exponent + 1;
                end
                if (exponent >= 255) pack_scaled_with_high = {sign, 8'hff, 7'd0};
                else if (exponent <= 0) pack_scaled_with_high = {sign, 15'd0};
                else pack_scaled_with_high = {sign, 8'(exponent), rounded[6:0]};
            end
        end
    endfunction

    function automatic logic [15:0] pack_scaled(
        input logic sign, input logic [31:0] magnitude, input integer scale
    );
        pack_scaled = pack_scaled_with_high(sign, magnitude, scale,
                                            highest_one(magnitude));
    endfunction

    function automatic logic [26:0] bf16_mul_unrounded(
        input logic [15:0] a, input logic [15:0] b
    );
        logic [7:0] sa, sb;
        logic [15:0] product;
        integer ea, eb;
        begin
            sa = {(a[14:7] != 0), a[6:0]};
            sb = {(b[14:7] != 0), b[6:0]};
            ea = a[14:7] == 0 ? 1 : int'(a[14:7]);
            eb = b[14:7] == 0 ? 1 : int'(b[14:7]);
            product = sa * sb;
            bf16_mul_unrounded = {a[15] ^ b[15],
                                  10'(ea + eb - 268), product};
        end
    endfunction

    function automatic logic [15:0] bf16_mul_pack(input logic [26:0] value);
        bf16_mul_pack = pack_scaled(value[26], {16'd0, value[15:0]},
                                    int'($signed(value[25:16])));
    endfunction

    function automatic logic [31:0] shr_sticky(
        input logic [31:0] v, input integer sh
    );
        logic [31:0] mask;
        begin
            if (sh <= 0) shr_sticky = v;
            else if (sh >= 32) shr_sticky = {31'd0, |v};
            else begin
                mask = (32'd1 << sh) - 1;
                shr_sticky = (v >> sh) | {31'd0, |(v & mask)};
            end
        end
    endfunction

    // Register the aligned signed sum before normalization and rounding.
    function automatic logic [40:0] bf16_add_unrounded(
        input logic [15:0] a, input logic [15:0] b
    );
        integer ea, eb, common_exp;
        logic [31:0] ma, mb;
        logic signed [32:0] signed_a, signed_b, sum;
        begin
            ea = a[14:7] == 0 ? 1 : int'(a[14:7]);
            eb = b[14:7] == 0 ? 1 : int'(b[14:7]);
            common_exp = ea > eb ? ea : eb;
            ma = shr_sticky({12'd0, (a[14:7] != 0), a[6:0], 12'd0},
                            common_exp - ea);
            mb = shr_sticky({12'd0, (b[14:7] != 0), b[6:0], 12'd0},
                            common_exp - eb);
            signed_a = a[15] ? -$signed({1'b0, ma}) : $signed({1'b0, ma});
            signed_b = b[15] ? -$signed({1'b0, mb}) : $signed({1'b0, mb});
            sum = signed_a + signed_b;
            bf16_add_unrounded = {8'(common_exp), sum};
        end
    endfunction

    assign cmd_ready = state_r == IDLE;
    assign done_valid = state_r == DONE;
    assign done_tag = bank_r[0];
    assign done_bank_count = 2'd2;
    assign done_bank = bank_r;
    assign done_error = error_r;
    assign low_addr_w = 16'(32'(row_r) *
                           (bank_r[0] == 4'd4 ? 72 : 24) +
                           32'(head_r) * 8 + 32'(pair_r));
    assign high_addr_w = low_addr_w + 16'd4;
    assign data_read_valid = state_r == LOW_REQ || state_r == HIGH_REQ;
    assign data_read_bank = bank_r[0];
    assign data_read_addr = state_r == HIGH_REQ ? high_addr_w : low_addr_w;
    assign coeff_read_valid = state_r == COS_REQ || state_r == SIN_REQ;
    assign coeff_read_bank = bank_r[1];
    assign coeff_read_addr = 16'(32'(row_r) * 8 + 32'(pair_r) +
                                 (state_r == SIN_REQ ? 4 : 0));
    assign data_write_valid = state_r == LOW_WRITE || state_r == HIGH_WRITE;
    assign data_write_bank = bank_r[0];
    assign data_write_addr = state_r == HIGH_WRITE ? high_addr_w : low_addr_w;
    assign data_write_strb = 16'hffff;
    assign data_write_data = state_r == HIGH_WRITE ? high_out_r : low_out_r;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE; bank_r <= '0; rows_r <= '0; row_r <= '0;
            head_r <= '0; head_count_r <= '0; pair_r <= '0; lane_r <= '0;
            low_r <= '0; high_r <= '0; cos_r <= '0; sin_r <= '0;
            low_out_r <= '0; high_out_r <= '0;
            p_lc_r <= '0; p_hs_r <= '0; p_hc_r <= '0; p_ls_r <= '0;
            raw_lc_r <= '0; raw_hs_r <= '0;
            raw_hc_r <= '0; raw_ls_r <= '0;
            low_sum_r <= '0; high_sum_r <= '0;
            low_mag_r <= '0; high_mag_r <= '0;
            low_sign_r <= 1'b0; high_sign_r <= 1'b0;
            low_scale_r <= '0; high_scale_r <= '0;
            low_high_r <= '0; high_high_r <= '0;
            error_r <= 1'b0;
        end else case (state_r)
            IDLE: if (cmd_valid) begin
                bank_r <= cmd_bank;
                rows_r <= cmd_payload[5:0]; row_r <= '0;
                head_r <= '0; pair_r <= '0; lane_r <= '0;
                head_count_r <= cmd_bank[0] == 4'd4 ? 4'd9 : 4'd3;
                error_r <= 1'b0;
                if (cmd_opcode != 4'd5 ||
                    (cmd_bank[0] != 4'd4 && cmd_bank[0] != 4'd5 &&
                     cmd_bank[0] != 4'd8) ||
                    cmd_bank[1] != 4'd7 || cmd_bank[2] != 4'd0 ||
                    cmd_payload[111:6] != '0 || cmd_payload[5:0] == 0 ||
                    cmd_payload[5:0] > 6'd32) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else state_r <= LOW_REQ;
            end
            LOW_REQ: if (data_read_ready) state_r <= LOW_WAIT;
            LOW_WAIT: if (data_rsp_valid) begin
                if (data_rsp_bank != bank_r[0]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin low_r <= data_rsp_data; state_r <= HIGH_REQ; end
            end
            HIGH_REQ: if (data_read_ready) state_r <= HIGH_WAIT;
            HIGH_WAIT: if (data_rsp_valid) begin
                if (data_rsp_bank != bank_r[0]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin high_r <= data_rsp_data; state_r <= COS_REQ; end
            end
            COS_REQ: if (coeff_read_ready) state_r <= COS_WAIT;
            COS_WAIT: if (coeff_rsp_valid) begin
                if (coeff_rsp_bank != bank_r[1]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin cos_r <= coeff_rsp_data; state_r <= SIN_REQ; end
            end
            SIN_REQ: if (coeff_read_ready) state_r <= SIN_WAIT;
            SIN_WAIT: if (coeff_rsp_valid) begin
                if (coeff_rsp_bank != bank_r[1]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin sin_r <= coeff_rsp_data; lane_r <= '0;
                               state_r <= MULT; end
            end
            MULT: begin
                if (low_r[16*lane_r+7 +: 8] == 8'hff ||
                    high_r[16*lane_r+7 +: 8] == 8'hff ||
                    cos_r[16*lane_r+7 +: 8] == 8'hff ||
                    sin_r[16*lane_r+7 +: 8] == 8'hff) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    raw_lc_r <= bf16_mul_unrounded(
                        low_r[16*lane_r +: 16], cos_r[16*lane_r +: 16]);
                    raw_hs_r <= bf16_mul_unrounded(
                        high_r[16*lane_r +: 16], sin_r[16*lane_r +: 16]);
                    raw_hc_r <= bf16_mul_unrounded(
                        high_r[16*lane_r +: 16], cos_r[16*lane_r +: 16]);
                    raw_ls_r <= bf16_mul_unrounded(
                        low_r[16*lane_r +: 16], sin_r[16*lane_r +: 16]);
                    state_r <= MULT_PACK;
                end
            end
            MULT_PACK: begin
                p_lc_r <= bf16_mul_pack(raw_lc_r);
                p_hs_r <= bf16_mul_pack(raw_hs_r);
                p_hc_r <= bf16_mul_pack(raw_hc_r);
                p_ls_r <= bf16_mul_pack(raw_ls_r);
                state_r <= ADD;
            end
            ADD: begin
                low_sum_r <= bf16_add_unrounded(
                    p_lc_r, {~p_hs_r[15], p_hs_r[14:0]});
                high_sum_r <= bf16_add_unrounded(p_hc_r, p_ls_r);
                state_r <= ABS;
            end
            ABS: begin
                low_sign_r <= low_sum_r[32];
                high_sign_r <= high_sum_r[32];
                low_mag_r <= low_sum_r[32] ? 32'(-$signed(low_sum_r[32:0])) :
                                              low_sum_r[31:0];
                high_mag_r <= high_sum_r[32] ? 32'(-$signed(high_sum_r[32:0])) :
                                                high_sum_r[31:0];
                low_scale_r <= 11'($signed({3'd0, low_sum_r[40:33]}) - 146);
                high_scale_r <= 11'($signed({3'd0, high_sum_r[40:33]}) - 146);
                state_r <= NORM;
            end
            NORM: begin
                low_high_r <= highest_one(low_mag_r);
                high_high_r <= highest_one(high_mag_r);
                state_r <= PACK;
            end
            PACK: begin
                low_out_r[16*lane_r +: 16] <=
                    pack_scaled_with_high(low_sign_r, low_mag_r,
                                          int'($signed(low_scale_r)), low_high_r);
                high_out_r[16*lane_r +: 16] <=
                    pack_scaled_with_high(high_sign_r, high_mag_r,
                                          int'($signed(high_scale_r)), high_high_r);
                if (lane_r == 3'd7) state_r <= LOW_WRITE;
                else begin lane_r <= lane_r + 1'b1; state_r <= MULT; end
            end
            LOW_WRITE: if (data_write_ready) state_r <= HIGH_WRITE;
            HIGH_WRITE: if (data_write_ready) begin
                if (pair_r == 2'd3) begin
                    pair_r <= '0;
                    if (head_r + 1'b1 == head_count_r) begin
                        head_r <= '0;
                        if (row_r + 1'b1 == rows_r) state_r <= DONE;
                        else begin row_r <= row_r + 1'b1; state_r <= LOW_REQ; end
                    end else begin head_r <= head_r + 1'b1; state_r <= LOW_REQ; end
                end else begin pair_r <= pair_r + 1'b1; state_r <= LOW_REQ; end
            end
            DONE: if (done_ready) state_r <= IDLE;
            default: state_r <= IDLE;
        endcase
    end
endmodule
