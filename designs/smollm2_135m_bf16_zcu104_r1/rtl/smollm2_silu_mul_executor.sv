`timescale 1ns/1ps

// BF16 SiLU(gate) * up, one lane at a time. A 128-bit bank word holds eight
// BF16 values; each of 1..32 rows contains 1536 values (192 words).
module smollm2_silu_mul_executor (
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
    output logic gate_read_valid,
    input  logic gate_read_ready,
    output logic [3:0] gate_read_bank,
    output logic [15:0] gate_read_addr,
    input  logic gate_rsp_valid,
    input  logic [3:0] gate_rsp_bank,
    input  logic [127:0] gate_rsp_data,
    output logic up_read_valid,
    input  logic up_read_ready,
    output logic [3:0] up_read_bank,
    output logic [15:0] up_read_addr,
    input  logic up_rsp_valid,
    input  logic [3:0] up_rsp_bank,
    input  logic [127:0] up_rsp_data,
    output logic dst_write_valid,
    input  logic dst_write_ready,
    output logic [3:0] dst_write_bank,
    output logic [15:0] dst_write_addr,
    output logic [15:0] dst_write_strb,
    output logic [127:0] dst_write_data
);
    typedef enum logic [3:0] {
        IDLE, GATE_REQ, GATE_WAIT, UP_REQ, UP_WAIT, LOOKUP,
        MUL_DECODE, MUL_PRODUCT, MUL_NORM, MUL_ROUND, MUL_PACK,
        WRITE_WORD, DONE
    } state_t;
    state_t state_r;
    logic [2:0][3:0] bank_r;
    logic [5:0] rows_r, row_r;
    logic [7:0] word_r;
    logic [2:0] lane_r;
    logic [127:0] gate_word_r, up_word_r, result_word_r;
    (* rom_style = "block" *) logic [15:0] silu_rom [0:65535];
    logic [15:0] silu_bits_r;
    logic [7:0] gate_sig_r, up_sig_r, gate_exp_r, up_exp_r;
    logic result_sign_r, zero_r;
    (* use_dsp = "yes" *) logic [15:0] product_r;
    logic [4:0] high_r;
    logic signed [10:0] exponent_r;
    logic [31:0] rounded_r;
    logic error_r;

    initial $readmemh("smollm2_silu_bf16_lut.mem", silu_rom);

    function automatic logic [31:0] round_shift(
        input logic [31:0] value, input integer amount);
        logic [31:0] quotient, remainder, halfway;
        begin
            if (amount <= 0) round_shift = value << -amount;
            else if (amount >= 32) round_shift = 0;
            else begin
                quotient = value >> amount;
                remainder = value & ((32'd1 << amount) - 1);
                halfway = 32'd1 << (amount - 1);
                round_shift = quotient +
                    ((remainder > halfway ||
                      (remainder == halfway && quotient[0])) ? 32'd1 : 0);
            end
        end
    endfunction

    assign cmd_ready = state_r == IDLE;
    assign done_valid = state_r == DONE;
    assign done_tag = bank_r[0];
    assign done_bank_count = 2'd3;
    assign done_bank = bank_r;
    assign done_error = error_r;
    assign gate_read_valid = state_r == GATE_REQ;
    assign gate_read_bank = bank_r[0];
    assign gate_read_addr = 16'(32'(row_r)*192 + 32'(word_r));
    assign up_read_valid = state_r == UP_REQ;
    assign up_read_bank = bank_r[1];
    assign up_read_addr = gate_read_addr;
    assign dst_write_valid = state_r == WRITE_WORD;
    assign dst_write_bank = bank_r[2];
    assign dst_write_addr = gate_read_addr;
    assign dst_write_strb = 16'hffff;
    assign dst_write_data = result_word_r;

    always_ff @(posedge aclk) begin : controller
        integer high;
        if (!aresetn) begin
            state_r <= IDLE; bank_r <= '0; rows_r <= '0;
            row_r <= '0; word_r <= '0; lane_r <= '0;
            gate_word_r <= '0; up_word_r <= '0; result_word_r <= '0;
            silu_bits_r <= '0; gate_sig_r <= '0; up_sig_r <= '0;
            gate_exp_r <= '0; up_exp_r <= '0;
            result_sign_r <= '0; zero_r <= '0; product_r <= '0;
            high_r <= '0; exponent_r <= '0; rounded_r <= '0;
            error_r <= 1'b0;
        end else case (state_r)
            IDLE: if (cmd_valid) begin
                bank_r <= cmd_bank;
                rows_r <= cmd_payload[5:0];
                row_r <= '0; word_r <= '0; lane_r <= '0;
                error_r <= 1'b0;
                if (cmd_opcode != 4'd10 || cmd_payload[111:6] != '0 ||
                    cmd_payload[5:0] == 0 || cmd_payload[5:0] > 32 ||
                    cmd_bank[0] == cmd_bank[1] ||
                    cmd_bank[0] == cmd_bank[2] ||
                    cmd_bank[1] == cmd_bank[2]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else state_r <= GATE_REQ;
            end
            GATE_REQ: if (gate_read_ready) state_r <= GATE_WAIT;
            GATE_WAIT: if (gate_rsp_valid) begin
                if (gate_rsp_bank != bank_r[0]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    gate_word_r <= gate_rsp_data;
                    state_r <= UP_REQ;
                end
            end
            UP_REQ: if (up_read_ready) state_r <= UP_WAIT;
            UP_WAIT: if (up_rsp_valid) begin
                if (up_rsp_bank != bank_r[1]) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    up_word_r <= up_rsp_data;
                    lane_r <= '0;
                    state_r <= LOOKUP;
                end
            end
            LOOKUP: begin
                if (gate_word_r[16*lane_r+7 +: 8] == 8'hff ||
                    up_word_r[16*lane_r+7 +: 8] == 8'hff) begin
                    error_r <= 1'b1; state_r <= DONE;
                end else begin
                    silu_bits_r <= silu_rom[gate_word_r[16*lane_r +: 16]];
                    state_r <= MUL_DECODE;
                end
            end
            MUL_DECODE: begin
                gate_sig_r <= {silu_bits_r[14:7] != 0,
                               silu_bits_r[6:0]};
                up_sig_r <= {up_word_r[16*lane_r+7 +: 8] != 0,
                             up_word_r[16*lane_r +: 7]};
                gate_exp_r <= silu_bits_r[14:7] == 0 ? 8'd1 :
                              silu_bits_r[14:7];
                up_exp_r <= up_word_r[16*lane_r+7 +: 8] == 0 ? 8'd1 :
                            up_word_r[16*lane_r+7 +: 8];
                result_sign_r <= silu_bits_r[15] ^ up_word_r[16*lane_r+15];
                state_r <= MUL_PRODUCT;
            end
            MUL_PRODUCT: begin
                product_r <= gate_sig_r * up_sig_r;
                state_r <= MUL_NORM;
            end
            MUL_NORM: begin
                high = -1;
                for (int i=0; i<16; i++) if (product_r[i]) high = i;
                high_r <= high < 0 ? 5'd0 : 5'(high);
                zero_r <= high < 0;
                exponent_r <= 11'($signed({1'b0,gate_exp_r}) +
                                  $signed({1'b0,up_exp_r}) + high - 141);
                state_r <= MUL_ROUND;
            end
            MUL_ROUND: begin
                rounded_r <= zero_r ? 32'd0 : exponent_r > 0 ?
                    round_shift({16'd0,product_r}, int'(high_r)-7) :
                    round_shift({16'd0,product_r},
                                135-int'(gate_exp_r)-int'(up_exp_r));
                state_r <= MUL_PACK;
            end
            MUL_PACK: begin
                if (zero_r)
                    result_word_r[16*lane_r +: 16] <=
                        {result_sign_r, 15'd0};
                else if (exponent_r >= 255 ||
                         (exponent_r > 0 && rounded_r >= 32'd256 &&
                          exponent_r >= 254))
                    result_word_r[16*lane_r +: 16] <=
                        {result_sign_r, 8'hff, 7'd0};
                else if (exponent_r > 0)
                    result_word_r[16*lane_r +: 16] <=
                        {result_sign_r,
                         8'(exponent_r + (rounded_r >= 32'd256)),
                         (rounded_r >= 32'd256 ? 7'd0 : rounded_r[6:0])};
                else if (rounded_r >= 32'd128)
                    result_word_r[16*lane_r +: 16] <=
                        {result_sign_r, 8'd1, 7'd0};
                else
                    result_word_r[16*lane_r +: 16] <=
                        {result_sign_r, 8'd0, rounded_r[6:0]};
                if (lane_r == 3'd7) state_r <= WRITE_WORD;
                else begin
                    lane_r <= lane_r + 1'b1;
                    state_r <= LOOKUP;
                end
            end
            WRITE_WORD: if (dst_write_ready) begin
                if (word_r == 8'd191) begin
                    word_r <= '0;
                    if (row_r + 1'b1 == rows_r) state_r <= DONE;
                    else begin
                        row_r <= row_r + 1'b1;
                        state_r <= GATE_REQ;
                    end
                end else begin
                    word_r <= word_r + 1'b1;
                    state_r <= GATE_REQ;
                end
            end
            DONE: if (done_ready) state_r <= IDLE;
            default: state_r <= IDLE;
        endcase
    end
endmodule
