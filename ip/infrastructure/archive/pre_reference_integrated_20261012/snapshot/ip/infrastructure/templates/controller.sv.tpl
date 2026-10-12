`timescale 1ns/1ps
// Design-authoring reference. Render names and USER slots in a design revision.
// Source pattern: reference controller/config_pkg (opcode, SRC0..3, DST, payload).
// This subset intentionally omits register instructions, loops and address flags.
// The payload is opaque here; every operation-specific engine owns its decoding.
module __CONTROLLER_MODULE__ #(
    parameter int BANK_NUM = __CONFIG_PKG__::BANK_NUM,
    parameter int BANK_ID_WIDTH = __CONFIG_PKG__::BANK_NUM_WIDTH,
    parameter int ROLE_WIDTH = __CONFIG_PKG__::PORT_ID_WIDTH,
    parameter int CMD_BITS = __CONFIG_PKG__::CMD_DATA_WIDTH,
    parameter int OPCODE_WIDTH = __CONFIG_PKG__::OPCODE_WIDTH,
    parameter int PAYLOAD_WIDTH = CMD_BITS - OPCODE_WIDTH - 5*BANK_ID_WIDTH,
    parameter int ENGINE_NUM = 1,
    parameter int CMD_ADDR_WIDTH = 10,
    parameter int CMD_READ_LATENCY = 2,
    parameter int MAX_COMMANDS = 1024
) (
    input logic aclk, aresetn,
    input logic start_i,
    output logic idle_o, done_o, error_o,
    output logic [7:0] error_code_o,
    output logic [CMD_ADDR_WIDTH-1:0] current_pc,
    output logic cmd_bram_enb,
    output logic [CMD_ADDR_WIDTH-1:0] cmd_bram_addrb,
    input logic [CMD_BITS-1:0] cmd_bram_doutb,
    output logic [ENGINE_NUM-1:0] m_engine_cmd_valid,
    input logic [ENGINE_NUM-1:0] m_engine_cmd_ready,
    output logic [ENGINE_NUM-1:0][OPCODE_WIDTH-1:0] m_engine_cmd_opcode,
    output logic [ENGINE_NUM-1:0][3:0][BANK_ID_WIDTH-1:0] m_engine_cmd_src_bank,
    output logic [ENGINE_NUM-1:0][BANK_ID_WIDTH-1:0] m_engine_cmd_dst_bank,
    output logic [ENGINE_NUM-1:0][PAYLOAD_WIDTH-1:0] m_engine_cmd_payload,
    input logic [ENGINE_NUM-1:0] s_engine_resp_valid,
    output logic [ENGINE_NUM-1:0] s_engine_resp_ready,
    input logic [ENGINE_NUM-1:0][CMD_BITS-1:0] s_engine_resp_command,
    input logic [ENGINE_NUM-1:0] s_engine_resp_error,
    input logic [ENGINE_NUM-1:0] s_engine_resp_clean,
    output logic [BANK_NUM-1:0] bank_wr_acquire_valid, bank_rd_acquire_valid,
    output logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] bank_wr_acquire_port, bank_rd_acquire_port,
    output logic [BANK_NUM-1:0] bank_wr_release_valid, bank_rd_release_valid,
    output logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] bank_wr_release_port, bank_rd_release_port,
    input logic [BANK_NUM-1:0] bank_wr_busy, bank_rd_busy,
    input logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] bank_wr_owner_port, bank_rd_owner_port,
    input logic [BANK_NUM-1:0] bank_wr_acquire_accepted, bank_rd_acquire_accepted,
    input logic [BANK_NUM-1:0] bank_wr_release_accepted, bank_rd_release_accepted,
    input logic bank_subsystem_error
    // USER_PORTS_BEGIN
    // Optional operation-specific public adapters, each prefixed with a comma.
    // USER_PORTS_END
);
    // USER_PARAMETERS_BEGIN
    // Design-specific constants; do not reinterpret the common header.
    // USER_PARAMETERS_END
    localparam int ENGINE_ID_WIDTH = ENGINE_NUM <= 1 ? 1 : $clog2(ENGINE_NUM);
    localparam int FETCH_COUNT_WIDTH = CMD_READ_LATENCY < 2 ? 1 : $clog2(CMD_READ_LATENCY+1);
    localparam logic [OPCODE_WIDTH-1:0] OP_END = __CONFIG_PKG__::OP_END;
    localparam logic PARAMETERS_LEGAL = CMD_BITS == 128 && OPCODE_WIDTH == 4 &&
        OP_END == '0 && BANK_NUM >= 1 && BANK_ID_WIDTH >= 1 &&
        BANK_ID_WIDTH >= $clog2(BANK_NUM) && PAYLOAD_WIDTH > 0 &&
        PAYLOAD_WIDTH == CMD_BITS-OPCODE_WIDTH-5*BANK_ID_WIDTH && ROLE_WIDTH >= 1 &&
        ENGINE_NUM >= 1 && CMD_READ_LATENCY >= 1 && MAX_COMMANDS >= 1 &&
        CMD_ADDR_WIDTH >= $clog2(MAX_COMMANDS);
    // USER_OPCODES_BEGIN
    // Declare supported per-operation opcodes. END remains reserved as zero.
    // USER_OPCODES_END
    typedef enum logic [3:0] {
        IDLE, FETCH, WAIT_READ, VERIFY, ACQUIRE, ISSUE, END_DRAIN,
        ERROR_DRAIN, COMPLETE, FAILED
    } state_t;
    state_t state_r;
    logic [CMD_ADDR_WIDTH-1:0] pc_r;
    logic [FETCH_COUNT_WIDTH-1:0] fetch_count_r;
    logic [CMD_BITS-1:0] command_r;
    logic [7:0] error_code_r;
    logic fail_stop_r;
    logic [ENGINE_NUM-1:0] pending_r, issued_r, completed_r;
    logic [ENGINE_NUM-1:0][CMD_BITS-1:0] engine_command_r;
    logic [ENGINE_NUM-1:0][BANK_NUM-1:0] engine_wr_mask_r, engine_rd_mask_r;
    logic [ENGINE_NUM-1:0][BANK_NUM-1:0][ROLE_WIDTH-1:0] engine_wr_roles_r, engine_rd_roles_r;
    logic [OPCODE_WIDTH-1:0] opcode_w;
    logic [3:0][BANK_ID_WIDTH-1:0] src_bank_w;
    logic [BANK_ID_WIDTH-1:0] dst_bank_w;
    logic [PAYLOAD_WIDTH-1:0] payload_w;
    logic [ENGINE_ID_WIDTH-1:0] selected_engine_w;
    logic opcode_known_w, command_legal_w, allow_split_overlap_w;
    logic [BANK_NUM-1:0] command_wr_mask_w, command_rd_mask_w;
    logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] command_wr_roles_w, command_rd_roles_w;
    logic bank_eligible_w, acquire_attempt_w, acquire_fire_w, issue_fire_w;
    logic response_fault_w, unclean_fault_w, clean_error_w, owner_fault_w;
    logic ack_fault_w, hard_fault_w, user_completion_fault_w, program_active_w;
    logic [ENGINE_NUM-1:0] response_match_w, release_fire_w;
    // USER_DECLARATIONS_BEGIN
    // Operation-specific adapters may use the decoded and latched context.
    // USER_DECLARATIONS_END
    assign opcode_w = command_r[CMD_BITS-1 -: OPCODE_WIDTH];
    for (genvar s=0; s<4; s++) begin : g_header
        assign src_bank_w[s] = command_r[CMD_BITS-OPCODE_WIDTH-1-s*BANK_ID_WIDTH -: BANK_ID_WIDTH];
    end
    assign dst_bank_w = command_r[PAYLOAD_WIDTH+BANK_ID_WIDTH-1 -: BANK_ID_WIDTH];
    assign payload_w = command_r[PAYLOAD_WIDTH-1:0];
    // USER_DECODE_BEGIN
    always_comb begin
        // Fail closed: only END is supported until per-op decode is supplied.
        opcode_known_w = opcode_w == OP_END;
        command_legal_w = opcode_w == OP_END;
        selected_engine_w = '0;
        command_wr_mask_w = '0; command_rd_mask_w = '0;
        command_wr_roles_w = '0; command_rd_roles_w = '0;
        // Opposite-direction overlap needs an explicit commit/watermark policy.
        allow_split_overlap_w = 1'b0;
    end
    // USER_DECODE_END
    always_comb begin
        bank_eligible_w = int'(selected_engine_w) < ENGINE_NUM;
        if (int'(selected_engine_w) < ENGINE_NUM)
            bank_eligible_w = bank_eligible_w && !pending_r[selected_engine_w];
        for (int b=0; b<BANK_NUM; b++) begin
            if (command_wr_mask_w[b]) begin
                bank_eligible_w = bank_eligible_w && !bank_wr_busy[b] &&
                    (allow_split_overlap_w || !bank_rd_busy[b]);
            end
            if (command_rd_mask_w[b]) begin
                bank_eligible_w = bank_eligible_w && !bank_rd_busy[b] &&
                    (allow_split_overlap_w || !bank_wr_busy[b]);
            end
        end
    end
    assign idle_o = state_r == IDLE;
    assign done_o = state_r == COMPLETE;
    assign error_o = error_code_r != '0;
    assign error_code_o = error_code_r;
    assign current_pc = pc_r;
    assign cmd_bram_enb = aresetn && state_r == FETCH;
    assign cmd_bram_addrb = pc_r;
    always_comb begin
        m_engine_cmd_valid = '0; m_engine_cmd_opcode = '0;
        m_engine_cmd_src_bank = '0; m_engine_cmd_dst_bank = '0; m_engine_cmd_payload = '0;
        for (int e=0; e<ENGINE_NUM; e++) begin
            m_engine_cmd_opcode[e] = opcode_w;
            m_engine_cmd_src_bank[e] = src_bank_w;
            m_engine_cmd_dst_bank[e] = dst_bank_w;
            m_engine_cmd_payload[e] = payload_w;
        end
        // Remain valid while stalled, even when another engine faults.
        if (aresetn && state_r == ISSUE && int'(selected_engine_w) < ENGINE_NUM)
            m_engine_cmd_valid[selected_engine_w] = 1'b1;
    end
    // USER_ISSUE_BEGIN
    // Connect per-op named interfaces to the common engine request arrays.
    // USER_ISSUE_END
    assign issue_fire_w = |(m_engine_cmd_valid & m_engine_cmd_ready);
    assign s_engine_resp_ready = aresetn && state_r != IDLE && state_r != COMPLETE &&
        state_r != FAILED ? '1 : '0;
    always_comb begin
        response_match_w = '0; response_fault_w = 1'b0;
        unclean_fault_w = 1'b0; clean_error_w = 1'b0; owner_fault_w = 1'b0;
        for (int e=0; e<ENGINE_NUM; e++) begin
            response_match_w[e] = pending_r[e] && !completed_r[e] &&
                (issued_r[e] || (m_engine_cmd_valid[e] && m_engine_cmd_ready[e])) &&
                s_engine_resp_command[e] == engine_command_r[e];
            if (s_engine_resp_valid[e] && s_engine_resp_ready[e]) begin
                if (!response_match_w[e]) response_fault_w = 1'b1;
                else if (!s_engine_resp_clean[e]) unclean_fault_w = 1'b1;
                else if (s_engine_resp_error[e]) clean_error_w = 1'b1;
            end
            for (int b=0; b<BANK_NUM; b++) begin
                if (pending_r[e] && engine_wr_mask_r[e][b] &&
                    (!bank_wr_busy[b] || bank_wr_owner_port[b] != engine_wr_roles_r[e][b])) owner_fault_w = 1'b1;
                if (pending_r[e] && engine_rd_mask_r[e][b] &&
                    (!bank_rd_busy[b] || bank_rd_owner_port[b] != engine_rd_roles_r[e][b])) owner_fault_w = 1'b1;
            end
        end
    end
    // USER_COMPLETION_BEGIN
    assign user_completion_fault_w = 1'b0;
    // Additional operation-specific response checks may assert this fault.
    // USER_COMPLETION_END
    assign acquire_attempt_w = aresetn && state_r == ACQUIRE && bank_eligible_w &&
        error_code_r == '0 && !bank_subsystem_error && !response_fault_w &&
        !unclean_fault_w && !clean_error_w && !owner_fault_w && !user_completion_fault_w;
    assign bank_wr_acquire_valid = acquire_attempt_w ? command_wr_mask_w : '0;
    assign bank_rd_acquire_valid = acquire_attempt_w ? command_rd_mask_w : '0;
    assign bank_wr_acquire_port = command_wr_roles_w;
    assign bank_rd_acquire_port = command_rd_roles_w;
    assign acquire_fire_w = acquire_attempt_w &&
        bank_wr_acquire_accepted == bank_wr_acquire_valid &&
        bank_rd_acquire_accepted == bank_rd_acquire_valid;
    always_comb begin
        bank_wr_release_valid = '0; bank_rd_release_valid = '0;
        bank_wr_release_port = '0; bank_rd_release_port = '0;
        release_fire_w = '0;
        for (int e=0; e<ENGINE_NUM; e++) begin
            if (pending_r[e] && completed_r[e] && aresetn && !fail_stop_r &&
                !bank_subsystem_error && !response_fault_w && !unclean_fault_w &&
                !owner_fault_w && !user_completion_fault_w) begin
                bank_wr_release_valid |= engine_wr_mask_r[e];
                bank_rd_release_valid |= engine_rd_mask_r[e];
                for (int b=0; b<BANK_NUM; b++) begin
                    if (engine_wr_mask_r[e][b]) bank_wr_release_port[b] = engine_wr_roles_r[e][b];
                    if (engine_rd_mask_r[e][b]) bank_rd_release_port[b] = engine_rd_roles_r[e][b];
                end
                release_fire_w[e] =
                    (bank_wr_release_accepted & engine_wr_mask_r[e]) == engine_wr_mask_r[e] &&
                    (bank_rd_release_accepted & engine_rd_mask_r[e]) == engine_rd_mask_r[e];
            end
        end
    end
    assign ack_fault_w = (acquire_attempt_w && !acquire_fire_w) ||
        bank_wr_release_accepted != bank_wr_release_valid ||
        bank_rd_release_accepted != bank_rd_release_valid;
    assign program_active_w = state_r != IDLE && state_r != COMPLETE && state_r != FAILED;
    assign hard_fault_w = program_active_w && (bank_subsystem_error || response_fault_w || unclean_fault_w ||
        owner_fault_w || ack_fault_w || user_completion_fault_w);
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE; pc_r <= '0; fetch_count_r <= '0; command_r <= '0;
            error_code_r <= '0; fail_stop_r <= 1'b0;
            pending_r <= '0; issued_r <= '0; completed_r <= '0;
            engine_command_r <= '0; engine_wr_mask_r <= '0; engine_rd_mask_r <= '0;
            engine_wr_roles_r <= '0; engine_rd_roles_r <= '0;
        end else begin
            for (int e=0; e<ENGINE_NUM; e++) begin
                if (s_engine_resp_valid[e] && s_engine_resp_ready[e] &&
                    response_match_w[e] && s_engine_resp_clean[e]) completed_r[e] <= 1'b1;
                if (release_fire_w[e]) begin
                    pending_r[e] <= 1'b0; issued_r[e] <= 1'b0; completed_r[e] <= 1'b0;
                end
                if (m_engine_cmd_valid[e] && m_engine_cmd_ready[e]) issued_r[e] <= 1'b1;
            end
            if (acquire_fire_w) begin
                pending_r[selected_engine_w] <= 1'b1;
                engine_command_r[selected_engine_w] <= command_r;
                engine_wr_mask_r[selected_engine_w] <= command_wr_mask_w;
                engine_rd_mask_r[selected_engine_w] <= command_rd_mask_w;
                engine_wr_roles_r[selected_engine_w] <= command_wr_roles_w;
                engine_rd_roles_r[selected_engine_w] <= command_rd_roles_w;
            end
            if (hard_fault_w) begin
                fail_stop_r <= 1'b1;
                if (error_code_r == '0) error_code_r <= 8'h03;
            end else if (clean_error_w && error_code_r == '0) error_code_r <= 8'h04;
            case (state_r)
                IDLE: if (start_i) begin
                    pc_r <= '0;
                    if (PARAMETERS_LEGAL) state_r <= FETCH;
                    else begin state_r <= FAILED; error_code_r <= 8'h06; fail_stop_r <= 1'b1; end
                end
                FETCH: begin fetch_count_r <= FETCH_COUNT_WIDTH'(1); state_r <= WAIT_READ; end
                WAIT_READ: if (fetch_count_r >= FETCH_COUNT_WIDTH'(CMD_READ_LATENCY)) begin
                    command_r <= cmd_bram_doutb; state_r <= VERIFY;
                end else fetch_count_r <= fetch_count_r + FETCH_COUNT_WIDTH'(1);
                VERIFY: begin
                    if (!opcode_known_w) begin
                        if (error_code_r == '0 && !hard_fault_w && !clean_error_w) error_code_r <= 8'h01;
                        state_r <= ERROR_DRAIN;
                    end
                    else if (!command_legal_w || (opcode_w != OP_END && int'(selected_engine_w) >= ENGINE_NUM)) begin
                        if (error_code_r == '0 && !hard_fault_w && !clean_error_w) error_code_r <= 8'h02;
                        state_r <= ERROR_DRAIN;
                    end else if (opcode_w == OP_END) state_r <= END_DRAIN;
                    else state_r <= ACQUIRE;
                end
                ACQUIRE: if (acquire_fire_w) state_r <= ISSUE;
                ISSUE: if (issue_fire_w) begin
                    if (pc_r == CMD_ADDR_WIDTH'(MAX_COMMANDS-1)) begin
                        if (error_code_r == '0 && !hard_fault_w && !clean_error_w) error_code_r <= 8'h05;
                        state_r <= ERROR_DRAIN;
                    end else begin pc_r <= pc_r + CMD_ADDR_WIDTH'(1); state_r <= FETCH; end
                end
                END_DRAIN: if (!(|pending_r) && !(|bank_wr_busy) && !(|bank_rd_busy)) state_r <= COMPLETE;
                ERROR_DRAIN: if (!(|pending_r) && !(|bank_wr_busy) && !(|bank_rd_busy)) state_r <= FAILED;
                COMPLETE: if (!start_i) state_r <= IDLE;
                FAILED: state_r <= FAILED; // Coherent reset of controller, bank and engines is required.
                default: begin
                    state_r <= FAILED; fail_stop_r <= 1'b1;
                    if (error_code_r == '0 && !hard_fault_w && !clean_error_w) error_code_r <= 8'h07;
                end
            endcase
            if (hard_fault_w || fail_stop_r) begin
                // Preserve a request already offered to an engine until accepted.
                if (state_r != ISSUE || issue_fire_w) state_r <= FAILED;
            end else if ((clean_error_w || error_code_r != '0) && state_r != FAILED && state_r != ERROR_DRAIN) begin
                if (state_r != ISSUE || issue_fire_w) state_r <= ERROR_DRAIN;
            end
        end
    end
endmodule
