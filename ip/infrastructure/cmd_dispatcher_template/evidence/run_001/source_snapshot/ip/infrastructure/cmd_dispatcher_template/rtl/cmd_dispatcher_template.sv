`timescale 1ns/1ps

module cmd_dispatcher_template #(
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
    parameter integer OPCODE_WIDTH      = 4
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic cmd_dispatcher_start,
    output logic cmd_dispatcher_busy,
    output logic cmd_dispatcher_done,
    output logic cmd_dispatcher_error,
    output logic [7:0] cmd_dispatcher_error_code,
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
    output logic [0:BANK_NUM-1][OPCODE_WIDTH-1:0] bank_acquire,
    output logic [0:BANK_NUM-1] bank_release,
    input  logic [0:BANK_NUM-1] bank_busy
    /* verilator lint_on LITENDIAN */

    // USER_PORTS_BEGIN
    // Add design-specific executor ports here, beginning each addition with a comma.
    // USER_PORTS_END
);

    // USER_PARAMETERS_BEGIN
    // Add design-specific executor parameters here.
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

    // USER_OPCODES_BEGIN
    // Add design-specific opcode constants here. Values 0, 1 and 2 are reserved.
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
    logic command_legal_w;
    logic bank_in_range_w;
    logic bank_eligible_w;
    logic request_fire_w;
    logic pending_any_w;
    logic busy_any_w;
    logic mm2s_response_match_w;
    logic s2mm_response_match_w;
    logic response_fault_w;
    logic executor_fault_w;
    logic [BANK_NUM_WIDTH:0] operand0_index_w;
    logic [TAG_WIDTH:0] mm2s_tag_index_w;
    logic [TAG_WIDTH:0] s2mm_tag_index_w;

    // USER_DECLARATIONS_BEGIN
    // Add design-specific state, pending identity and decoded payload declarations here.
    localparam integer USER_MARKER_COUNT = 14;
    // USER_DECLARATIONS_END

    assign opcode_w = command_r[CMD_DATA_WIDTH-1 -: OPCODE_WIDTH];
    assign operand0_bank_w = command_r[OPCODE_LSB-1 -: BANK_NUM_WIDTH];
    assign operand1_bank_w = command_r[OPERAND0_LSB-1 -: BANK_NUM_WIDTH];
    assign operand2_bank_w = command_r[OPERAND1_LSB-1 -: BANK_NUM_WIDTH];
    assign local_offset_w = command_r[OPERAND2_LSB-1 -: BANK_ADDR_WIDTH];
    assign byte_count_w = command_r[LOCAL_OFFSET_LSB-1 -: BTT_WIDTH];
    assign axi_address_w = command_r[BYTE_COUNT_LSB-1 -: AXI_ADDR_WIDTH];

    always_comb begin
        operand0_tag_w = TAG_WIDTH'(operand0_bank_w);
        operand0_index_w = {1'b0, operand0_bank_w};

        fixed_opcode_w = (opcode_w == OP_END) ||
                         (opcode_w == OP_MM2S) ||
                         (opcode_w == OP_S2MM);
        bank_in_range_w = (operand0_index_w < BANK_NUM_LIMIT);
        command_legal_w = 1'b0;
        bank_eligible_w = 1'b0;

        case (opcode_w)
            OP_END: begin
                command_legal_w = 1'b1;
                bank_eligible_w = 1'b1;
            end
            OP_MM2S, OP_S2MM: begin
                command_legal_w = bank_in_range_w && (byte_count_w != '0);
                if (bank_in_range_w) begin
                    bank_eligible_w = !bank_busy[operand0_bank_w] &&
                                      !pending_mm2s_r[operand0_bank_w] &&
                                      !pending_s2mm_r[operand0_bank_w];
                end
            end
            default: begin
                command_legal_w = 1'b0;
                bank_eligible_w = 1'b0;
            end
        endcase
    end

    // USER_DECODE_BEGIN
    // Add design-specific legality and bank-eligibility decode logic here.
    // USER_DECODE_END

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

        response_fault_w = cmd_dispatcher_busy &&
            ((s_ctrl_mm2s_sts_valid && !mm2s_response_match_w) ||
             (s_ctrl_s2mm_sts_valid && !s2mm_response_match_w));
        executor_fault_w = cmd_dispatcher_busy &&
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

        request_fire_w = (m_ctrl_mm2s_cmd_valid && m_ctrl_mm2s_cmd_ready) ||
                         (m_ctrl_s2mm_cmd_valid && m_ctrl_s2mm_cmd_ready);

        bank_acquire = '0;
        bank_release = '0;
        if (request_fire_w) begin
            bank_acquire[operand0_bank_w] = opcode_w;
        end
        if (aresetn && s_ctrl_mm2s_sts_valid && mm2s_response_match_w) begin
            bank_release[s_ctrl_mm2s_sts_tag] = 1'b1;
        end
        if (aresetn && s_ctrl_s2mm_sts_valid && s2mm_response_match_w) begin
            bank_release[s_ctrl_s2mm_sts_tag] = 1'b1;
        end

        pending_any_w = |(pending_mm2s_r | pending_s2mm_r);
        busy_any_w = |bank_busy;
    end

    // USER_ISSUE_BEGIN
    // Add design-specific stable request and atomic acquire logic here.
    // USER_ISSUE_END

    // USER_COMPLETION_BEGIN
    // Add design-specific response validation and exact-once release logic here.
    // USER_COMPLETION_END

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE;
            pc_r <= '0;
            fetch_count_r <= '0;
            command_r <= '0;
            error_code_r <= ERR_NONE;
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
                        if (!fixed_opcode_w) begin
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
                            end else begin
                                pending_s2mm_r[operand0_bank_w] <= 1'b1;
                            end
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

endmodule
