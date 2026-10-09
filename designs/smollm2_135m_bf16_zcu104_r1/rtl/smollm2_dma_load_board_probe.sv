`timescale 1ns/1ps

// Bounded hardware probe for DDR -> ISA DMA_LOAD -> existing bank fabric.
// Opcode 4 is used only to acquire legal B0/B3 read roles in this test top.
// The probe does not implement RMSNORM and is never a model compute executor.
module smollm2_dma_load_board_probe (
    input  logic aclk, aresetn,
    input  logic [31:0] host_data0, host_data1, host_data2, host_data3,
    input  logic [31:0] host_control,
    output logic [31:0] host_status,
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
    input  logic datamover_mm2s_err
);
    typedef enum logic [3:0] {
        HOST_IDLE, HOST_WRITE_CMD, HOST_START, HOST_SEND_READ,
        HOST_WAIT_READ, HOST_SEND_DONE, HOST_ACK
    } host_state_t;
    host_state_t host_state_r;
    logic seq_seen_r, ack_seq_r, host_error_r;
    logic [3:0] host_bank_r;
    logic [15:0] host_addr_r, result_r;
    logic [127:0] host_data_r;
    logic probe_active_r, cmd_dispatcher_start;
    logic cmd_dispatcher_busy, cmd_dispatcher_done, cmd_dispatcher_error;
    logic [7:0] cmd_dispatcher_error_code;
    logic [9:0] current_pc, cmd_addrb;
    logic cmd_enb;
    logic [127:0] cmd_doutb;
    (* ram_style = "block" *) logic [127:0] command_bram [0:15];
    always_ff @(posedge aclk) begin
        if (host_state_r == HOST_WRITE_CMD)
            command_bram[host_addr_r[3:0]] <= host_data_r;
        if (cmd_enb) cmd_doutb <= command_bram[cmd_addrb[3:0]];
    end

    logic [6:0] compute_cmd_valid, compute_cmd_ready;
    logic [6:0][3:0] compute_cmd_opcode;
    logic [6:0][2:0][3:0] compute_cmd_bank;
    logic [6:0][111:0] compute_cmd_payload;
    logic [6:0] compute_done_valid, compute_done_ready;
    logic [6:0][3:0] compute_done_tag;
    logic [6:0][1:0] compute_done_bank_count;
    logic [6:0][2:0][3:0] compute_done_bank;
    logic [6:0] compute_done_error;
    logic [0:20] compute_role_read_valid, compute_role_read_ready;
    logic [0:20][3:0] compute_role_read_bank, compute_role_rsp_bank;
    logic [0:20][15:0] compute_role_read_addr;
    logic [0:20] compute_role_read_wide, compute_role_rsp_valid;
    logic [0:20][127:0] compute_role_rsp_data;
    logic [0:20][255:0] compute_role_rsp_wide_data;
    logic [0:20] compute_role_write_valid, compute_role_write_ready;
    logic [0:20][3:0] compute_role_write_bank;
    logic [0:20][15:0] compute_role_write_addr, compute_role_write_strb;
    logic [0:20][127:0] compute_role_write_data;
    logic [71:0] m_axis_s2mm_cmd_tdata;
    logic m_axis_s2mm_cmd_tvalid;
    logic [63:0] m_axis_s2mm_tdata;
    logic [7:0] m_axis_s2mm_tkeep;
    logic m_axis_s2mm_tvalid, m_axis_s2mm_tlast;
    logic s_axis_s2mm_sts_tready;
    logic [0:12] bank_busy;
    logic [0:12][4:0] bank_owner_port;
    logic [12:0] bank_tensor_valid;
    logic [12:0][15:0] tensor_progress;
    logic [12:0] write_pending;
    logic bank_tensor_state_error, subsystem_error, ownership_error;
    logic [1:0] subsystem_error_code;
    logic [2:0] ownership_error_code, router_error_code, bridge_fault_code;
    logic router_error, bridge_fault, external_role_fault;
    logic [4:0] router_error_role;
    logic [3:0] router_error_bank, bridge_fault_bank;
    logic system_recovery_required;

    smollm2_dma_control_fabric_wide fabric (
        .m_axis_s2mm_cmd_tready(1'b0),
        .m_axis_s2mm_tready(1'b0),
        .s_axis_s2mm_sts_tdata(8'd0),
        .s_axis_s2mm_sts_tkeep(1'b0),
        .s_axis_s2mm_sts_tvalid(1'b0),
        .s_axis_s2mm_sts_tlast(1'b0),
        .*
    );

    assign cmd_dispatcher_start = host_state_r == HOST_START;
    assign compute_cmd_ready = 7'(probe_active_r ? 0 : 7'b0000010);
    always_comb begin
        compute_done_valid = '0;
        compute_done_valid[1] = host_state_r == HOST_SEND_DONE;
        compute_done_tag = '0;
        compute_done_bank_count = '0;
        compute_done_bank_count[1] = 2'd3;
        compute_done_bank = '0;
        compute_done_bank[1][0] = 4'd0;
        compute_done_bank[1][1] = 4'd3;
        compute_done_bank[1][2] = 4'd2;
        compute_done_error = '0;
        compute_role_read_valid = '0;
        compute_role_read_bank = '0;
        compute_role_read_addr = '0;
        compute_role_read_wide = '0;
        if (host_state_r == HOST_SEND_READ) begin
            if (host_bank_r == 4'd0) begin
                compute_role_read_valid[6] = 1'b1;
                compute_role_read_bank[6] = 4'd0;
                compute_role_read_addr[6] = host_addr_r >> 3;
            end else if (host_bank_r == 4'd3) begin
                compute_role_read_valid[7] = 1'b1;
                compute_role_read_bank[7] = 4'd3;
                compute_role_read_addr[7] = host_addr_r >> 3;
            end
        end
        compute_role_write_valid = '0;
        compute_role_write_bank = '0;
        compute_role_write_addr = '0;
        compute_role_write_strb = '0;
        compute_role_write_data = '0;
    end
    assign host_status = {ack_seq_r, (host_state_r != HOST_IDLE),
                          probe_active_r,
                          (host_error_r || datamover_mm2s_err ||
                           system_recovery_required),
                          cmd_dispatcher_done, cmd_dispatcher_busy,
                          bank_tensor_valid[3], bank_tensor_valid[0],
                          8'd0, result_r};

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            host_state_r <= HOST_IDLE;
            seq_seen_r <= 1'b0; ack_seq_r <= 1'b0;
            host_error_r <= 1'b0; host_bank_r <= '0;
            host_addr_r <= '0; host_data_r <= '0;
            result_r <= '0; probe_active_r <= 1'b0;
        end else begin
            if (compute_cmd_valid[1] && compute_cmd_ready[1]) begin
                probe_active_r <= 1'b1;
                if (compute_cmd_opcode[1] != 4'd4 ||
                    compute_cmd_bank[1][0] != 4'd0 ||
                    compute_cmd_bank[1][1] != 4'd3 ||
                    compute_cmd_bank[1][2] != 4'd2 ||
                    compute_cmd_payload[1] != '0)
                    host_error_r <= 1'b1;
            end
            case (host_state_r)
                HOST_IDLE: if (host_control[31] != seq_seen_r) begin
                    seq_seen_r <= host_control[31];
                    host_bank_r <= host_control[27:24];
                    host_addr_r <= host_control[15:0];
                    host_data_r <= {host_data3, host_data2,
                                    host_data1, host_data0};
                    case (host_control[30:28])
                        3'd1: if (!cmd_dispatcher_busy &&
                                    !probe_active_r &&
                                    host_control[15:0] < 16)
                            host_state_r <= HOST_WRITE_CMD;
                        else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        3'd2: if (!cmd_dispatcher_busy &&
                                    !probe_active_r) begin
                            host_error_r <= 0;
                            host_state_r <= HOST_START;
                        end else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        3'd3: if (probe_active_r &&
                                    ((host_control[27:24] == 4'd0 &&
                                      host_control[15:0] < 16'd18432) ||
                                     (host_control[27:24] == 4'd3 &&
                                      host_control[15:0] < 16'd9216)))
                            host_state_r <= HOST_SEND_READ;
                        else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        3'd4: if (probe_active_r) host_state_r <= HOST_SEND_DONE;
                        else begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                        default: begin host_error_r <= 1; host_state_r <= HOST_ACK; end
                    endcase
                end
                HOST_WRITE_CMD: host_state_r <= HOST_ACK;
                HOST_START: host_state_r <= HOST_ACK;
                HOST_SEND_READ:
                    if ((host_bank_r == 0 && compute_role_read_ready[6]) ||
                        (host_bank_r == 3 && compute_role_read_ready[7]))
                        host_state_r <= HOST_WAIT_READ;
                HOST_WAIT_READ:
                    if ((host_bank_r == 0 && compute_role_rsp_valid[6]) ||
                        (host_bank_r == 3 && compute_role_rsp_valid[7])) begin
                        if (host_bank_r == 0)
                            result_r <= compute_role_rsp_data[6]
                                [16*host_addr_r[2:0] +: 16];
                        else
                            result_r <= compute_role_rsp_data[7]
                                [16*host_addr_r[2:0] +: 16];
                        host_state_r <= HOST_ACK;
                    end
                HOST_SEND_DONE: if (compute_done_ready[1]) begin
                    probe_active_r <= 1'b0;
                    host_state_r <= HOST_ACK;
                end
                HOST_ACK: begin ack_seq_r <= seq_seen_r; host_state_r <= HOST_IDLE; end
                default: host_state_r <= HOST_IDLE;
            endcase
        end
    end
endmodule
