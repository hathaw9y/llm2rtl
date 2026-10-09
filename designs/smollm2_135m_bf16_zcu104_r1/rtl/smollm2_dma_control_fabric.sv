`timescale 1ns/1ps

// DMA-capable control/data fabric. Compute channels and roles 3..20 attach
// externally; this module does not implement model tensor arithmetic.
module smollm2_dma_control_fabric (
    input  logic aclk,
    input  logic aresetn,
    input  logic cmd_dispatcher_start,
    output logic cmd_dispatcher_busy,
    output logic cmd_dispatcher_done,
    output logic cmd_dispatcher_error,
    output logic [7:0] cmd_dispatcher_error_code,
    output logic [9:0] current_pc,
    output logic cmd_enb,
    output logic [9:0] cmd_addrb,
    input  logic [127:0] cmd_doutb,

    output logic [6:0] compute_cmd_valid,
    input  logic [6:0] compute_cmd_ready,
    output logic [6:0][3:0] compute_cmd_opcode,
    output logic [6:0][2:0][3:0] compute_cmd_bank,
    output logic [6:0][111:0] compute_cmd_payload,
    input  logic [6:0] compute_done_valid,
    output logic [6:0] compute_done_ready,
    input  logic [6:0][3:0] compute_done_tag,
    input  logic [6:0][1:0] compute_done_bank_count,
    input  logic [6:0][2:0][3:0] compute_done_bank,
    input  logic [6:0] compute_done_error,

    input  logic [0:20] compute_role_read_valid,
    output logic [0:20] compute_role_read_ready,
    input  logic [0:20][3:0] compute_role_read_bank,
    input  logic [0:20][15:0] compute_role_read_addr,
    output logic [0:20] compute_role_rsp_valid,
    output logic [0:20][3:0] compute_role_rsp_bank,
    output logic [0:20][127:0] compute_role_rsp_data,
    input  logic [0:20] compute_role_write_valid,
    output logic [0:20] compute_role_write_ready,
    input  logic [0:20][3:0] compute_role_write_bank,
    input  logic [0:20][15:0] compute_role_write_addr,
    input  logic [0:20][15:0] compute_role_write_strb,
    input  logic [0:20][127:0] compute_role_write_data,

    output logic [71:0] m_axis_mm2s_cmd_tdata,
    output logic m_axis_mm2s_cmd_tvalid,
    input  logic m_axis_mm2s_cmd_tready,
    input  logic [63:0] s_axis_mm2s_tdata,
    input  logic [7:0] s_axis_mm2s_tkeep,
    input  logic s_axis_mm2s_tvalid,
    output logic s_axis_mm2s_tready,
    input  logic s_axis_mm2s_tlast,
    input  logic [7:0] s_axis_mm2s_sts_tdata,
    input  logic s_axis_mm2s_sts_tkeep,
    input  logic s_axis_mm2s_sts_tvalid,
    output logic s_axis_mm2s_sts_tready,
    input  logic s_axis_mm2s_sts_tlast,
    output logic [71:0] m_axis_s2mm_cmd_tdata,
    output logic m_axis_s2mm_cmd_tvalid,
    input  logic m_axis_s2mm_cmd_tready,
    output logic [63:0] m_axis_s2mm_tdata,
    output logic [7:0] m_axis_s2mm_tkeep,
    output logic m_axis_s2mm_tvalid,
    input  logic m_axis_s2mm_tready,
    output logic m_axis_s2mm_tlast,
    input  logic [7:0] s_axis_s2mm_sts_tdata,
    input  logic s_axis_s2mm_sts_tkeep,
    input  logic s_axis_s2mm_sts_tvalid,
    output logic s_axis_s2mm_sts_tready,
    input  logic s_axis_s2mm_sts_tlast,

    output logic [0:12] bank_busy,
    output logic [0:12][4:0] bank_owner_port,
    output logic [12:0] bank_tensor_valid,
    output logic [12:0][15:0] tensor_progress,
    output logic [12:0] write_pending,
    output logic bank_tensor_state_error,
    output logic subsystem_error,
    output logic [1:0] subsystem_error_code,
    output logic ownership_error,
    output logic [2:0] ownership_error_code,
    output logic router_error,
    output logic [2:0] router_error_code,
    output logic [4:0] router_error_role,
    output logic [3:0] router_error_bank,
    output logic bridge_fault,
    output logic [2:0] bridge_fault_code,
    output logic [3:0] bridge_fault_bank,
    output logic external_role_fault,
    output logic system_recovery_required
);
    logic [0:12] bank_acquire_valid, bank_release_valid;
    logic [0:12][4:0] bank_acquire_port, bank_release_port;
    logic [12:0] wr_issue_valid, wr_complete_valid, wr_complete_error;
    logic [12:0][1:0] wr_issue_kind;
    logic [12:0][15:0] wr_issue_index, wr_issue_count, wr_issue_total;
    logic [12:0] wr_issue_valid_r, wr_complete_valid_r, wr_complete_error_r;
    logic [12:0][1:0] wr_issue_kind_r;
    logic [12:0][15:0] wr_issue_index_r, wr_issue_count_r, wr_issue_total_r;
    logic [0:12] dispatcher_bank_busy;

    logic m_ctrl_mm2s_cmd_valid, m_ctrl_mm2s_cmd_ready;
    logic [31:0] m_ctrl_mm2s_cmd_addr, m_ctrl_mm2s_cmd_offset;
    logic [22:0] m_ctrl_mm2s_cmd_btt;
    logic [3:0] m_ctrl_mm2s_cmd_bank, m_ctrl_mm2s_cmd_tag;
    logic s_ctrl_mm2s_sts_valid, m_ctrl_mm2s_sts_ready;
    logic [3:0] s_ctrl_mm2s_sts_tag;
    logic s_ctrl_mm2s_sts_error;
    logic m_ctrl_s2mm_cmd_valid, m_ctrl_s2mm_cmd_ready;
    logic [31:0] m_ctrl_s2mm_cmd_addr, m_ctrl_s2mm_cmd_offset;
    logic [22:0] m_ctrl_s2mm_cmd_btt;
    logic [3:0] m_ctrl_s2mm_cmd_bank, m_ctrl_s2mm_cmd_tag;
    logic s_ctrl_s2mm_sts_valid, m_ctrl_s2mm_sts_ready;
    logic [3:0] s_ctrl_s2mm_sts_tag;
    logic s_ctrl_s2mm_sts_error;

    logic mm2s_cmd_valid, mm2s_cmd_ready, mm2s_sts_valid, mm2s_sts_ready;
    logic [31:0] mm2s_cmd_addr, mm2s_cmd_offset;
    logic [22:0] mm2s_cmd_btt;
    logic [3:0] mm2s_cmd_bank, mm2s_sts_tag;
    logic mm2s_sts_error;
    logic [7:0] mm2s_sts_error_code;
    logic s2mm_cmd_valid, s2mm_cmd_ready, s2mm_sts_valid, s2mm_sts_ready;
    logic [31:0] s2mm_cmd_addr, s2mm_cmd_offset;
    logic [22:0] s2mm_cmd_btt;
    logic [3:0] s2mm_cmd_bank, s2mm_sts_tag;
    logic s2mm_sts_error;
    logic [7:0] s2mm_sts_error_code;
    logic mm2s_engine_faulted, s2mm_engine_faulted, recovery_required;
    logic [3:0] mm2s_engine_status_tag, mm2s_engine_received_tag;
    logic [7:0] mm2s_engine_raw_status;
    logic [3:0] s2mm_engine_status_tag, s2mm_engine_received_tag;
    logic [7:0] s2mm_engine_raw_status;

    logic role1_write_valid, role1_write_ready;
    logic [3:0] role1_write_bank;
    logic [15:0] role1_write_addr, role1_write_strb;
    logic [127:0] role1_write_data;
    logic role2_read_valid, role2_read_ready, role2_rsp_valid;
    logic [3:0] role2_read_bank, role2_rsp_bank;
    logic [15:0] role2_read_addr;
    logic [127:0] role2_rsp_data;
    logic [0:20] role_read_valid, role_read_ready, role_rsp_valid;
    logic [0:20][3:0] role_read_bank, role_rsp_bank;
    logic [0:20][15:0] role_read_addr;
    logic [0:20][127:0] role_rsp_data;
    logic [0:20] role_write_valid, role_write_ready;
    logic [0:20][3:0] role_write_bank;
    logic [0:20][15:0] role_write_addr, role_write_strb;
    logic [0:20][127:0] role_write_data;

    assign mm2s_cmd_valid = m_ctrl_mm2s_cmd_valid;
    assign m_ctrl_mm2s_cmd_ready = mm2s_cmd_ready;
    assign mm2s_cmd_addr = m_ctrl_mm2s_cmd_addr;
    assign mm2s_cmd_btt = m_ctrl_mm2s_cmd_btt;
    assign mm2s_cmd_offset = m_ctrl_mm2s_cmd_offset;
    assign mm2s_cmd_bank = m_ctrl_mm2s_cmd_bank;
    assign s_ctrl_mm2s_sts_valid = mm2s_sts_valid;
    assign mm2s_sts_ready = m_ctrl_mm2s_sts_ready;
    assign s_ctrl_mm2s_sts_tag = mm2s_sts_tag;
    assign s_ctrl_mm2s_sts_error = mm2s_sts_error;
    assign s2mm_cmd_valid = m_ctrl_s2mm_cmd_valid;
    assign m_ctrl_s2mm_cmd_ready = s2mm_cmd_ready;
    assign s2mm_cmd_addr = m_ctrl_s2mm_cmd_addr;
    assign s2mm_cmd_btt = m_ctrl_s2mm_cmd_btt;
    assign s2mm_cmd_offset = m_ctrl_s2mm_cmd_offset;
    assign s2mm_cmd_bank = m_ctrl_s2mm_cmd_bank;
    assign s_ctrl_s2mm_sts_valid = s2mm_sts_valid;
    assign s2mm_sts_ready = m_ctrl_s2mm_sts_ready;
    assign s_ctrl_s2mm_sts_tag = s2mm_sts_tag;
    assign s_ctrl_s2mm_sts_error = s2mm_sts_error;

    // Break command decode to tensor-state arithmetic. Keep a bank ineligible
    // during the one-cycle event handoff, including after its owner releases it.
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            wr_issue_valid_r <= '0;
            wr_issue_kind_r <= '0;
            wr_issue_index_r <= '0;
            wr_issue_count_r <= '0;
            wr_issue_total_r <= '0;
            wr_complete_valid_r <= '0;
            wr_complete_error_r <= '0;
        end else begin
            wr_issue_valid_r <= wr_issue_valid;
            wr_issue_kind_r <= wr_issue_kind;
            wr_issue_index_r <= wr_issue_index;
            wr_issue_count_r <= wr_issue_count;
            wr_issue_total_r <= wr_issue_total;
            wr_complete_valid_r <= wr_complete_valid;
            wr_complete_error_r <= wr_complete_error;
        end
    end
    for (genvar bank = 0; bank < 13; bank++) begin : dispatcher_busy_guard
        assign dispatcher_bank_busy[bank] = bank_busy[bank] ||
            write_pending[bank] || wr_issue_valid_r[bank];
    end

    isa_command_dispatcher #(.BANK_NUM(13), .PORT_ROLE_WIDTH(5)) dispatcher (
        .bank_busy(dispatcher_bank_busy), .*
    );
    bank_tensor_state_tracker #(.BANK_NUM(13)) tracker (
        .aclk(aclk), .aresetn(aresetn), .wr_issue_valid(wr_issue_valid_r),
        .wr_issue_kind(wr_issue_kind_r), .wr_issue_index(wr_issue_index_r),
        .wr_issue_count(wr_issue_count_r), .wr_issue_total(wr_issue_total_r),
        .wr_complete_valid(wr_complete_valid_r),
        .wr_complete_error(wr_complete_error_r),
        .tensor_valid(bank_tensor_valid), .tensor_progress(tensor_progress),
        .write_pending(write_pending), .state_error(bank_tensor_state_error)
    );
    smollm2_dma_engine_link dma (.*);
    smollm2_bank_subsystem banks (.*);

    always_comb begin
        role_read_valid = compute_role_read_valid;
        role_read_bank = compute_role_read_bank;
        role_read_addr = compute_role_read_addr;
        role_write_valid = compute_role_write_valid;
        role_write_bank = compute_role_write_bank;
        role_write_addr = compute_role_write_addr;
        role_write_strb = compute_role_write_strb;
        role_write_data = compute_role_write_data;
        role_read_valid[0] = 1'b0;
        role_read_valid[1] = 1'b0;
        role_read_valid[2] = role2_read_valid;
        role_read_bank[2] = role2_read_bank;
        role_read_addr[2] = role2_read_addr;
        role_write_valid[0] = 1'b0;
        role_write_valid[1] = role1_write_valid;
        role_write_valid[2] = 1'b0;
        role_write_bank[1] = role1_write_bank;
        role_write_addr[1] = role1_write_addr;
        role_write_strb[1] = role1_write_strb;
        role_write_data[1] = role1_write_data;
        compute_role_read_ready = role_read_ready;
        compute_role_read_ready[0] = 1'b0;
        compute_role_read_ready[1] = 1'b0;
        compute_role_read_ready[2] = 1'b0;
        compute_role_rsp_valid = role_rsp_valid;
        compute_role_rsp_valid[0] = 1'b0;
        compute_role_rsp_valid[1] = 1'b0;
        compute_role_rsp_valid[2] = 1'b0;
        compute_role_rsp_bank = role_rsp_bank;
        compute_role_rsp_data = role_rsp_data;
        compute_role_write_ready = role_write_ready;
        compute_role_write_ready[0] = 1'b0;
        compute_role_write_ready[1] = 1'b0;
        compute_role_write_ready[2] = 1'b0;
    end
    assign role1_write_ready = role_write_ready[1];
    assign role2_read_ready = role_read_ready[2];
    assign role2_rsp_valid = role_rsp_valid[2];
    assign role2_rsp_bank = role_rsp_bank[2];
    assign role2_rsp_data = role_rsp_data[2];
    assign system_recovery_required = recovery_required || subsystem_error ||
                                      bank_tensor_state_error || external_role_fault ||
                                      cmd_dispatcher_error ||
                                      (cmd_dispatcher_busy &&
                                       (cmd_dispatcher_error_code != 8'h00));
    always_ff @(posedge aclk) begin
        if (!aresetn) external_role_fault <= 1'b0;
        else if (compute_role_read_valid[0] || compute_role_read_valid[1] ||
                 compute_role_read_valid[2] || compute_role_write_valid[0] ||
                 compute_role_write_valid[1] || compute_role_write_valid[2])
            external_role_fault <= 1'b1;
    end
endmodule
