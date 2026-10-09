`timescale 1ns/1ps

// BF16 residual ADD. One 128-bit word contains eight BF16 lanes; the
// arithmetic is serialized by lane to keep the ZCU104 fabric small.
// Payload [5:0] is the number of 576-element rows (1..32).
module smollm2_add_executor (
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
    output logic left_read_valid,
    input  logic left_read_ready,
    output logic [3:0] left_read_bank,
    output logic [15:0] left_read_addr,
    input  logic left_rsp_valid,
    input  logic [3:0] left_rsp_bank,
    input  logic [127:0] left_rsp_data,
    output logic right_read_valid,
    input  logic right_read_ready,
    output logic [3:0] right_read_bank,
    output logic [15:0] right_read_addr,
    input  logic right_rsp_valid,
    input  logic [3:0] right_rsp_bank,
    input  logic [127:0] right_rsp_data,
    output logic dst_write_valid,
    input  logic dst_write_ready,
    output logic [3:0] dst_write_bank,
    output logic [15:0] dst_write_addr,
    output logic [15:0] dst_write_strb,
    output logic [127:0] dst_write_data
);
    typedef enum logic [3:0] {
        IDLE, LEFT_REQ, LEFT_WAIT, RIGHT_REQ, RIGHT_WAIT,
        ADD_DECODE, ADD_ALIGN, ADD_SUM, ADD_NORM, ADD_ROUND, ADD_PACK,
        WRITE_WORD, DONE
    } state_t;
    state_t state_r;
    logic [2:0][3:0] bank_r;
    logic [5:0] rows_r, row_r;
    logic [6:0] word_r;
    logic [2:0] lane_r;
    logic [127:0] left_word_r, right_word_r, result_word_r;
    logic [7:0] left_sig_r, right_sig_r;
    logic [7:0] left_exp_r, right_exp_r, common_exp_r;
    logic left_sign_r, right_sign_r, result_sign_r;
    logic [63:0] aligned_left_r, aligned_right_r, magnitude_r, rounded_r;
    logic [6:0] high_r;
    logic signed [10:0] exponent_r;
    logic zero_r;
    logic error_r;

    function automatic logic [63:0] shift_sticky(
        input logic [63:0] value, input integer amount);
        logic [63:0] mask;
        begin
            if (amount <= 0) shift_sticky = value;
            else if (amount >= 64) shift_sticky = (value != 0) ? 64'd1 : 0;
            else begin
                mask = (64'd1 << amount) - 1;
                shift_sticky = (value >> amount) |
                    (((value & mask) != 0) ? 64'd1 : 0);
            end
        end
    endfunction

    function automatic logic [63:0] round_shift(
        input logic [63:0] value, input integer amount);
        logic [63:0] quotient, remainder, halfway;
        begin
            if (amount <= 0) round_shift = value << -amount;
            else if (amount >= 64) round_shift = 0;
            else begin
                quotient = value >> amount;
                remainder = value & ((64'd1 << amount) - 1);
                halfway = 64'd1 << (amount - 1);
                round_shift = quotient +
                    ((remainder > halfway ||
                      (remainder == halfway && quotient[0])) ? 64'd1 : 0);
            end
        end
    endfunction

    assign cmd_ready = state_r == IDLE;
    assign done_valid = state_r == DONE;
    assign done_tag = bank_r[0];
    assign done_bank_count = 2'd3;
    assign done_bank = bank_r;
    assign done_error = error_r;
    assign left_read_valid = state_r == LEFT_REQ;
    assign left_read_bank = bank_r[0];
    assign left_read_addr = 16'(32'(row_r)*72 + 32'(word_r));
    assign right_read_valid = state_r == RIGHT_REQ;
    assign right_read_bank = bank_r[1];
    assign right_read_addr = left_read_addr;
    assign dst_write_valid = state_r == WRITE_WORD;
    assign dst_write_bank = bank_r[2];
    assign dst_write_addr = left_read_addr;
    assign dst_write_strb = 16'hffff;
    assign dst_write_data = result_word_r;

    always_ff @(posedge aclk) begin : controller
        integer high;
        if (!aresetn) begin
            state_r <= IDLE; bank_r <= '0; rows_r <= '0;
            row_r <= '0; word_r <= '0; lane_r <= '0;
            left_word_r <= '0; right_word_r <= '0;
            result_word_r <= '0; error_r <= 1'b0;
            left_sig_r <= '0; right_sig_r <= '0;
            left_exp_r <= '0; right_exp_r <= '0; common_exp_r <= '0;
            left_sign_r <= '0; right_sign_r <= '0; result_sign_r <= '0;
            aligned_left_r <= '0; aligned_right_r <= '0;
            magnitude_r <= '0; rounded_r <= '0;
            high_r <= '0; exponent_r <= '0; zero_r <= '0;
        end else case (state_r)
            IDLE: if (cmd_valid) begin
                bank_r <= cmd_bank;
                rows_r <= cmd_payload[5:0];
                row_r <= '0; word_r <= '0; lane_r <= '0;
                error_r <= 1'b0;
                if (cmd_opcode != 4'd9 || cmd_payload[111:6] != '0 ||
                    cmd_payload[5:0] == 0 || cmd_payload[5:0] > 32 ||
                    cmd_bank[0] == cmd_bank[1] ||
                    cmd_bank[0] == cmd_bank[2] ||
                    cmd_bank[1] == cmd_bank[2]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else state_r <= LEFT_REQ;
            end
            LEFT_REQ: if (left_read_ready) state_r <= LEFT_WAIT;
            LEFT_WAIT: if (left_rsp_valid) begin
                if (left_rsp_bank != bank_r[0]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    left_word_r <= left_rsp_data;
                    state_r <= RIGHT_REQ;
                end
            end
            RIGHT_REQ: if (right_read_ready) state_r <= RIGHT_WAIT;
            RIGHT_WAIT: if (right_rsp_valid) begin
                if (right_rsp_bank != bank_r[1]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    right_word_r <= right_rsp_data;
                    lane_r <= '0;
                    state_r <= ADD_DECODE;
                end
            end
            ADD_DECODE: begin
                if (left_word_r[16*lane_r+7 +: 8] == 8'hff ||
                    right_word_r[16*lane_r+7 +: 8] == 8'hff) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    left_sig_r <= {left_word_r[16*lane_r+7 +: 8] != 0,
                                   left_word_r[16*lane_r +: 7]};
                    right_sig_r <= {right_word_r[16*lane_r+7 +: 8] != 0,
                                    right_word_r[16*lane_r +: 7]};
                    left_exp_r <= left_word_r[16*lane_r+7 +: 8] == 0 ?
                                  8'd1 : left_word_r[16*lane_r+7 +: 8];
                    right_exp_r <= right_word_r[16*lane_r+7 +: 8] == 0 ?
                                   8'd1 : right_word_r[16*lane_r+7 +: 8];
                    common_exp_r <=
                        (left_word_r[16*lane_r+7 +: 8] >=
                         right_word_r[16*lane_r+7 +: 8]) ?
                        (left_word_r[16*lane_r+7 +: 8] == 0 ?
                         8'd1 : left_word_r[16*lane_r+7 +: 8]) :
                        (right_word_r[16*lane_r+7 +: 8] == 0 ?
                         8'd1 : right_word_r[16*lane_r+7 +: 8]);
                    left_sign_r <= left_word_r[16*lane_r+15];
                    right_sign_r <= right_word_r[16*lane_r+15];
                    state_r <= ADD_ALIGN;
                end
            end
            ADD_ALIGN: begin
                aligned_left_r <= shift_sticky({56'd0,left_sig_r} << 32,
                                    int'(common_exp_r)-int'(left_exp_r));
                aligned_right_r <= shift_sticky({56'd0,right_sig_r} << 32,
                                     int'(common_exp_r)-int'(right_exp_r));
                state_r <= ADD_SUM;
            end
            ADD_SUM: begin
                if (left_sign_r == right_sign_r) begin
                    magnitude_r <= aligned_left_r + aligned_right_r;
                    result_sign_r <= left_sign_r;
                end else if (aligned_left_r >= aligned_right_r) begin
                    magnitude_r <= aligned_left_r - aligned_right_r;
                    result_sign_r <= left_sign_r;
                end else begin
                    magnitude_r <= aligned_right_r - aligned_left_r;
                    result_sign_r <= right_sign_r;
                end
                state_r <= ADD_NORM;
            end
            ADD_NORM: begin
                high = -1;
                for (int i=0; i<64; i++) if (magnitude_r[i]) high = i;
                high_r <= high < 0 ? 7'd0 : 7'(high);
                zero_r <= high < 0;
                exponent_r <= 11'($signed({1'b0,common_exp_r}) +
                                   high - 39);
                state_r <= ADD_ROUND;
            end
            ADD_ROUND: begin
                rounded_r <= zero_r ? 64'd0 :
                    exponent_r > 0 ?
                    round_shift(magnitude_r, int'(high_r)-7) :
                    round_shift(magnitude_r, 33-int'(common_exp_r));
                state_r <= ADD_PACK;
            end
            ADD_PACK: begin
                if (zero_r)
                    result_word_r[16*lane_r +: 16] <=
                        {left_sign_r & right_sign_r, 15'd0};
                else if (exponent_r >= 255 ||
                         (exponent_r > 0 && rounded_r >= 64'd256 &&
                          exponent_r >= 254))
                    result_word_r[16*lane_r +: 16] <=
                        {result_sign_r, 8'hff, 7'd0};
                else if (exponent_r > 0)
                    result_word_r[16*lane_r +: 16] <=
                        {result_sign_r,
                         8'(exponent_r + (rounded_r >= 64'd256)),
                         (rounded_r >= 64'd256 ? 7'd0 : rounded_r[6:0])};
                else if (rounded_r >= 64'd128)
                    result_word_r[16*lane_r +: 16] <=
                        {result_sign_r, 8'd1, 7'd0};
                else
                    result_word_r[16*lane_r +: 16] <=
                        {result_sign_r, 8'd0, rounded_r[6:0]};
                if (lane_r == 3'd7) state_r <= WRITE_WORD;
                else begin
                    lane_r <= lane_r + 1'b1;
                    state_r <= ADD_DECODE;
                end
            end
            WRITE_WORD: if (dst_write_ready) begin
                if (word_r == 7'd71) begin
                    word_r <= '0;
                    if (row_r + 1'b1 == rows_r) state_r <= DONE;
                    else begin
                        row_r <= row_r + 1'b1;
                        state_r <= LEFT_REQ;
                    end
                end else begin
                    word_r <= word_r + 1'b1;
                    state_r <= LEFT_REQ;
                end
            end
            DONE: if (done_ready) state_r <= IDLE;
            default: state_r <= IDLE;
        endcase
    end
endmodule
