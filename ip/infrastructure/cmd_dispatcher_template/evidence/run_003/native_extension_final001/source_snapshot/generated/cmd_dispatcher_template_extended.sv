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
    parameter integer OPCODE_WIDTH      = 4,
    parameter integer PORT_ROLE_WIDTH   = 3,
    parameter logic [BANK_NUM-1:0] MM2S_BANK_MASK = '1,
    parameter logic [BANK_NUM-1:0] S2MM_BANK_MASK = '1
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

    output logic [BANK_NUM-1:0] bank_wr_acquire_valid, bank_rd_acquire_valid,
    output logic [BANK_NUM-1:0][PORT_ROLE_WIDTH-1:0] bank_wr_acquire_port, bank_rd_acquire_port,
    output logic [BANK_NUM-1:0] bank_wr_release_valid, bank_rd_release_valid,
    output logic [BANK_NUM-1:0][PORT_ROLE_WIDTH-1:0] bank_wr_release_port, bank_rd_release_port,
    input logic [BANK_NUM-1:0] bank_wr_busy, bank_rd_busy,
    input logic [BANK_NUM-1:0][PORT_ROLE_WIDTH-1:0] bank_wr_owner_port, bank_rd_owner_port,
    input logic [BANK_NUM-1:0] bank_wr_acquire_accepted, bank_rd_acquire_accepted,
    input logic [BANK_NUM-1:0] bank_wr_release_accepted, bank_rd_release_accepted,
    input logic [BANK_NUM-1:0] bank_rd_pending,
    input logic bank_subsystem_error
    // USER_PORTS_BEGIN
    , output logic m_ctrl_probe_cmd_valid
    , input logic m_ctrl_probe_cmd_ready
    , output logic [BANK_NUM_WIDTH-1:0] m_ctrl_probe_cmd_src, m_ctrl_probe_cmd_dst
    , input logic s_ctrl_probe_sts_valid
    , output logic m_ctrl_probe_sts_ready
    , input logic [BANK_NUM_WIDTH-1:0] s_ctrl_probe_sts_src, s_ctrl_probe_sts_dst
    , input logic s_ctrl_probe_sts_error
    // USER_PORTS_END
);
    // USER_PARAMETERS_BEGIN
    // Arbitrary two-operand executor smoke fixture; base parameters suffice.
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
    localparam logic [OPCODE_WIDTH-1:0] OP_PROBE = OPCODE_WIDTH'(3);
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_PROBE_READ = PORT_ROLE_WIDTH'(3);
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_PROBE_WRITE = PORT_ROLE_WIDTH'(4);
    // USER_OPCODES_END

    localparam logic [7:0] ERR_NONE        = 8'h00;
    localparam logic [7:0] ERR_OPCODE      = 8'h01;
    localparam logic [7:0] ERR_OPERAND     = 8'h02;
    localparam logic [7:0] ERR_RESPONSE    = 8'h03;
    localparam logic [7:0] ERR_EXECUTOR    = 8'h04;
    localparam logic [7:0] ERR_MISSING_END = 8'h05;
    localparam logic [7:0] ERR_PARAMETER   = 8'h06;
    localparam logic [7:0] ERR_BANK        = 8'h07;
    localparam logic [7:0] ERR_BANK_ACK    = 8'h08;

    typedef enum logic [3:0] {
        IDLE, CMD_READ, CMD_WAIT, OP_VERIFY, BANK_ACQUIRE, EXECUTE,
        END_DRAIN, ERROR_DRAIN, DONE_STATE, ERROR_STATE
    } state_t;
    state_t state_r;
    logic [CMD_ADDR_WIDTH-1:0] pc_r;
    logic [FETCH_COUNT_WIDTH-1:0] fetch_count_r;
    logic [CMD_DATA_WIDTH-1:0] command_r;
    logic [7:0] error_code_r;
    logic fail_stop_r;
    // Pending starts at bank acquisition, issued at engine acceptance, completed
    // at status acceptance, and retires only at matching bank release acceptance.
    logic [BANK_NUM-1:0] pending_mm2s_r, pending_s2mm_r;
    logic [BANK_NUM-1:0] issued_mm2s_r, issued_s2mm_r;
    logic [BANK_NUM-1:0] completed_mm2s_r, completed_s2mm_r;
    logic [OPCODE_WIDTH-1:0] opcode_w;
    logic [BANK_NUM_WIDTH-1:0] operand0_bank_w, operand1_bank_w, operand2_bank_w;
    logic [BANK_ADDR_WIDTH-1:0] local_offset_w;
    logic [BTT_WIDTH-1:0] byte_count_w;
    logic [AXI_ADDR_WIDTH-1:0] axi_address_w;
    logic [TAG_WIDTH-1:0] operand0_tag_w;
    logic fixed_opcode_w, opcode_known_w, command_legal_w, bank_eligible_w;
    logic fixed_bank_eligible_w, fixed_command_legal_w, bank_in_range_w;
    logic fixed_request_fire_w, request_fire_w, mm2s_fire_w, s2mm_fire_w;
    logic acquire_attempt_w, acquire_fire_w, user_acquire_fire_w;
    logic pending_any_w, busy_any_w, response_fault_w, executor_fault_w;
    logic fixed_response_fault_w, fixed_executor_fault_w, fixed_owner_fault_w;
    logic bank_ack_fault_w, hard_fault_w;
    logic [BANK_NUM-1:0] command_wr_mask_w, command_rd_mask_w;
    logic [BANK_NUM-1:0][PORT_ROLE_WIDTH-1:0] command_wr_roles_w, command_rd_roles_w;
    logic [BANK_NUM-1:0] fixed_wr_release_valid_w, fixed_rd_release_valid_w;
    logic [BANK_NUM-1:0][PORT_ROLE_WIDTH-1:0] fixed_wr_release_port_w, fixed_rd_release_port_w;
    logic mm2s_response_match_w, s2mm_response_match_w;
    logic user_opcode_known_w, user_command_legal_w, user_bank_eligible_w;
    logic user_request_valid_w, user_request_ready_w, user_request_fire_w;
    logic user_pending_any_w, user_response_fault_w, user_executor_fault_w;
    logic [BANK_NUM-1:0] user_bank_wr_acquire_valid_w, user_bank_rd_acquire_valid_w;
    logic [BANK_NUM-1:0][PORT_ROLE_WIDTH-1:0] user_bank_wr_acquire_port_w, user_bank_rd_acquire_port_w;
    logic [BANK_NUM-1:0] user_bank_wr_release_valid_w, user_bank_rd_release_valid_w;
    logic [BANK_NUM-1:0][PORT_ROLE_WIDTH-1:0] user_bank_wr_release_port_w, user_bank_rd_release_port_w;
    // USER_DECLARATIONS_BEGIN
    logic probe_pending_r, probe_issued_r, probe_completed_r;
    logic [BANK_NUM_WIDTH-1:0] probe_src_r, probe_dst_r;
    logic probe_match_w, probe_status_fire_w, probe_owner_fault_w;
    // USER_DECLARATIONS_END

    assign opcode_w = command_r[CMD_DATA_WIDTH-1 -: OPCODE_WIDTH];
    assign operand0_bank_w = command_r[OPCODE_LSB-1 -: BANK_NUM_WIDTH];
    assign operand1_bank_w = command_r[OPERAND0_LSB-1 -: BANK_NUM_WIDTH];
    assign operand2_bank_w = command_r[OPERAND1_LSB-1 -: BANK_NUM_WIDTH];
    assign local_offset_w = command_r[OPERAND2_LSB-1 -: BANK_ADDR_WIDTH];
    assign byte_count_w = command_r[LOCAL_OFFSET_LSB-1 -: BTT_WIDTH];
    assign axi_address_w = command_r[BYTE_COUNT_LSB-1 -: AXI_ADDR_WIDTH];
    assign operand0_tag_w = TAG_WIDTH'(operand0_bank_w);
    assign bank_in_range_w = {1'b0,operand0_bank_w} < BANK_NUM_LIMIT;
    assign fixed_opcode_w = opcode_w == OP_END || opcode_w == OP_MM2S || opcode_w == OP_S2MM;
    always_comb begin
        fixed_command_legal_w = opcode_w == OP_END;
        if (bank_in_range_w && byte_count_w != '0) begin
            if (opcode_w == OP_MM2S) fixed_command_legal_w = MM2S_BANK_MASK[operand0_bank_w];
            if (opcode_w == OP_S2MM) fixed_command_legal_w = S2MM_BANK_MASK[operand0_bank_w];
        end
        fixed_bank_eligible_w = 1'b0;
        if (bank_in_range_w)
            fixed_bank_eligible_w = !bank_wr_busy[operand0_bank_w] && !bank_rd_busy[operand0_bank_w] &&
                !bank_rd_pending[operand0_bank_w] && !pending_mm2s_r[operand0_bank_w] && !pending_s2mm_r[operand0_bank_w];
    end
    // USER_DECODE_BEGIN
    always_comb begin
        user_opcode_known_w = opcode_w == OP_PROBE;
        user_command_legal_w = user_opcode_known_w &&
            {1'b0,operand0_bank_w} < BANK_NUM_LIMIT &&
            {1'b0,operand1_bank_w} < BANK_NUM_LIMIT && operand0_bank_w != operand1_bank_w;
        user_bank_eligible_w = 1'b0;
        user_bank_wr_acquire_valid_w = '0; user_bank_rd_acquire_valid_w = '0;
        user_bank_wr_acquire_port_w = '0; user_bank_rd_acquire_port_w = '0;
        if (user_command_legal_w) begin
            user_bank_wr_acquire_valid_w[operand0_bank_w] = 1'b1;
            user_bank_rd_acquire_valid_w[operand1_bank_w] = 1'b1;
            user_bank_wr_acquire_port_w[operand0_bank_w] = PORT_PROBE_WRITE;
            user_bank_rd_acquire_port_w[operand1_bank_w] = PORT_PROBE_READ;
            user_bank_eligible_w = !probe_pending_r &&
                !bank_wr_busy[operand0_bank_w] && !bank_rd_busy[operand0_bank_w] &&
                !bank_wr_busy[operand1_bank_w] && !bank_rd_busy[operand1_bank_w] &&
                !bank_rd_pending[operand0_bank_w] && !bank_rd_pending[operand1_bank_w];
        end
    end
    // USER_DECODE_END
    always_comb begin
        opcode_known_w = fixed_opcode_w || user_opcode_known_w;
        command_legal_w = fixed_opcode_w ? fixed_command_legal_w : user_command_legal_w;
        bank_eligible_w = fixed_opcode_w ? fixed_bank_eligible_w : user_bank_eligible_w;
        command_wr_mask_w = '0; command_rd_mask_w = '0;
        command_wr_roles_w = '0; command_rd_roles_w = '0;
        if (bank_in_range_w && opcode_w == OP_MM2S) begin
            command_wr_mask_w[operand0_bank_w] = 1'b1;
            command_wr_roles_w[operand0_bank_w] = PORT_MM2S_ARBITER;
        end else if (bank_in_range_w && opcode_w == OP_S2MM) begin
            command_rd_mask_w[operand0_bank_w] = 1'b1;
            command_rd_roles_w[operand0_bank_w] = PORT_S2MM_ARBITER;
        end else if (!fixed_opcode_w) begin
            command_wr_mask_w = user_bank_wr_acquire_valid_w; command_rd_mask_w = user_bank_rd_acquire_valid_w;
            command_wr_roles_w = user_bank_wr_acquire_port_w; command_rd_roles_w = user_bank_rd_acquire_port_w;
        end
    end
    assign cmd_dispatcher_busy = state_r != IDLE && state_r != DONE_STATE && state_r != ERROR_STATE;
    assign cmd_dispatcher_done = state_r == DONE_STATE;
    // Sticky errors become visible immediately after the first failing edge,
    // including while a previously presented executor request is stalled.
    assign cmd_dispatcher_error = error_code_r != ERR_NONE;
    assign cmd_dispatcher_error_code = error_code_r;
    assign current_pc = pc_r;
    assign cmd_enb = aresetn && state_r == CMD_READ;
    assign cmd_addrb = pc_r;
    assign m_ctrl_mm2s_cmd_valid = aresetn && state_r == EXECUTE && opcode_w == OP_MM2S;
    assign m_ctrl_s2mm_cmd_valid = aresetn && state_r == EXECUTE && opcode_w == OP_S2MM;
    assign m_ctrl_mm2s_cmd_addr = axi_address_w;
    assign m_ctrl_mm2s_cmd_btt = byte_count_w;
    assign m_ctrl_mm2s_cmd_offset = local_offset_w;
    assign m_ctrl_mm2s_cmd_bank = operand0_bank_w;
    assign m_ctrl_mm2s_cmd_tag = operand0_tag_w;
    assign m_ctrl_s2mm_cmd_addr = axi_address_w;
    assign m_ctrl_s2mm_cmd_btt = byte_count_w;
    assign m_ctrl_s2mm_cmd_offset = local_offset_w;
    assign m_ctrl_s2mm_cmd_bank = operand0_bank_w;
    assign m_ctrl_s2mm_cmd_tag = operand0_tag_w;
    assign m_ctrl_mm2s_sts_ready = aresetn && cmd_dispatcher_busy;
    assign m_ctrl_s2mm_sts_ready = aresetn && cmd_dispatcher_busy;
    assign mm2s_fire_w = m_ctrl_mm2s_cmd_valid && m_ctrl_mm2s_cmd_ready;
    assign s2mm_fire_w = m_ctrl_s2mm_cmd_valid && m_ctrl_s2mm_cmd_ready;
    assign fixed_request_fire_w = mm2s_fire_w || s2mm_fire_w;
    // USER_ISSUE_BEGIN
    always_comb begin
        m_ctrl_probe_cmd_valid = aresetn && state_r == EXECUTE && opcode_w == OP_PROBE;
        m_ctrl_probe_cmd_src = operand1_bank_w;
        m_ctrl_probe_cmd_dst = operand0_bank_w;
        user_request_valid_w = m_ctrl_probe_cmd_valid;
        user_request_ready_w = m_ctrl_probe_cmd_ready;
    end
    // USER_ISSUE_END
    assign user_request_fire_w = user_request_valid_w && user_request_ready_w;
    assign request_fire_w = fixed_request_fire_w || user_request_fire_w;

    always_comb begin
        mm2s_response_match_w = 1'b0; s2mm_response_match_w = 1'b0;
        if ({1'b0,s_ctrl_mm2s_sts_tag} < TAG_BANK_NUM_LIMIT) begin
            mm2s_response_match_w = pending_mm2s_r[s_ctrl_mm2s_sts_tag] &&
                !completed_mm2s_r[s_ctrl_mm2s_sts_tag] && bank_wr_busy[s_ctrl_mm2s_sts_tag] &&
                bank_wr_owner_port[s_ctrl_mm2s_sts_tag] == PORT_MM2S_ARBITER &&
                (issued_mm2s_r[s_ctrl_mm2s_sts_tag] ||
                 (mm2s_fire_w && s_ctrl_mm2s_sts_tag == operand0_tag_w));
        end
        if ({1'b0,s_ctrl_s2mm_sts_tag} < TAG_BANK_NUM_LIMIT) begin
            s2mm_response_match_w = pending_s2mm_r[s_ctrl_s2mm_sts_tag] &&
                !completed_s2mm_r[s_ctrl_s2mm_sts_tag] && bank_rd_busy[s_ctrl_s2mm_sts_tag] &&
                bank_rd_owner_port[s_ctrl_s2mm_sts_tag] == PORT_S2MM_ARBITER &&
                (issued_s2mm_r[s_ctrl_s2mm_sts_tag] ||
                 (s2mm_fire_w && s_ctrl_s2mm_sts_tag == operand0_tag_w));
        end
        fixed_response_fault_w =
            (s_ctrl_mm2s_sts_valid && m_ctrl_mm2s_sts_ready && !mm2s_response_match_w) ||
            (s_ctrl_s2mm_sts_valid && m_ctrl_s2mm_sts_ready && !s2mm_response_match_w);
        fixed_executor_fault_w =
            (s_ctrl_mm2s_sts_valid && m_ctrl_mm2s_sts_ready && mm2s_response_match_w && s_ctrl_mm2s_sts_error) ||
            (s_ctrl_s2mm_sts_valid && m_ctrl_s2mm_sts_ready && s2mm_response_match_w && s_ctrl_s2mm_sts_error);
        fixed_wr_release_valid_w = '0; fixed_rd_release_valid_w = '0;
        fixed_wr_release_port_w = '0; fixed_rd_release_port_w = '0;
        fixed_owner_fault_w = 1'b0;
        for (int b=0; b<BANK_NUM; b++) begin
            if (pending_mm2s_r[b] && (!bank_wr_busy[b] || bank_wr_owner_port[b] != PORT_MM2S_ARBITER))
                fixed_owner_fault_w = 1'b1;
            if (pending_s2mm_r[b] && (!bank_rd_busy[b] || bank_rd_owner_port[b] != PORT_S2MM_ARBITER))
                fixed_owner_fault_w = 1'b1;
            if (completed_mm2s_r[b] && pending_mm2s_r[b] && bank_wr_busy[b] &&
                bank_wr_owner_port[b] == PORT_MM2S_ARBITER) begin
                fixed_wr_release_valid_w[b] = 1'b1;
                fixed_wr_release_port_w[b] = PORT_MM2S_ARBITER;
            end
            if (completed_s2mm_r[b] && pending_s2mm_r[b] && !bank_rd_pending[b] && bank_rd_busy[b] &&
                bank_rd_owner_port[b] == PORT_S2MM_ARBITER) begin
                fixed_rd_release_valid_w[b] = 1'b1;
                fixed_rd_release_port_w[b] = PORT_S2MM_ARBITER;
            end
        end
    end
    // USER_COMPLETION_BEGIN
    always_comb begin
        m_ctrl_probe_sts_ready = aresetn && cmd_dispatcher_busy;
        probe_status_fire_w = s_ctrl_probe_sts_valid && m_ctrl_probe_sts_ready;
        probe_owner_fault_w = probe_pending_r &&
            (!bank_rd_busy[probe_src_r] || bank_rd_owner_port[probe_src_r] != PORT_PROBE_READ ||
             !bank_wr_busy[probe_dst_r] || bank_wr_owner_port[probe_dst_r] != PORT_PROBE_WRITE);
        probe_match_w = probe_pending_r && !probe_completed_r && !probe_owner_fault_w &&
            (probe_issued_r || user_request_fire_w) &&
            s_ctrl_probe_sts_src == probe_src_r && s_ctrl_probe_sts_dst == probe_dst_r;
        user_pending_any_w = probe_pending_r;
        user_bank_wr_release_valid_w = '0; user_bank_rd_release_valid_w = '0;
        user_bank_wr_release_port_w = '0; user_bank_rd_release_port_w = '0;
        if (probe_pending_r && probe_completed_r && !probe_owner_fault_w && !bank_rd_pending[probe_src_r]) begin
            user_bank_wr_release_valid_w[probe_dst_r] = 1'b1;
            user_bank_rd_release_valid_w[probe_src_r] = 1'b1;
            user_bank_wr_release_port_w[probe_dst_r] = PORT_PROBE_WRITE;
            user_bank_rd_release_port_w[probe_src_r] = PORT_PROBE_READ;
        end
        user_response_fault_w = probe_owner_fault_w || (probe_status_fire_w && !probe_match_w);
        user_executor_fault_w = probe_status_fire_w && probe_match_w && s_ctrl_probe_sts_error;
    end
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            probe_pending_r <= 1'b0; probe_issued_r <= 1'b0; probe_completed_r <= 1'b0;
            probe_src_r <= '0; probe_dst_r <= '0;
        end else begin
            if (user_acquire_fire_w) begin
                probe_pending_r <= 1'b1;
                probe_src_r <= operand1_bank_w; probe_dst_r <= operand0_bank_w;
            end
            if (user_request_fire_w) probe_issued_r <= 1'b1;
            if (probe_status_fire_w && probe_match_w) probe_completed_r <= 1'b1;
            if (probe_pending_r && bank_wr_release_valid[probe_dst_r] && bank_rd_release_valid[probe_src_r] &&
                bank_wr_release_accepted[probe_dst_r] && bank_rd_release_accepted[probe_src_r]) begin
                probe_pending_r <= 1'b0; probe_issued_r <= 1'b0; probe_completed_r <= 1'b0;
            end
        end
    end
    // USER_COMPLETION_END
    assign response_fault_w = fixed_response_fault_w || (cmd_dispatcher_busy && user_response_fault_w);
    assign executor_fault_w = fixed_executor_fault_w || (cmd_dispatcher_busy && user_executor_fault_w);
    assign acquire_attempt_w = aresetn && state_r == BANK_ACQUIRE && bank_eligible_w &&
        error_code_r == ERR_NONE && !bank_subsystem_error && !response_fault_w && !executor_fault_w;
    assign bank_wr_acquire_valid = acquire_attempt_w ? command_wr_mask_w : '0;
    assign bank_rd_acquire_valid = acquire_attempt_w ? command_rd_mask_w : '0;
    assign bank_wr_acquire_port = command_wr_roles_w;
    assign bank_rd_acquire_port = command_rd_roles_w;
    assign acquire_fire_w = acquire_attempt_w &&
        bank_wr_acquire_accepted == bank_wr_acquire_valid && bank_rd_acquire_accepted == bank_rd_acquire_valid;
    assign user_acquire_fire_w = acquire_fire_w && !fixed_opcode_w;
    assign bank_wr_release_valid = aresetn && !fail_stop_r && !bank_subsystem_error ?
        fixed_wr_release_valid_w | user_bank_wr_release_valid_w : '0;
    assign bank_rd_release_valid = aresetn && !fail_stop_r && !bank_subsystem_error ?
        fixed_rd_release_valid_w | user_bank_rd_release_valid_w : '0;
    assign bank_wr_release_port = fixed_wr_release_port_w | user_bank_wr_release_port_w;
    assign bank_rd_release_port = fixed_rd_release_port_w | user_bank_rd_release_port_w;
    assign bank_ack_fault_w =
        (acquire_attempt_w && !acquire_fire_w) ||
        (|bank_wr_release_valid && bank_wr_release_accepted != bank_wr_release_valid) ||
        (|bank_rd_release_valid && bank_rd_release_accepted != bank_rd_release_valid);
    assign hard_fault_w = cmd_dispatcher_busy &&
        (bank_subsystem_error || bank_ack_fault_w || fixed_owner_fault_w || response_fault_w);
    assign pending_any_w = |pending_mm2s_r || |pending_s2mm_r || user_pending_any_w;
    assign busy_any_w = |bank_wr_busy || |bank_rd_busy || |bank_rd_pending;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE; pc_r <= '0; fetch_count_r <= '0; command_r <= '0;
            error_code_r <= ERR_NONE; fail_stop_r <= 1'b0;
            pending_mm2s_r <= '0; pending_s2mm_r <= '0;
            issued_mm2s_r <= '0; issued_s2mm_r <= '0;
            completed_mm2s_r <= '0; completed_s2mm_r <= '0;
        end else begin
            // Completion matching allows a status on the same edge as engine
            // acceptance. Reservation was already established on an earlier edge.
            if (s_ctrl_mm2s_sts_valid && m_ctrl_mm2s_sts_ready && mm2s_response_match_w)
                completed_mm2s_r[s_ctrl_mm2s_sts_tag] <= 1'b1;
            if (s_ctrl_s2mm_sts_valid && m_ctrl_s2mm_sts_ready && s2mm_response_match_w)
                completed_s2mm_r[s_ctrl_s2mm_sts_tag] <= 1'b1;
            for (int b=0; b<BANK_NUM; b++) begin
                if (bank_wr_release_valid[b] && bank_wr_release_accepted[b] && pending_mm2s_r[b]) begin
                    pending_mm2s_r[b] <= 1'b0; issued_mm2s_r[b] <= 1'b0; completed_mm2s_r[b] <= 1'b0;
                end
                if (bank_rd_release_valid[b] && bank_rd_release_accepted[b] && pending_s2mm_r[b]) begin
                    pending_s2mm_r[b] <= 1'b0; issued_s2mm_r[b] <= 1'b0; completed_s2mm_r[b] <= 1'b0;
                end
            end
            if (acquire_fire_w && opcode_w == OP_MM2S) pending_mm2s_r[operand0_bank_w] <= 1'b1;
            if (acquire_fire_w && opcode_w == OP_S2MM) pending_s2mm_r[operand0_bank_w] <= 1'b1;
            if (mm2s_fire_w) issued_mm2s_r[operand0_bank_w] <= 1'b1;
            if (s2mm_fire_w) issued_s2mm_r[operand0_bank_w] <= 1'b1;
            if (hard_fault_w) fail_stop_r <= 1'b1;
            if (error_code_r == ERR_NONE && cmd_dispatcher_busy) begin
                if (bank_subsystem_error || fixed_owner_fault_w) error_code_r <= ERR_BANK;
                else if (bank_ack_fault_w) error_code_r <= ERR_BANK_ACK;
                else if (response_fault_w) error_code_r <= ERR_RESPONSE;
                else if (executor_fault_w) error_code_r <= ERR_EXECUTOR;
            end
            case (state_r)
                IDLE, DONE_STATE: if (cmd_dispatcher_start) begin
                    pc_r <= '0; fetch_count_r <= '0;
                    if (PARAMETERS_LEGAL) state_r <= CMD_READ;
                    else begin error_code_r <= ERR_PARAMETER; state_r <= ERROR_STATE; fail_stop_r <= 1'b1; end
                end
                CMD_READ: begin fetch_count_r <= FETCH_COUNT_WIDTH'(1); state_r <= CMD_WAIT; end
                CMD_WAIT: begin
                    if (fetch_count_r >= FETCH_LATENCY_COUNT) begin
                        command_r <= cmd_doutb; state_r <= OP_VERIFY;
                    end else fetch_count_r <= fetch_count_r + FETCH_COUNT_WIDTH'(1);
                end
                OP_VERIFY: begin
                    if (!opcode_known_w) begin
                        if (error_code_r == ERR_NONE && !hard_fault_w && !executor_fault_w) error_code_r <= ERR_OPCODE;
                        state_r <= ERROR_DRAIN;
                    end else if (!command_legal_w) begin
                        if (error_code_r == ERR_NONE && !hard_fault_w && !executor_fault_w) error_code_r <= ERR_OPERAND;
                        state_r <= ERROR_DRAIN;
                    end else if (opcode_w == OP_END) state_r <= END_DRAIN;
                    else state_r <= BANK_ACQUIRE;
                end
                BANK_ACQUIRE: if (acquire_fire_w) state_r <= EXECUTE;
                EXECUTE: if (request_fire_w) begin
                    if (pc_r == LAST_PC) begin
                        if (error_code_r == ERR_NONE && !hard_fault_w && !executor_fault_w) error_code_r <= ERR_MISSING_END;
                        state_r <= ERROR_DRAIN;
                    end else begin pc_r <= pc_r + CMD_ADDR_WIDTH'(1); state_r <= CMD_READ; end
                end
                END_DRAIN: if (!pending_any_w && !busy_any_w) state_r <= DONE_STATE;
                ERROR_DRAIN: if (!pending_any_w && !busy_any_w) state_r <= ERROR_STATE;
                ERROR_STATE: state_r <= ERROR_STATE; // coordinated reset is required
                default: begin
                    state_r <= ERROR_STATE; fail_stop_r <= 1'b1;
                    if (error_code_r == ERR_NONE && !hard_fault_w && !executor_fault_w)
                        error_code_r <= ERR_OPCODE;
                end
            endcase
            // Never retract a presented engine valid or mutate its command while
            // ready is low, even if another engine reports an error asynchronously.
            if (hard_fault_w || fail_stop_r) begin
                if (state_r != EXECUTE || request_fire_w) state_r <= ERROR_STATE;
            end else if ((executor_fault_w || error_code_r != ERR_NONE) &&
                         state_r != ERROR_DRAIN && state_r != ERROR_STATE) begin
                if (state_r != EXECUTE || request_fire_w) state_r <= ERROR_DRAIN;
            end
        end
    end
endmodule
