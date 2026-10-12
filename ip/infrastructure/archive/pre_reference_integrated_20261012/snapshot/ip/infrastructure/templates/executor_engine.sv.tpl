`timescale 1ns/1ps
// Per-operation engine authoring reference, not a numerical/model executor.
// An engine decodes its own opaque payload, drives its named bank endpoints,
// calls a core with held start/done, then drains before returning held context.
module __EXECUTOR_MODULE__ #(
    parameter int BANK_ID_WIDTH = __CONFIG_PKG__::BANK_NUM_WIDTH,
    parameter int CMD_BITS = __CONFIG_PKG__::CMD_DATA_WIDTH,
    parameter int OPCODE_WIDTH = __CONFIG_PKG__::OPCODE_WIDTH,
    parameter int PAYLOAD_WIDTH = CMD_BITS-OPCODE_WIDTH-5*BANK_ID_WIDTH
) (
    input logic aclk, aresetn,
    input logic s_ctrl_cmd_valid,
    output logic s_ctrl_cmd_ready,
    input logic [OPCODE_WIDTH-1:0] s_ctrl_cmd_opcode,
    input logic [3:0][BANK_ID_WIDTH-1:0] s_ctrl_cmd_src_bank,
    input logic [BANK_ID_WIDTH-1:0] s_ctrl_cmd_dst_bank,
    input logic [PAYLOAD_WIDTH-1:0] s_ctrl_cmd_payload,
    output logic m_ctrl_resp_valid,
    input logic m_ctrl_resp_ready,
    output logic [CMD_BITS-1:0] m_ctrl_resp_command,
    output logic m_ctrl_resp_error, m_ctrl_resp_clean,
    output logic [7:0] m_ctrl_resp_error_code
    // USER_PORTS_BEGIN
    // Named native bank request/response and core ports, prefixed by commas.
    // USER_PORTS_END
);
    // USER_PARAMETERS_BEGIN
    // Per-op widths, payload field positions and numeric behavior belong here.
    // USER_PARAMETERS_END
    typedef enum logic [2:0] {IDLE, RUN, REARM, DRAIN, RESPONSE, BLOCKED} state_t;
    state_t state_r;
    logic [OPCODE_WIDTH-1:0] opcode_r;
    logic [3:0][BANK_ID_WIDTH-1:0] src_bank_r;
    logic [BANK_ID_WIDTH-1:0] dst_bank_r;
    logic [PAYLOAD_WIDTH-1:0] payload_r;
    logic [CMD_BITS-1:0] command_r;
    logic response_error_r, response_clean_r;
    logic [7:0] response_error_code_r;
    logic command_legal_w;
    logic core_start_w, core_done_w, core_error_w, core_unclean_fault_w, drain_done_w;
    // USER_DECLARATIONS_BEGIN
    // Declare bank adapters, counters, latched payload decoding and real core wires.
    // USER_DECLARATIONS_END
    // USER_LEGALITY_BEGIN
    assign command_legal_w = 1'b0;
    // Unbound template rejects every request; replacing this alone is insufficient.
    // USER_LEGALITY_END
    assign s_ctrl_cmd_ready = aresetn && state_r == IDLE;
    assign core_start_w = aresetn && state_r == RUN;
    assign m_ctrl_resp_valid = aresetn && state_r == RESPONSE;
    assign m_ctrl_resp_command = command_r;
    assign m_ctrl_resp_error = response_error_r;
    assign m_ctrl_resp_clean = response_clean_r;
    assign m_ctrl_resp_error_code = response_error_code_r;
    // USER_DATAPATH_BEGIN
    assign core_done_w = 1'b0;
    assign core_error_w = 1'b0;
    assign core_unclean_fault_w = 1'b0;
    assign drain_done_w = 1'b0;
    // Instantiate a real core and native bank adapters here. core_start_w is held
    // until done; the core must clear done after start drops. drain_done_w means
    // every read response was consumed and every final write was accepted; no
    // bank request may follow a response. core_error_w is qualified by core_done_w;
    // drain_done_w must remain asserted after all work drains, or the operation's
    // adapter must latch that monotonic completion before driving this level.
    // Unsafe/non-drainable faults assert
    // core_unclean_fault_w; ownership is retained until a coherent reset.
    // USER_DATAPATH_END
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE; opcode_r <= '0; src_bank_r <= '0; dst_bank_r <= '0;
            payload_r <= '0; command_r <= '0; response_error_r <= 1'b0;
            response_clean_r <= 1'b0; response_error_code_r <= '0;
        end else begin
            case (state_r)
                IDLE: if (s_ctrl_cmd_valid && s_ctrl_cmd_ready) begin
                    opcode_r <= s_ctrl_cmd_opcode; src_bank_r <= s_ctrl_cmd_src_bank;
                    dst_bank_r <= s_ctrl_cmd_dst_bank; payload_r <= s_ctrl_cmd_payload;
                    // Header is MSB-first; SRC0 is first despite packed-array order.
                    command_r <= {s_ctrl_cmd_opcode, s_ctrl_cmd_src_bank[0],
                        s_ctrl_cmd_src_bank[1], s_ctrl_cmd_src_bank[2],
                        s_ctrl_cmd_src_bank[3], s_ctrl_cmd_dst_bank, s_ctrl_cmd_payload};
                    response_error_r <= !command_legal_w;
                    response_error_code_r <= command_legal_w ? 8'h00 : 8'h02;
                    response_clean_r <= !command_legal_w;
                    state_r <= command_legal_w ? RUN : RESPONSE;
                end
                RUN: if (core_done_w) begin
                    response_error_r <= core_error_w;
                    response_error_code_r <= core_error_w ? 8'h04 : 8'h00;
                    state_r <= REARM;
                end
                REARM: if (!core_done_w) state_r <= DRAIN;
                DRAIN: if (drain_done_w) begin response_clean_r <= 1'b1; state_r <= RESPONSE; end
                RESPONSE: if (m_ctrl_resp_ready) state_r <= response_clean_r ? IDLE : BLOCKED;
                BLOCKED: state_r <= BLOCKED;
                default: begin
                    state_r <= BLOCKED; response_error_r <= 1'b1;
                    response_clean_r <= 1'b0; response_error_code_r <= 8'h07;
                end
            endcase
            if (core_unclean_fault_w && (state_r == RUN || state_r == REARM || state_r == DRAIN)) begin
                response_error_r <= 1'b1; response_clean_r <= 1'b0;
                response_error_code_r <= 8'h08; state_r <= RESPONSE;
            end
        end
    end
endmodule
