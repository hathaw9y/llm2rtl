`timescale 1ns/1ps

module isa_command_dispatcher #(
    parameter integer AXI_ADDR_WIDTH    = 32,
    parameter integer BTT_WIDTH         = 23,
    parameter integer BANK_NUM          = 16,
    parameter integer BANK_NUM_WIDTH    = 4,
    parameter integer TAG_WIDTH         = 4,
    parameter integer BANK_ADDR_WIDTH   = 32,
    parameter integer CMD_ADDR_WIDTH    = 10,
    parameter integer CMD_READ_LATENCY  = 2,
    parameter integer CMD_DATA_WIDTH    = 128,
    parameter integer MAX_COMMANDS      = 1024,
    parameter integer OPCODE_WIDTH      = 4,
    parameter integer PORT_ROLE_WIDTH   = 3,
    parameter bit ALLOW_ZERO_RMS_PROBE   = 1'b0
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic cmd_dispatcher_start,
    output logic cmd_dispatcher_busy,
    output logic cmd_dispatcher_done,
    output logic cmd_dispatcher_error,
    output logic [7:0] cmd_dispatcher_error_code,
    output logic [18:0] profile_events,
    output logic [CMD_ADDR_WIDTH-1:0] current_pc,

    output logic cmd_enb,
    output logic [CMD_ADDR_WIDTH-1:0] cmd_addrb,
    input  logic [CMD_DATA_WIDTH-1:0] cmd_doutb,

    output logic m_ctrl_mm2s_cmd_valid,
    input  logic m_ctrl_mm2s_cmd_ready,
    output logic [AXI_ADDR_WIDTH-1:0] m_ctrl_mm2s_cmd_addr,
    output logic [BTT_WIDTH-1:0] m_ctrl_mm2s_cmd_btt,
    output logic [BANK_ADDR_WIDTH-1:0] m_ctrl_mm2s_cmd_offset,
    output logic [BANK_NUM_WIDTH-1:0] m_ctrl_mm2s_cmd_bank,
    output logic [TAG_WIDTH-1:0] m_ctrl_mm2s_cmd_tag,
    input  logic s_ctrl_mm2s_sts_valid,
    output logic m_ctrl_mm2s_sts_ready,
    input  logic [TAG_WIDTH-1:0] s_ctrl_mm2s_sts_tag,
    input  logic s_ctrl_mm2s_sts_error,

    output logic m_ctrl_s2mm_cmd_valid,
    input  logic m_ctrl_s2mm_cmd_ready,
    output logic [AXI_ADDR_WIDTH-1:0] m_ctrl_s2mm_cmd_addr,
    output logic [BTT_WIDTH-1:0] m_ctrl_s2mm_cmd_btt,
    output logic [BANK_ADDR_WIDTH-1:0] m_ctrl_s2mm_cmd_offset,
    output logic [BANK_NUM_WIDTH-1:0] m_ctrl_s2mm_cmd_bank,
    output logic [TAG_WIDTH-1:0] m_ctrl_s2mm_cmd_tag,
    input  logic s_ctrl_s2mm_sts_valid,
    output logic m_ctrl_s2mm_sts_ready,
    input  logic [TAG_WIDTH-1:0] s_ctrl_s2mm_sts_tag,
    input  logic s_ctrl_s2mm_sts_error,

    /* verilator lint_off LITENDIAN */
    output logic [0:BANK_NUM-1] bank_acquire_valid,
    output logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_acquire_port,
    output logic [0:BANK_NUM-1] bank_release_valid,
    output logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_release_port,
    input  logic [0:BANK_NUM-1] bank_busy,
    input  logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_owner_port
    /* verilator lint_on LITENDIAN */

    // USER_PORTS_BEGIN
    ,
    input  logic [BANK_NUM-1:0] bank_tensor_valid,
    input  logic bank_tensor_state_error,
    output logic [BANK_NUM-1:0] wr_issue_valid,
    output logic [BANK_NUM-1:0][1:0] wr_issue_kind,
    output logic [BANK_NUM-1:0][15:0] wr_issue_index,
    output logic [BANK_NUM-1:0][15:0] wr_issue_count,
    output logic [BANK_NUM-1:0][15:0] wr_issue_total,
    output logic [BANK_NUM-1:0] wr_complete_valid,
    output logic [BANK_NUM-1:0] wr_complete_error,
    output logic [6:0] compute_cmd_valid,
    input  logic [6:0] compute_cmd_ready,
    output logic [6:0][OPCODE_WIDTH-1:0] compute_cmd_opcode,
    output logic [6:0][2:0][BANK_NUM_WIDTH-1:0] compute_cmd_bank,
    output logic [6:0][111:0] compute_cmd_payload,
    input  logic [6:0] compute_done_valid,
    output logic [6:0] compute_done_ready,
    input  logic [6:0][BANK_NUM_WIDTH-1:0] compute_done_tag,
    input  logic [6:0][1:0] compute_done_bank_count,
    input  logic [6:0][2:0][BANK_NUM_WIDTH-1:0] compute_done_bank,
    input  logic [6:0] compute_done_error
    // USER_PORTS_END
);

    // USER_PARAMETERS_BEGIN
    // Seven physical compute channels, one in-flight command per channel.
    // USER_PARAMETERS_END

    localparam integer REQUIRED_CMD_WIDTH = OPCODE_WIDTH +
                                            (3 * BANK_NUM_WIDTH) +
                                            BANK_ADDR_WIDTH + BTT_WIDTH +
                                            AXI_ADDR_WIDTH;
    localparam integer FETCH_COUNT_WIDTH =
        (CMD_READ_LATENCY < 2) ? 1 : $clog2(CMD_READ_LATENCY + 1);
    localparam integer REQUIRED_BANK_NUM_WIDTH =
        (BANK_NUM <= 1) ? 1 : $clog2(BANK_NUM);
    localparam integer REQUIRED_CMD_ADDR_WIDTH =
        (MAX_COMMANDS <= 1) ? 1 : $clog2(MAX_COMMANDS);
    localparam logic [FETCH_COUNT_WIDTH-1:0] FETCH_LATENCY_COUNT =
        FETCH_COUNT_WIDTH'(CMD_READ_LATENCY);
    localparam logic [CMD_ADDR_WIDTH-1:0] LAST_PC =
        CMD_ADDR_WIDTH'(MAX_COMMANDS - 1);
    localparam logic [BANK_NUM_WIDTH:0] BANK_NUM_LIMIT =
        (BANK_NUM_WIDTH + 1)'(BANK_NUM);
    localparam logic [TAG_WIDTH:0] TAG_BANK_NUM_LIMIT =
        (TAG_WIDTH + 1)'(BANK_NUM);
    localparam logic PARAMETERS_LEGAL =
        (BANK_NUM >= 1) &&
        (BANK_NUM_WIDTH >= REQUIRED_BANK_NUM_WIDTH) &&
        (TAG_WIDTH >= BANK_NUM_WIDTH) &&
        (CMD_READ_LATENCY >= 1) &&
        (MAX_COMMANDS >= 1) &&
        (CMD_ADDR_WIDTH >= REQUIRED_CMD_ADDR_WIDTH) &&
        (CMD_DATA_WIDTH >= REQUIRED_CMD_WIDTH) &&
        (PORT_ROLE_WIDTH >= 3) &&
        (OPCODE_WIDTH >= 2);

    localparam integer OPCODE_LSB = CMD_DATA_WIDTH - OPCODE_WIDTH;
    localparam integer OPERAND0_LSB = OPCODE_LSB - BANK_NUM_WIDTH;
    localparam integer OPERAND1_LSB = OPERAND0_LSB - BANK_NUM_WIDTH;
    localparam integer OPERAND2_LSB = OPERAND1_LSB - BANK_NUM_WIDTH;
    localparam integer LOCAL_OFFSET_LSB = OPERAND2_LSB - BANK_ADDR_WIDTH;
    localparam integer BYTE_COUNT_LSB = LOCAL_OFFSET_LSB - BTT_WIDTH;
    localparam integer AXI_ADDRESS_LSB = BYTE_COUNT_LSB - AXI_ADDR_WIDTH;

    localparam logic [OPCODE_WIDTH-1:0] OP_END  = 0;
    localparam logic [OPCODE_WIDTH-1:0] OP_MM2S = 1;
    localparam logic [OPCODE_WIDTH-1:0] OP_S2MM = 2;
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_MM2S_ARBITER = 1;
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_S2MM_ARBITER = 2;

    // USER_OPCODES_BEGIN
    localparam logic [OPCODE_WIDTH-1:0] OP_GEMM = 3, OP_RMS = 4,
        OP_ROPE = 5, OP_SCORE = 6, OP_SOFTMAX = 7, OP_VALUE = 8,
        OP_ADD = 9, OP_SILU = 10, OP_FENCE = 11, OP_GEMM_TILES = 12;
    // USER_OPCODES_END

    localparam logic [7:0] ERR_NONE        = 8'h00;
    localparam logic [7:0] ERR_OPCODE      = 8'h01;
    localparam logic [7:0] ERR_OPERAND     = 8'h02;
    localparam logic [7:0] ERR_RESPONSE    = 8'h03;
    localparam logic [7:0] ERR_EXECUTOR    = 8'h04;
    localparam logic [7:0] ERR_MISSING_END = 8'h05;
    localparam logic [7:0] ERR_PARAMETER   = 8'h06;

    typedef enum logic [3:0] {
        IDLE,
        FETCH,
        CHECK_COMMAND,
        ISSUE_COMMAND,
        END_DRAIN,
        ERROR_DRAIN,
        DONE_STATE,
        ERROR_STATE
    } state_t;

    state_t state_r;
    logic [CMD_ADDR_WIDTH-1:0] pc_r;
    logic [FETCH_COUNT_WIDTH-1:0] fetch_count_r;
    /* verilator lint_off UNUSED */
    logic [CMD_DATA_WIDTH-1:0] command_r;
    /* verilator lint_on UNUSED */
    logic [7:0] error_code_r;
    logic macro_active_r, macro_gemm_r;
    logic [CMD_DATA_WIDTH-1:0] macro_command_r;
    logic [15:0] macro_n_r;
    logic [31:0] macro_address_r;
    logic macro_legal_w;

    function automatic logic [7:0] macro_tile_width(
        input logic [CMD_DATA_WIDTH-1:0] descriptor,
        input logic [15:0] n_start);
        logic [15:0] remaining;
        begin
            remaining = descriptor[79:64] - n_start;
            macro_tile_width = (remaining >= {8'd0, descriptor[40:33]}) ?
                descriptor[40:33] : remaining[7:0];
        end
    endfunction

    function automatic logic [CMD_DATA_WIDTH-1:0] macro_load_command(
        input logic [CMD_DATA_WIDTH-1:0] descriptor,
        input logic [31:0] address,
        input logic [15:0] n_start);
        logic [31:0] bytes;
        logic [CMD_DATA_WIDTH-1:0] result;
        begin
            bytes = 32'(macro_tile_width(descriptor, n_start)) *
                    32'(descriptor[63:53]) * 32'd2;
            result = '0;
            result[127:124] = OP_MM2S;
            result[123:120] = descriptor[119:116];
            result[79:57] = bytes[22:0];
            result[56:25] = address;
            macro_load_command = result;
        end
    endfunction

    function automatic logic [CMD_DATA_WIDTH-1:0] macro_gemm_command(
        input logic [CMD_DATA_WIDTH-1:0] descriptor,
        input logic [15:0] n_start);
        logic [CMD_DATA_WIDTH-1:0] result;
        begin
            result = '0;
            result[127:124] = OP_GEMM;
            result[123:112] = descriptor[123:112];
            result[62:47] = n_start;
            result[46:31] = descriptor[79:64];
            result[30:25] = descriptor[52:47];
            result[24:19] = descriptor[46:41];
            result[18:8] = descriptor[63:53];
            result[7:0] = macro_tile_width(descriptor, n_start);
            macro_gemm_command = result;
        end
    endfunction

    /* verilator lint_off LITENDIAN */
    logic [0:BANK_NUM-1] pending_mm2s_r;
    logic [0:BANK_NUM-1] pending_s2mm_r;
    /* verilator lint_on LITENDIAN */

    logic [OPCODE_WIDTH-1:0] opcode_w;
    logic [BANK_NUM_WIDTH-1:0] operand0_bank_w;
    /* verilator lint_off UNUSED */
    logic [BANK_NUM_WIDTH-1:0] operand1_bank_w;
    logic [BANK_NUM_WIDTH-1:0] operand2_bank_w;
    /* verilator lint_on UNUSED */
    logic [BANK_ADDR_WIDTH-1:0] local_offset_w;
    logic [BTT_WIDTH-1:0] byte_count_w;
    logic [AXI_ADDR_WIDTH-1:0] axi_address_w;
    logic [TAG_WIDTH-1:0] operand0_tag_w;

    logic fixed_opcode_w;
    logic opcode_known_w;
    logic fixed_command_legal_w;
    logic fixed_bank_eligible_w;
    logic command_legal_w;
    logic bank_in_range_w;
    logic bank_eligible_w;
    logic fixed_request_fire_w;
    logic request_fire_w;
    logic fixed_pending_any_w;
    logic pending_any_w;
    logic busy_any_w;
    logic mm2s_response_match_w;
    logic s2mm_response_match_w;
    logic fixed_response_fault_w;
    logic fixed_executor_fault_w;
    logic response_fault_w;
    logic executor_fault_w;
    /* verilator lint_off LITENDIAN */
    logic [0:BANK_NUM-1] fixed_bank_acquire_valid_w;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] fixed_bank_acquire_port_w;
    logic [0:BANK_NUM-1] fixed_bank_release_valid_w;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] fixed_bank_release_port_w;
    logic [0:BANK_NUM-1] user_bank_acquire_valid_w;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] user_bank_acquire_port_w;
    logic [0:BANK_NUM-1] user_bank_release_valid_w;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] user_bank_release_port_w;
    /* verilator lint_on LITENDIAN */
    logic user_opcode_known_w;
    logic user_command_legal_w;
    logic user_bank_eligible_w;
    logic user_request_valid_w;
    logic user_request_ready_w;
    logic user_request_fire_w;
    logic user_pending_any_w;
    logic user_response_fault_w;
    logic user_executor_fault_w;
    logic [BANK_NUM_WIDTH:0] operand0_index_w;
    logic [TAG_WIDTH:0] mm2s_tag_index_w;
    logic [TAG_WIDTH:0] s2mm_tag_index_w;

    // USER_DECLARATIONS_BEGIN
    localparam integer USER_MARKER_COUNT = 14;
    localparam logic [1:0] WRITE_FULL = 0, WRITE_PART = 1, WRITE_INPLACE = 2;
    logic [6:0] compute_pending_r;
    logic [6:0][2:0][BANK_NUM_WIDTH-1:0] pending_bank_r;
    logic [6:0][2:0][PORT_ROLE_WIDTH-1:0] pending_role_r;
    logic [6:0][1:0] pending_bank_count_r;
    logic [6:0][BANK_NUM_WIDTH-1:0] pending_dst_r;
    logic [6:0] completion_match_w;
    logic [6:0] compute_fire_w;
    logic [2:0] selected_channel_w;
    logic is_compute_w, is_fence_w, source_invalid_w, dma_load_invalid_w;
    logic [1:0] used_bank_count_w;
    logic [BANK_NUM_WIDTH-1:0] write_bank_w;
    logic [1:0] write_kind_w;
    logic [15:0] write_index_w, write_count_w, write_total_w;
    logic [15:0] gemm_n_start_w, gemm_n_total_w;
    logic [7:0] gemm_n_tile_w;
    logic [5:0] gemm_m_start_w, gemm_m_count_w;
    logic [10:0] gemm_k_w;
    logic [9:0] score_q_start_w;
    logic [5:0] score_m_count_w;
    logic [10:0] score_kv_len_w;
    logic [5:0] embedding_row_w, embedding_rows_w;
    logic [BANK_NUM_WIDTH:0] bank1_index_w, bank2_index_w;
    logic all_banks_free_w;

    function automatic logic [PORT_ROLE_WIDTH-1:0] role_for(
        input logic [OPCODE_WIDTH-1:0] op, input integer position);
        case (op)
            OP_GEMM: role_for = PORT_ROLE_WIDTH'(3 + position);
            OP_RMS: role_for = PORT_ROLE_WIDTH'(6 + position);
            OP_ROPE: role_for = PORT_ROLE_WIDTH'(9 + position);
            OP_SCORE: role_for = PORT_ROLE_WIDTH'(11 + position);
            OP_SOFTMAX: role_for = PORT_ROLE_WIDTH'(14);
            OP_VALUE: role_for = PORT_ROLE_WIDTH'(15 + position);
            OP_ADD, OP_SILU: role_for = PORT_ROLE_WIDTH'(18 + position);
            default: role_for = '0;
        endcase
    endfunction

    function automatic logic bank_allowed(input int role, input logic [3:0] bank);
        case (role)
            1: bank_allowed = (bank == 0 || bank == 3 || bank == 7 ||
                               bank == 8 || bank == 9);
            2: bank_allowed = (bank == 5 || bank == 6 || bank == 12);
            3: bank_allowed = (bank == 2 || bank == 10 || bank == 11);
            4: bank_allowed = (bank == 3);
            5: bank_allowed = (bank == 1 || bank == 4 || bank == 5 ||
                               bank == 6 || bank == 8 || bank == 9 || bank == 12);
            6: bank_allowed = (bank == 0 || bank == 5);
            7: bank_allowed = (bank == 3);
            8: bank_allowed = (bank == 2);
            9: bank_allowed = (bank == 4 || bank == 5 || bank == 8);
            10: bank_allowed = (bank == 7);
            11: bank_allowed = (bank == 4);
            12: bank_allowed = (bank == 8);
            13: bank_allowed = (bank == 10);
            14: bank_allowed = (bank == 10);
            15: bank_allowed = (bank == 10);
            16: bank_allowed = (bank == 9);
            17: bank_allowed = (bank == 11);
            18: bank_allowed = (bank == 0 || bank == 5 || bank == 8);
            19: bank_allowed = (bank == 1 || bank == 9);
            20: bank_allowed = (bank == 0 || bank == 5 || bank == 10);
            default: bank_allowed = 1'b0;
        endcase
    endfunction
    // USER_DECLARATIONS_END

    assign opcode_w = command_r[CMD_DATA_WIDTH-1 -: OPCODE_WIDTH];
    assign operand0_bank_w = command_r[OPCODE_LSB-1 -: BANK_NUM_WIDTH];
    assign operand1_bank_w = command_r[OPERAND0_LSB-1 -: BANK_NUM_WIDTH];
    assign operand2_bank_w = command_r[OPERAND1_LSB-1 -: BANK_NUM_WIDTH];
    assign local_offset_w = command_r[OPERAND2_LSB-1 -: BANK_ADDR_WIDTH];
    assign byte_count_w = command_r[LOCAL_OFFSET_LSB-1 -: BTT_WIDTH];
    assign axi_address_w = command_r[BYTE_COUNT_LSB-1 -: AXI_ADDR_WIDTH];

    assign macro_legal_w = (command_r[32:0] == '0) &&
        (operand1_bank_w == 4'd3) &&
        ({1'b0, operand0_bank_w} < BANK_NUM_LIMIT) &&
        ({1'b0, operand2_bank_w} < BANK_NUM_LIMIT) &&
        (operand0_bank_w != operand1_bank_w) &&
        (operand0_bank_w != operand2_bank_w) &&
        (operand1_bank_w != operand2_bank_w) &&
        bank_allowed(int'(role_for(OP_GEMM, 0)), operand0_bank_w) &&
        bank_allowed(int'(role_for(OP_GEMM, 1)), operand1_bank_w) &&
        bank_allowed(int'(role_for(OP_GEMM, 2)), operand2_bank_w) &&
        (command_r[83:80] == 4'd0) &&
        (command_r[79:64] != 16'd0) &&
        (command_r[79:64] <= 16'd49152) &&
        (command_r[63:53] != 11'd0) &&
        (command_r[63:53] <= 11'd1536) &&
        (command_r[40:33] != 8'd0) &&
        (command_r[40:33] <= 8'd192) &&
        (command_r[46:41] != 6'd0) &&
        (command_r[46:41] <= 6'd32) &&
        ({1'b0, command_r[52:47]} + {1'b0, command_r[46:41]} <= 7'd32);

    always_comb begin
        operand0_tag_w = TAG_WIDTH'(operand0_bank_w);
        operand0_index_w = {1'b0, operand0_bank_w};

        fixed_opcode_w = (opcode_w == OP_END) ||
                         (opcode_w == OP_MM2S) ||
                         (opcode_w == OP_S2MM);
        bank_in_range_w = (operand0_index_w < BANK_NUM_LIMIT);
        fixed_command_legal_w = 1'b0;
        fixed_bank_eligible_w = 1'b0;

        case (opcode_w)
            OP_END: begin
                fixed_command_legal_w = 1'b1;
                fixed_bank_eligible_w = 1'b1;
            end
            OP_MM2S, OP_S2MM: begin
                fixed_command_legal_w = bank_in_range_w && (byte_count_w != '0);
                if (bank_in_range_w) begin
                    fixed_bank_eligible_w = !bank_busy[operand0_bank_w] &&
                                      !pending_mm2s_r[operand0_bank_w] &&
                                      !pending_s2mm_r[operand0_bank_w];
                end
            end
            default: begin
                fixed_command_legal_w = 1'b0;
                fixed_bank_eligible_w = 1'b0;
            end
        endcase
    end

    // USER_DECODE_BEGIN
    always_comb begin
        is_compute_w = (opcode_w >= OP_GEMM) && (opcode_w <= OP_SILU);
        is_fence_w = (opcode_w == OP_FENCE);
        selected_channel_w = 3'd0;
        case (opcode_w)
            OP_GEMM: selected_channel_w = 3'd0;
            OP_RMS: selected_channel_w = 3'd1;
            OP_ROPE: selected_channel_w = 3'd2;
            OP_SCORE: selected_channel_w = 3'd3;
            OP_SOFTMAX: selected_channel_w = 3'd4;
            OP_VALUE: selected_channel_w = 3'd5;
            OP_ADD, OP_SILU: selected_channel_w = 3'd6;
            default: selected_channel_w = 3'd0;
        endcase
        used_bank_count_w = 2'd3;
        if (opcode_w == OP_ROPE) used_bank_count_w = 2'd2;
        if (opcode_w == OP_SOFTMAX) used_bank_count_w = 2'd1;
        bank1_index_w = {1'b0, operand1_bank_w};
        bank2_index_w = {1'b0, operand2_bank_w};
        gemm_n_start_w = command_r[62:47];
        gemm_n_total_w = command_r[46:31];
        gemm_m_start_w = command_r[30:25];
        gemm_m_count_w = command_r[24:19];
        gemm_k_w = command_r[18:8];
        gemm_n_tile_w = command_r[7:0];
        score_q_start_w = command_r[26:17];
        score_m_count_w = command_r[16:11];
        score_kv_len_w = command_r[10:0];
        embedding_rows_w = command_r[11:6];
        embedding_row_w = command_r[5:0];

        user_opcode_known_w = is_compute_w || is_fence_w;
        user_command_legal_w = 1'b0;
        if (is_fence_w) begin
            user_command_legal_w = (command_r[123:0] == '0);
        end else if (is_compute_w) begin
            user_command_legal_w = bank_in_range_w &&
                ((used_bank_count_w < 2) || (bank1_index_w < BANK_NUM_LIMIT)) &&
                ((used_bank_count_w < 3) || (bank2_index_w < BANK_NUM_LIMIT)) &&
                ((used_bank_count_w < 2) || (operand0_bank_w != operand1_bank_w)) &&
                ((used_bank_count_w < 3) ||
                 ((operand0_bank_w != operand2_bank_w) &&
                  (operand1_bank_w != operand2_bank_w))) &&
                ((used_bank_count_w != 1) ||
                 ((operand1_bank_w == '0) && (operand2_bank_w == '0))) &&
                ((used_bank_count_w != 2) || (operand2_bank_w == '0));
            user_command_legal_w = user_command_legal_w &&
                bank_allowed(int'(role_for(opcode_w, 0)), operand0_bank_w) &&
                ((used_bank_count_w < 2) ||
                 bank_allowed(int'(role_for(opcode_w, 1)), operand1_bank_w)) &&
                ((used_bank_count_w < 3) ||
                 bank_allowed(int'(role_for(opcode_w, 2)), operand2_bank_w));
            if (opcode_w == OP_GEMM) begin
                user_command_legal_w = user_command_legal_w &&
                    (command_r[111:63] == '0) &&
                    (gemm_n_total_w != 0) && (gemm_n_total_w <= 16'd49152) &&
                    (gemm_n_tile_w != 0) && (gemm_n_tile_w <= 8'd192) &&
                    ({1'b0, gemm_n_start_w} + {9'b0, gemm_n_tile_w} <=
                     {1'b0, gemm_n_total_w}) &&
                    (gemm_m_count_w != 0) && (gemm_m_count_w <= 6'd32) &&
                    ({1'b0, gemm_m_start_w} + {1'b0, gemm_m_count_w} <= 7'd32) &&
                    (gemm_k_w != 0);
            end else if (opcode_w == OP_RMS || opcode_w == OP_ROPE ||
                         opcode_w == OP_ADD || opcode_w == OP_SILU) begin
                user_command_legal_w = user_command_legal_w &&
                    (command_r[111:6] == '0) &&
                    ((command_r[5:0] != 0) ||
                     (opcode_w == OP_RMS && ALLOW_ZERO_RMS_PROBE)) &&
                    (command_r[5:0] <= 6'd32);
            end else if (opcode_w == OP_SCORE || opcode_w == OP_SOFTMAX ||
                         opcode_w == OP_VALUE) begin
                user_command_legal_w = user_command_legal_w &&
                    (command_r[111:27] == '0) &&
                    (score_m_count_w != 0) && (score_m_count_w <= 6'd32) &&
                    (score_kv_len_w != 0) && (score_kv_len_w <= 11'd1024) &&
                    ({1'b0, score_q_start_w} + {5'b0, score_m_count_w} <=
                     score_kv_len_w);
            end else begin
                user_command_legal_w = user_command_legal_w &&
                    (command_r[111:0] == '0);
            end
        end

        all_banks_free_w = !(|(pending_mm2s_r | pending_s2mm_r)) &&
            !(|compute_pending_r) && !(|bank_busy);
        user_bank_eligible_w = 1'b0;
        if (is_fence_w && user_command_legal_w) begin
            user_bank_eligible_w = all_banks_free_w;
        end else if (is_compute_w && user_command_legal_w) begin
            user_bank_eligible_w = !compute_pending_r[selected_channel_w] &&
                !bank_busy[operand0_bank_w] &&
                ((used_bank_count_w < 2) || !bank_busy[operand1_bank_w]) &&
                ((used_bank_count_w < 3) || !bank_busy[operand2_bank_w]);
        end

        source_invalid_w = 1'b0;
        if (is_compute_w && user_command_legal_w) begin
            source_invalid_w = !bank_tensor_valid[operand0_bank_w] ||
                ((used_bank_count_w >= 2) &&
                 !bank_tensor_valid[operand1_bank_w]);
        end
        dma_load_invalid_w = 1'b0;
        if (opcode_w == OP_MM2S && command_r[24:0] != '0) begin
            dma_load_invalid_w = (command_r[24:12] != '0) ||
                (embedding_rows_w == 0) || (embedding_rows_w > 6'd32) ||
                (embedding_row_w >= embedding_rows_w) ||
                (byte_count_w != BTT_WIDTH'(1152)) ||
                (local_offset_w !=
                 (BANK_ADDR_WIDTH'(embedding_row_w) << 10) +
                 (BANK_ADDR_WIDTH'(embedding_row_w) << 7));
        end

        write_bank_w = (opcode_w == OP_ROPE || opcode_w == OP_SOFTMAX) ?
            operand0_bank_w : operand2_bank_w;
        write_kind_w = WRITE_FULL;
        write_index_w = 16'd0;
        write_count_w = 16'd1;
        write_total_w = 16'd1;
        if (opcode_w == OP_GEMM) begin
            write_kind_w = WRITE_PART;
            write_index_w = gemm_n_start_w;
            write_count_w = {8'd0, gemm_n_tile_w};
            write_total_w = gemm_n_total_w;
        end else if (opcode_w == OP_ROPE || opcode_w == OP_SOFTMAX) begin
            write_kind_w = WRITE_INPLACE;
            write_count_w = 16'd0;
            write_total_w = 16'd0;
        end
    end
    // USER_DECODE_END

    always_comb begin
        opcode_known_w = fixed_opcode_w || user_opcode_known_w;
        command_legal_w = fixed_opcode_w ? fixed_command_legal_w :
                                             user_command_legal_w;
        bank_eligible_w = fixed_opcode_w ? fixed_bank_eligible_w :
                                            user_bank_eligible_w;
    end

    always_comb begin
        mm2s_tag_index_w = {1'b0, s_ctrl_mm2s_sts_tag};
        s2mm_tag_index_w = {1'b0, s_ctrl_s2mm_sts_tag};
        mm2s_response_match_w = 1'b0;
        if (mm2s_tag_index_w < TAG_BANK_NUM_LIMIT) begin
            mm2s_response_match_w = pending_mm2s_r[s_ctrl_mm2s_sts_tag];
        end

        s2mm_response_match_w = 1'b0;
        if (s2mm_tag_index_w < TAG_BANK_NUM_LIMIT) begin
            s2mm_response_match_w = pending_s2mm_r[s_ctrl_s2mm_sts_tag];
        end

        fixed_response_fault_w = cmd_dispatcher_busy &&
            ((s_ctrl_mm2s_sts_valid && !mm2s_response_match_w) ||
             (s_ctrl_s2mm_sts_valid && !s2mm_response_match_w));
        fixed_executor_fault_w = cmd_dispatcher_busy &&
            ((s_ctrl_mm2s_sts_valid && mm2s_response_match_w &&
              s_ctrl_mm2s_sts_error) ||
             (s_ctrl_s2mm_sts_valid && s2mm_response_match_w &&
              s_ctrl_s2mm_sts_error));
    end

    always_comb begin
        cmd_dispatcher_busy = (state_r == FETCH) ||
                              (state_r == CHECK_COMMAND) ||
                              (state_r == ISSUE_COMMAND) ||
                              (state_r == END_DRAIN) ||
                              (state_r == ERROR_DRAIN);
        cmd_dispatcher_done = (state_r == DONE_STATE);
        cmd_dispatcher_error = (state_r == ERROR_STATE);
        cmd_dispatcher_error_code = error_code_r;
        current_pc = pc_r;

        cmd_enb = (state_r == FETCH) && (fetch_count_r == '0);
        cmd_addrb = pc_r;

        m_ctrl_mm2s_cmd_valid = aresetn &&
                                (state_r == ISSUE_COMMAND) &&
                                (opcode_w == OP_MM2S) &&
                                !response_fault_w && !executor_fault_w;
        m_ctrl_mm2s_cmd_addr = axi_address_w;
        m_ctrl_mm2s_cmd_btt = byte_count_w;
        m_ctrl_mm2s_cmd_offset = local_offset_w;
        m_ctrl_mm2s_cmd_bank = operand0_bank_w;
        m_ctrl_mm2s_cmd_tag = operand0_tag_w;

        m_ctrl_s2mm_cmd_valid = aresetn &&
                                (state_r == ISSUE_COMMAND) &&
                                (opcode_w == OP_S2MM) &&
                                !response_fault_w && !executor_fault_w;
        m_ctrl_s2mm_cmd_addr = axi_address_w;
        m_ctrl_s2mm_cmd_btt = byte_count_w;
        m_ctrl_s2mm_cmd_offset = local_offset_w;
        m_ctrl_s2mm_cmd_bank = operand0_bank_w;
        m_ctrl_s2mm_cmd_tag = operand0_tag_w;

        m_ctrl_mm2s_sts_ready = aresetn;
        m_ctrl_s2mm_sts_ready = aresetn;

        fixed_request_fire_w =
            (m_ctrl_mm2s_cmd_valid && m_ctrl_mm2s_cmd_ready) ||
            (m_ctrl_s2mm_cmd_valid && m_ctrl_s2mm_cmd_ready);

        fixed_bank_acquire_valid_w = '0;
        fixed_bank_acquire_port_w = '0;
        fixed_bank_release_valid_w = '0;
        fixed_bank_release_port_w = '0;
        if (fixed_request_fire_w) begin
            fixed_bank_acquire_valid_w[operand0_bank_w] = 1'b1;
            fixed_bank_acquire_port_w[operand0_bank_w] =
                (opcode_w == OP_MM2S) ? PORT_MM2S_ARBITER : PORT_S2MM_ARBITER;
        end
        if (aresetn && s_ctrl_mm2s_sts_valid && mm2s_response_match_w) begin
            fixed_bank_release_valid_w[s_ctrl_mm2s_sts_tag] = 1'b1;
            fixed_bank_release_port_w[s_ctrl_mm2s_sts_tag] = PORT_MM2S_ARBITER;
        end
        if (aresetn && s_ctrl_s2mm_sts_valid && s2mm_response_match_w) begin
            fixed_bank_release_valid_w[s_ctrl_s2mm_sts_tag] = 1'b1;
            fixed_bank_release_port_w[s_ctrl_s2mm_sts_tag] = PORT_S2MM_ARBITER;
        end

        fixed_pending_any_w = |(pending_mm2s_r | pending_s2mm_r);
        busy_any_w = |bank_busy;
    end

    // USER_ISSUE_BEGIN
    always_comb begin
        compute_cmd_valid = '0;
        compute_cmd_opcode = '0;
        compute_cmd_bank = '0;
        compute_cmd_payload = '0;
        compute_fire_w = '0;
        user_request_valid_w = 1'b0;
        user_request_ready_w = 1'b0;
        user_request_fire_w = 1'b0;
        user_bank_acquire_valid_w = '0;
        user_bank_acquire_port_w = '0;
        if (aresetn && (state_r == ISSUE_COMMAND) && is_compute_w &&
            !fixed_response_fault_w && !fixed_executor_fault_w &&
            !user_response_fault_w && !user_executor_fault_w) begin
            compute_cmd_valid[selected_channel_w] = 1'b1;
            compute_cmd_opcode[selected_channel_w] = opcode_w;
            compute_cmd_bank[selected_channel_w][0] = operand0_bank_w;
            compute_cmd_bank[selected_channel_w][1] = operand1_bank_w;
            compute_cmd_bank[selected_channel_w][2] = operand2_bank_w;
            compute_cmd_payload[selected_channel_w] = command_r[111:0];
            user_request_valid_w = 1'b1;
            user_request_ready_w = compute_cmd_ready[selected_channel_w];
            compute_fire_w[selected_channel_w] =
                compute_cmd_ready[selected_channel_w];
            user_request_fire_w = compute_cmd_ready[selected_channel_w];
            if (user_request_fire_w) begin
                user_bank_acquire_valid_w[operand0_bank_w] = 1'b1;
                user_bank_acquire_port_w[operand0_bank_w] = role_for(opcode_w, 0);
                if (used_bank_count_w >= 2) begin
                    user_bank_acquire_valid_w[operand1_bank_w] = 1'b1;
                    user_bank_acquire_port_w[operand1_bank_w] = role_for(opcode_w, 1);
                end
                if (used_bank_count_w >= 3) begin
                    user_bank_acquire_valid_w[operand2_bank_w] = 1'b1;
                    user_bank_acquire_port_w[operand2_bank_w] = role_for(opcode_w, 2);
                end
            end
        end else if (aresetn && (state_r == ISSUE_COMMAND) && is_fence_w &&
                     !fixed_response_fault_w && !fixed_executor_fault_w &&
                     !user_response_fault_w && !user_executor_fault_w) begin
            user_request_valid_w = 1'b1;
            user_request_ready_w = all_banks_free_w;
            user_request_fire_w = all_banks_free_w;
        end
    end
    // USER_ISSUE_END

    // USER_COMPLETION_BEGIN
    always_comb begin
        compute_done_ready = '0;
        completion_match_w = '0;
        user_pending_any_w = |compute_pending_r;
        user_bank_release_valid_w = '0;
        user_bank_release_port_w = '0;
        user_response_fault_w = 1'b0;
        user_executor_fault_w = bank_tensor_state_error;
        wr_issue_valid = '0;
        wr_issue_kind = '0;
        wr_issue_index = '0;
        wr_issue_count = '0;
        wr_issue_total = '0;
        wr_complete_valid = '0;
        wr_complete_error = '0;

        if (aresetn && fixed_request_fire_w && opcode_w == OP_MM2S) begin
            wr_issue_valid[operand0_bank_w] = 1'b1;
            if (command_r[24:0] != '0) begin
                wr_issue_kind[operand0_bank_w] = WRITE_PART;
                wr_issue_index[operand0_bank_w] = {10'd0, embedding_row_w};
                wr_issue_count[operand0_bank_w] = 16'd1;
                wr_issue_total[operand0_bank_w] = {10'd0, embedding_rows_w};
            end else begin
                wr_issue_kind[operand0_bank_w] = WRITE_FULL;
                wr_issue_count[operand0_bank_w] = 16'd1;
                wr_issue_total[operand0_bank_w] = 16'd1;
            end
        end
        if (aresetn && s_ctrl_mm2s_sts_valid && mm2s_response_match_w) begin
            wr_complete_valid[s_ctrl_mm2s_sts_tag] = 1'b1;
            wr_complete_error[s_ctrl_mm2s_sts_tag] = s_ctrl_mm2s_sts_error;
        end

        if (aresetn && user_request_fire_w && is_compute_w) begin
            wr_issue_valid[write_bank_w] = 1'b1;
            wr_issue_kind[write_bank_w] = write_kind_w;
            wr_issue_index[write_bank_w] = write_index_w;
            wr_issue_count[write_bank_w] = write_count_w;
            wr_issue_total[write_bank_w] = write_total_w;
        end
        for (int channel = 0; channel < 7; channel++) begin
            compute_done_ready[channel] = aresetn;
            completion_match_w[channel] = compute_done_valid[channel] &&
                compute_pending_r[channel] &&
                (compute_done_tag[channel] == pending_bank_r[channel][0]) &&
                (compute_done_bank_count[channel] == pending_bank_count_r[channel]);
            for (int position = 0; position < 3; position++) begin
                if (compute_done_bank[channel][position] != pending_bank_r[channel][position])
                    completion_match_w[channel] = 1'b0;
            end
            if (aresetn && completion_match_w[channel]) begin
                for (int position = 0; position < 3; position++) begin
                    if (position < pending_bank_count_r[channel]) begin
                        user_bank_release_valid_w[compute_done_bank[channel][position]] = 1'b1;
                        user_bank_release_port_w[compute_done_bank[channel][position]] =
                            pending_role_r[channel][position];
                    end
                end
                wr_complete_valid[pending_dst_r[channel]] = 1'b1;
                wr_complete_error[pending_dst_r[channel]] = compute_done_error[channel];
            end
            if (cmd_dispatcher_busy && compute_done_valid[channel] &&
                !completion_match_w[channel]) user_response_fault_w = 1'b1;
            if (cmd_dispatcher_busy && completion_match_w[channel] &&
                compute_done_error[channel]) user_executor_fault_w = 1'b1;
        end
        if (cmd_dispatcher_busy && (state_r == ISSUE_COMMAND)) begin
            if (is_compute_w && source_invalid_w) user_executor_fault_w = 1'b1;
            if (opcode_w == OP_S2MM && bank_in_range_w &&
                !bank_allowed(2, operand0_bank_w)) user_executor_fault_w = 1'b1;
            if (opcode_w == OP_MM2S && bank_in_range_w &&
                !bank_allowed(1, operand0_bank_w)) user_executor_fault_w = 1'b1;
            if (opcode_w == OP_S2MM && bank_in_range_w &&
                !bank_tensor_valid[operand0_bank_w]) user_executor_fault_w = 1'b1;
            if (opcode_w == OP_MM2S && dma_load_invalid_w)
                user_executor_fault_w = 1'b1;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            compute_pending_r <= '0;
            pending_bank_r <= '0;
            pending_role_r <= '0;
            pending_bank_count_r <= '0;
            pending_dst_r <= '0;
        end else begin
            for (int channel = 0; channel < 7; channel++) begin
                if (completion_match_w[channel]) compute_pending_r[channel] <= 1'b0;
                if (compute_fire_w[channel]) begin
                    compute_pending_r[channel] <= 1'b1;
                    pending_bank_r[channel][0] <= operand0_bank_w;
                    pending_bank_r[channel][1] <= operand1_bank_w;
                    pending_bank_r[channel][2] <= operand2_bank_w;
                    pending_role_r[channel][0] <= role_for(opcode_w, 0);
                    pending_role_r[channel][1] <= role_for(opcode_w, 1);
                    pending_role_r[channel][2] <= role_for(opcode_w, 2);
                    pending_bank_count_r[channel] <= used_bank_count_w;
                    pending_dst_r[channel] <= write_bank_w;
                end
            end
        end
    end
    // USER_COMPLETION_END

    always_comb begin
        request_fire_w = fixed_request_fire_w ||
                         (user_request_valid_w && user_request_ready_w &&
                          user_request_fire_w);
        bank_acquire_valid = fixed_bank_acquire_valid_w | user_bank_acquire_valid_w;
        bank_acquire_port = fixed_bank_acquire_port_w | user_bank_acquire_port_w;
        bank_release_valid = fixed_bank_release_valid_w | user_bank_release_valid_w;
        bank_release_port = fixed_bank_release_port_w | user_bank_release_port_w;
        pending_any_w = fixed_pending_any_w || user_pending_any_w;
        response_fault_w = fixed_response_fault_w || user_response_fault_w ||
            (cmd_dispatcher_busy && user_request_fire_w &&
             !(user_request_valid_w && user_request_ready_w));
        executor_fault_w = fixed_executor_fault_w || user_executor_fault_w;
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE;
            pc_r <= '0;
            fetch_count_r <= '0;
            command_r <= '0;
            error_code_r <= ERR_NONE;
            macro_active_r <= 1'b0;
            macro_gemm_r <= 1'b0;
            macro_command_r <= '0;
            macro_n_r <= '0;
            macro_address_r <= '0;
            pending_mm2s_r <= '0;
            pending_s2mm_r <= '0;
        end else begin
            if (s_ctrl_mm2s_sts_valid && mm2s_response_match_w) begin
                pending_mm2s_r[s_ctrl_mm2s_sts_tag] <= 1'b0;
            end
            if (s_ctrl_s2mm_sts_valid && s2mm_response_match_w) begin
                pending_s2mm_r[s_ctrl_s2mm_sts_tag] <= 1'b0;
            end

            if ((response_fault_w || executor_fault_w) &&
                (state_r != ERROR_DRAIN)) begin
                error_code_r <= response_fault_w ? ERR_RESPONSE : ERR_EXECUTOR;
                state_r <= ERROR_DRAIN;
            end else begin
                case (state_r)
                    IDLE: begin
                        if (cmd_dispatcher_start) begin
                            pc_r <= '0;
                            fetch_count_r <= '0;
                            error_code_r <= ERR_NONE;
                            macro_active_r <= 1'b0;
                            macro_gemm_r <= 1'b0;
                            if (PARAMETERS_LEGAL) begin
                                state_r <= FETCH;
                            end else begin
                                error_code_r <= ERR_PARAMETER;
                                state_r <= ERROR_STATE;
                            end
                        end
                    end
                    FETCH: begin
                        if (fetch_count_r < FETCH_LATENCY_COUNT) begin
                            fetch_count_r <= fetch_count_r + 1'b1;
                        end else begin
                            command_r <= cmd_doutb;
                            fetch_count_r <= '0;
                            state_r <= CHECK_COMMAND;
                        end
                    end
                    CHECK_COMMAND: begin
                        if (opcode_w == OP_GEMM_TILES && !macro_active_r) begin
                            if (!macro_legal_w) begin
                                error_code_r <= ERR_OPERAND;
                                state_r <= ERROR_DRAIN;
                            end else begin
                                macro_command_r <= command_r;
                                macro_n_r <= '0;
                                macro_address_r <= command_r[111:80];
                                macro_active_r <= 1'b1;
                                macro_gemm_r <= 1'b0;
                                command_r <= macro_load_command(
                                    command_r, command_r[111:80], 16'd0);
                                state_r <= CHECK_COMMAND;
                            end
                        end else if (!opcode_known_w) begin
                            error_code_r <= ERR_OPCODE;
                            state_r <= ERROR_DRAIN;
                        end else if (!command_legal_w) begin
                            error_code_r <= ERR_OPERAND;
                            state_r <= ERROR_DRAIN;
                        end else if (opcode_w == OP_END) begin
                            state_r <= END_DRAIN;
                        end else if (bank_eligible_w) begin
                            state_r <= ISSUE_COMMAND;
                        end
                    end
                    ISSUE_COMMAND: begin
                        if (request_fire_w) begin
                            if (opcode_w == OP_MM2S) begin
                                pending_mm2s_r[operand0_bank_w] <= 1'b1;
                            end else if (opcode_w == OP_S2MM) begin
                                pending_s2mm_r[operand0_bank_w] <= 1'b1;
                            end
                            if (macro_active_r && !macro_gemm_r) begin
                                command_r <= macro_gemm_command(
                                    macro_command_r, macro_n_r);
                                macro_gemm_r <= 1'b1;
                                state_r <= CHECK_COMMAND;
                            end else if (macro_active_r &&
                                ({1'b0, macro_n_r} +
                                 {9'd0, macro_tile_width(macro_command_r, macro_n_r)} <
                                 {1'b0, macro_command_r[79:64]})) begin
                                macro_n_r <= macro_n_r +
                                    16'(macro_tile_width(macro_command_r, macro_n_r));
                                macro_address_r <= macro_address_r +
                                    32'(macro_tile_width(macro_command_r, macro_n_r)) *
                                    32'(macro_command_r[63:53]) * 32'd2;
                                command_r <= macro_load_command(
                                    macro_command_r,
                                    macro_address_r +
                                    32'(macro_tile_width(macro_command_r, macro_n_r)) *
                                    32'(macro_command_r[63:53]) * 32'd2,
                                    macro_n_r +
                                    16'(macro_tile_width(macro_command_r, macro_n_r)));
                                macro_gemm_r <= 1'b0;
                                state_r <= CHECK_COMMAND;
                            end else begin
                                macro_active_r <= 1'b0;
                                if (pc_r == LAST_PC) begin
                                    error_code_r <= ERR_MISSING_END;
                                    state_r <= ERROR_DRAIN;
                                end else begin
                                    pc_r <= pc_r + 1'b1;
                                    fetch_count_r <= '0;
                                    state_r <= FETCH;
                                end
                            end
                        end
                    end
                    END_DRAIN: begin
                        if (!pending_any_w && !busy_any_w) begin
                            state_r <= DONE_STATE;
                        end
                    end
                    ERROR_DRAIN: begin
                        if (!pending_any_w && !busy_any_w) begin
                            state_r <= ERROR_STATE;
                        end
                    end
                    DONE_STATE, ERROR_STATE: begin
                        if (cmd_dispatcher_start) begin
                            pc_r <= '0;
                            fetch_count_r <= '0;
                            error_code_r <= ERR_NONE;
                            macro_active_r <= 1'b0;
                            macro_gemm_r <= 1'b0;
                            if (PARAMETERS_LEGAL) begin
                                state_r <= FETCH;
                            end else begin
                                error_code_r <= ERR_PARAMETER;
                                state_r <= ERROR_STATE;
                            end
                        end
                    end
                    default: begin
                        error_code_r <= ERR_OPCODE;
                        state_r <= ERROR_DRAIN;
                    end
                endcase
            end
        end
    end

    // Passive observation. Activity counters overlap; they are not a time sum.
    always_comb begin
        profile_events = '0;
        if (cmd_dispatcher_busy) begin
            profile_events[0] = 1'b1;
            profile_events[1] = |pending_mm2s_r;
            profile_events[2] = |pending_s2mm_r;
            profile_events[3] = compute_pending_r[0];
            profile_events[4] = compute_pending_r[1];
            profile_events[5] = compute_pending_r[2];
            profile_events[6] = compute_pending_r[3];
            profile_events[7] = compute_pending_r[4];
            profile_events[8] = compute_pending_r[5];
            profile_events[9] = compute_pending_r[6];
            profile_events[10] = (state_r == CHECK_COMMAND || state_r == ISSUE_COMMAND)
                && is_fence_w && !all_banks_free_w;
            profile_events[11] = state_r == CHECK_COMMAND && !is_fence_w
                && opcode_w != OP_END && command_legal_w && !bank_eligible_w;
            profile_events[12] = state_r == ISSUE_COMMAND && !request_fire_w;
            profile_events[13] = state_r == END_DRAIN && !all_banks_free_w;
            profile_events[14] = profile_events[10] && |pending_mm2s_r;
            profile_events[15] = profile_events[10] && |pending_s2mm_r;
            profile_events[16] = profile_events[10] && |compute_pending_r;
            profile_events[17] = profile_events[10] && |bank_busy;
            profile_events[18] = |compute_pending_r;
        end
    end
endmodule
