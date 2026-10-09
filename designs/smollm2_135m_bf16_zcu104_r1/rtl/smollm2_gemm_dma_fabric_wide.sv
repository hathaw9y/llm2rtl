`timescale 1ns/1ps

// Bounded DMA/control composition with optional RMSNorm/RoPE/Softmax channels.
module smollm2_gemm_dma_fabric_wide #(
    parameter int DMA_DATA_WIDTH = 64,
    parameter bit REAL_RMS = 1'b0,
    parameter bit REAL_ROPE = 1'b0,
    parameter bit REAL_SOFTMAX = 1'b0,
    parameter bit PROBE_SCORE = 1'b0,
    parameter bit REAL_ATTENTION = 1'b0,
    parameter bit REAL_ADD = 1'b0,
    parameter bit REAL_SILU = 1'b0
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic cmd_dispatcher_start,
    output logic cmd_dispatcher_busy,
    output logic cmd_dispatcher_done,
    output logic cmd_dispatcher_error,
    output logic [7:0] cmd_dispatcher_error_code,
    output logic [18:0] profile_events,
    output logic [9:0] current_pc,
    output logic cmd_enb,
    output logic [9:0] cmd_addrb,
    input  logic [127:0] cmd_doutb,

    output logic [71:0] m_axis_mm2s_cmd_tdata,
    output logic m_axis_mm2s_cmd_tvalid,
    input  logic m_axis_mm2s_cmd_tready,
    input  logic [DMA_DATA_WIDTH-1:0] s_axis_mm2s_tdata,
    input  logic [DMA_DATA_WIDTH/8-1:0] s_axis_mm2s_tkeep,
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
    output logic [DMA_DATA_WIDTH-1:0] m_axis_s2mm_tdata,
    output logic [DMA_DATA_WIDTH/8-1:0] m_axis_s2mm_tkeep,
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
    output logic system_recovery_required,
    output logic gemm_write_accepted,
    output logic [3:0] gemm_write_bank,
    output logic [15:0] gemm_write_addr,
    output logic [15:0] gemm_write_strb,
    output logic [127:0] gemm_write_data,
    output logic rms_write_accepted,
    output logic [3:0] rms_write_bank,
    output logic [15:0] rms_write_addr,
    output logic [127:0] rms_write_data,
    output logic rope_write_accepted,
    output logic [3:0] rope_write_bank,
    output logic [15:0] rope_write_addr,
    output logic [127:0] rope_write_data,
    output logic softmax_write_accepted,
    output logic [3:0] softmax_write_bank,
    output logic [15:0] softmax_write_addr,
    output logic [127:0] softmax_write_data,
    output logic score_write_accepted,
    output logic [15:0] score_write_addr,
    output logic [15:0] score_write_strb,
    output logic [127:0] score_write_data,
    output logic value_write_accepted,
    output logic [15:0] value_write_addr,
    output logic [15:0] value_write_strb,
    output logic [127:0] value_write_data,
    output logic add_write_accepted,
    output logic [3:0] add_write_bank,
    output logic [15:0] add_write_addr,
    output logic [127:0] add_write_data,
    output logic silu_write_accepted,
    output logic [3:0] silu_write_bank,
    output logic [15:0] silu_write_addr,
    output logic [127:0] silu_write_data,
    output logic probe_cmd_valid,
    input  logic probe_cmd_ready,
    input  logic probe_done_valid,
    output logic probe_done_ready,
    input  logic probe_write_valid,
    output logic probe_write_ready,
    input  logic [15:0] probe_write_addr,
    input  logic [127:0] probe_write_data
);

    // Optional channels are disabled by default for older bounded probes.
    logic [6:0] compute_cmd_valid;
    logic [6:0] compute_cmd_ready;
    logic [6:0][3:0] compute_cmd_opcode;
    logic [6:0][2:0][3:0] compute_cmd_bank;
    logic [6:0][111:0] compute_cmd_payload;
    logic [6:0] compute_done_valid;
    logic [6:0] compute_done_ready;
    logic [6:0][3:0] compute_done_tag;
    logic [6:0][1:0] compute_done_bank_count;
    logic [6:0][2:0][3:0] compute_done_bank;
    logic [6:0] compute_done_error;
    logic [0:20] compute_role_read_valid;
    logic [0:20] compute_role_read_ready;
    logic [0:20][3:0] compute_role_read_bank;
    logic [0:20][15:0] compute_role_read_addr;
    logic [0:20] compute_role_read_wide;
    logic [0:20] compute_role_rsp_valid;
    logic [0:20][3:0] compute_role_rsp_bank;
    logic [0:20][127:0] compute_role_rsp_data;
    logic [0:20][255:0] compute_role_rsp_wide_data;
    logic [0:20] compute_role_write_valid;
    logic [0:20] compute_role_write_ready;
    logic [0:20][3:0] compute_role_write_bank;
    logic [0:20][15:0] compute_role_write_addr;
    logic [0:20][15:0] compute_role_write_strb;
    logic [0:20][127:0] compute_role_write_data;
    logic gemm_cmd_ready, gemm_done_valid, gemm_done_error;
    logic [3:0] gemm_done_tag;
    logic [1:0] gemm_done_bank_count;
    logic [2:0][3:0] gemm_done_bank;
    logic act_read_valid, act_read_ready, act_rsp_valid;
    logic [3:0] act_read_bank, act_rsp_bank;
    logic [15:0] act_read_addr;
    logic [255:0] act_rsp_data;
    logic weight_read_valid, weight_read_ready, weight_rsp_valid;
    logic [3:0] weight_read_bank, weight_rsp_bank;
    logic [15:0] weight_read_addr;
    logic [255:0] weight_rsp_data;
    logic dst_write_valid, dst_write_ready;
    logic [3:0] dst_write_bank;
    logic [15:0] dst_write_addr, dst_write_strb;
    logic [127:0] dst_write_data;
    logic gemm_pipe_valid_r;
    logic [2:0] gemm_owner_r;
    logic gemm_core_done_ready;
    logic [3:0] gemm_pipe_opcode_r;
    logic [2:0][3:0] gemm_pipe_bank_r;
    logic [111:0] gemm_pipe_payload_r;
    logic act_rsp_valid_r, weight_rsp_valid_r;
    logic [3:0] act_rsp_bank_r, weight_rsp_bank_r;
    logic [255:0] act_rsp_data_r, weight_rsp_data_r;
    logic rms_cmd_ready, rms_done_valid, rms_done_error;
    logic [3:0] rms_done_tag;
    logic [1:0] rms_done_bank_count;
    logic [2:0][3:0] rms_done_bank;
    logic rms_src_read_valid, rms_src_read_ready, rms_src_rsp_valid;
    logic [3:0] rms_src_read_bank, rms_src_rsp_bank;
    logic [15:0] rms_src_read_addr;
    logic [127:0] rms_src_rsp_data;
    logic rms_gamma_read_valid, rms_gamma_read_ready, rms_gamma_rsp_valid;
    logic [3:0] rms_gamma_read_bank, rms_gamma_rsp_bank;
    logic [15:0] rms_gamma_read_addr;
    logic [127:0] rms_gamma_rsp_data;
    logic rms_dst_write_valid, rms_dst_write_ready;
    logic [3:0] rms_dst_write_bank;
    logic [15:0] rms_dst_write_addr, rms_dst_write_strb;
    logic [127:0] rms_dst_write_data;
    logic rope_cmd_ready, rope_done_valid, rope_done_error;
    logic [3:0] rope_done_tag;
    logic [1:0] rope_done_bank_count;
    logic [2:0][3:0] rope_done_bank;
    logic rope_data_read_valid, rope_data_read_ready, rope_data_rsp_valid;
    logic [3:0] rope_data_read_bank, rope_data_rsp_bank;
    logic [15:0] rope_data_read_addr;
    logic [127:0] rope_data_rsp_data;
    logic rope_coeff_read_valid, rope_coeff_read_ready, rope_coeff_rsp_valid;
    logic [3:0] rope_coeff_read_bank, rope_coeff_rsp_bank;
    logic [15:0] rope_coeff_read_addr;
    logic [127:0] rope_coeff_rsp_data;
    logic rope_data_write_valid, rope_data_write_ready;
    logic [3:0] rope_data_write_bank;
    logic [15:0] rope_data_write_addr, rope_data_write_strb;
    logic [127:0] rope_data_write_data;
    logic softmax_cmd_ready, softmax_done_valid, softmax_done_error;
    logic [3:0] softmax_done_tag;
    logic [1:0] softmax_done_bank_count;
    logic [2:0][3:0] softmax_done_bank;
    logic softmax_data_read_valid, softmax_data_read_ready, softmax_data_rsp_valid;
    logic [3:0] softmax_data_read_bank, softmax_data_rsp_bank;
    logic [15:0] softmax_data_read_addr;
    logic [127:0] softmax_data_rsp_data;
    logic softmax_data_write_valid, softmax_data_write_ready;
    logic [3:0] softmax_data_write_bank;
    logic [15:0] softmax_data_write_addr, softmax_data_write_strb;
    logic [127:0] softmax_data_write_data;
    logic score_cmd_ready, score_done_valid, score_done_error;
    logic [3:0] score_done_tag;
    logic [1:0] score_done_bank_count;
    logic [2:0][3:0] score_done_bank;
    logic score_probe_write_valid;
    logic value_cmd_ready, value_done_valid, value_done_error;
    logic [3:0] value_done_tag;
    logic [1:0] value_done_bank_count;
    logic [2:0][3:0] value_done_bank;
    logic [1:0] attention_a_req, attention_a_ready, attention_a_rsp_valid;
    logic [1:0][3:0] attention_a_bank, attention_a_rsp_bank;
    logic [1:0][15:0] attention_a_addr;
    logic [1:0][127:0] attention_a_rsp_data;
    logic [1:0] attention_b_req, attention_b_ready, attention_b_rsp_valid;
    logic [1:0][3:0] attention_b_bank, attention_b_rsp_bank;
    logic [1:0][15:0] attention_b_addr;
    logic [1:0][127:0] attention_b_rsp_data;
    logic [1:0] attention_dst_valid, attention_dst_ready;
    logic [1:0][3:0] attention_dst_bank;
    logic [1:0][15:0] attention_dst_addr, attention_dst_strb;
    logic [1:0][127:0] attention_dst_data;
    logic add_cmd_ready, add_done_valid, add_done_error;
    logic [3:0] add_done_tag;
    logic [1:0] add_done_bank_count;
    logic [2:0][3:0] add_done_bank;
    logic add_left_read_valid, add_left_read_ready, add_left_rsp_valid;
    logic [3:0] add_left_read_bank, add_left_rsp_bank;
    logic [15:0] add_left_read_addr;
    logic [127:0] add_left_rsp_data;
    logic add_right_read_valid, add_right_read_ready, add_right_rsp_valid;
    logic [3:0] add_right_read_bank, add_right_rsp_bank;
    logic [15:0] add_right_read_addr;
    logic [127:0] add_right_rsp_data;
    logic add_dst_write_valid, add_dst_write_ready;
    logic [3:0] add_dst_write_bank;
    logic [15:0] add_dst_write_addr, add_dst_write_strb;
    logic [127:0] add_dst_write_data;
    logic vector_silu_r;
    logic silu_cmd_ready, silu_done_valid, silu_done_error;
    logic [3:0] silu_done_tag;
    logic [1:0] silu_done_bank_count;
    logic [2:0][3:0] silu_done_bank;
    logic silu_gate_read_valid, silu_gate_read_ready, silu_gate_rsp_valid;
    logic [3:0] silu_gate_read_bank, silu_gate_rsp_bank;
    logic [15:0] silu_gate_read_addr;
    logic [127:0] silu_gate_rsp_data;
    logic silu_up_read_valid, silu_up_read_ready, silu_up_rsp_valid;
    logic [3:0] silu_up_read_bank, silu_up_rsp_bank;
    logic [15:0] silu_up_read_addr;
    logic [127:0] silu_up_rsp_data;
    logic silu_dst_write_valid, silu_dst_write_ready;
    logic [3:0] silu_dst_write_bank;
    logic [15:0] silu_dst_write_addr, silu_dst_write_strb;
    logic [127:0] silu_dst_write_data;

    always_ff @(posedge aclk) begin
        if (!aresetn) vector_silu_r <= 1'b0;
        else if (compute_cmd_valid[6] && compute_cmd_ready[6])
            vector_silu_r <= compute_cmd_opcode[6] == 4'd10;
    end

    if (REAL_ADD) begin : real_add
        smollm2_add_executor add (
            .aclk(aclk), .aresetn(aresetn),
            .cmd_valid(compute_cmd_valid[6] && compute_cmd_opcode[6] == 4'd9),
            .cmd_ready(add_cmd_ready),
            .cmd_opcode(compute_cmd_opcode[6]),
            .cmd_bank(compute_cmd_bank[6]),
            .cmd_payload(compute_cmd_payload[6]),
            .done_valid(add_done_valid),
            .done_ready(compute_done_ready[6] && !vector_silu_r),
            .done_tag(add_done_tag), .done_bank_count(add_done_bank_count),
            .done_bank(add_done_bank), .done_error(add_done_error),
            .left_read_valid(add_left_read_valid),
            .left_read_ready(add_left_read_ready),
            .left_read_bank(add_left_read_bank),
            .left_read_addr(add_left_read_addr),
            .left_rsp_valid(add_left_rsp_valid),
            .left_rsp_bank(add_left_rsp_bank),
            .left_rsp_data(add_left_rsp_data),
            .right_read_valid(add_right_read_valid),
            .right_read_ready(add_right_read_ready),
            .right_read_bank(add_right_read_bank),
            .right_read_addr(add_right_read_addr),
            .right_rsp_valid(add_right_rsp_valid),
            .right_rsp_bank(add_right_rsp_bank),
            .right_rsp_data(add_right_rsp_data),
            .dst_write_valid(add_dst_write_valid),
            .dst_write_ready(add_dst_write_ready),
            .dst_write_bank(add_dst_write_bank),
            .dst_write_addr(add_dst_write_addr),
            .dst_write_strb(add_dst_write_strb),
            .dst_write_data(add_dst_write_data)
        );
    end else begin : no_add
        assign add_cmd_ready = 1'b0;
        assign add_done_valid = 1'b0;
        assign add_done_error = 1'b0;
        assign add_done_tag = '0;
        assign add_done_bank_count = '0;
        assign add_done_bank = '0;
        assign add_left_read_valid = 1'b0;
        assign add_left_read_bank = '0;
        assign add_left_read_addr = '0;
        assign add_right_read_valid = 1'b0;
        assign add_right_read_bank = '0;
        assign add_right_read_addr = '0;
        assign add_dst_write_valid = 1'b0;
        assign add_dst_write_bank = '0;
        assign add_dst_write_addr = '0;
        assign add_dst_write_strb = '0;
        assign add_dst_write_data = '0;
    end

    if (REAL_SILU) begin : real_silu
        smollm2_silu_mul_executor silu_mul (
            .aclk(aclk), .aresetn(aresetn),
            .cmd_valid(compute_cmd_valid[6] && compute_cmd_opcode[6] == 4'd10),
            .cmd_ready(silu_cmd_ready),
            .cmd_opcode(compute_cmd_opcode[6]),
            .cmd_bank(compute_cmd_bank[6]),
            .cmd_payload(compute_cmd_payload[6]),
            .done_valid(silu_done_valid),
            .done_ready(compute_done_ready[6] && vector_silu_r),
            .done_tag(silu_done_tag),
            .done_bank_count(silu_done_bank_count),
            .done_bank(silu_done_bank),
            .done_error(silu_done_error),
            .gate_read_valid(silu_gate_read_valid),
            .gate_read_ready(silu_gate_read_ready),
            .gate_read_bank(silu_gate_read_bank),
            .gate_read_addr(silu_gate_read_addr),
            .gate_rsp_valid(silu_gate_rsp_valid),
            .gate_rsp_bank(silu_gate_rsp_bank),
            .gate_rsp_data(silu_gate_rsp_data),
            .up_read_valid(silu_up_read_valid),
            .up_read_ready(silu_up_read_ready),
            .up_read_bank(silu_up_read_bank),
            .up_read_addr(silu_up_read_addr),
            .up_rsp_valid(silu_up_rsp_valid),
            .up_rsp_bank(silu_up_rsp_bank),
            .up_rsp_data(silu_up_rsp_data),
            .dst_write_valid(silu_dst_write_valid),
            .dst_write_ready(silu_dst_write_ready),
            .dst_write_bank(silu_dst_write_bank),
            .dst_write_addr(silu_dst_write_addr),
            .dst_write_strb(silu_dst_write_strb),
            .dst_write_data(silu_dst_write_data)
        );
    end else begin : no_silu
        assign silu_cmd_ready = 1'b0;
        assign silu_done_valid = 1'b0;
        assign silu_done_error = 1'b0;
        assign silu_done_tag = '0;
        assign silu_done_bank_count = '0;
        assign silu_done_bank = '0;
        assign silu_gate_read_valid = 1'b0;
        assign silu_gate_read_bank = '0;
        assign silu_gate_read_addr = '0;
        assign silu_up_read_valid = 1'b0;
        assign silu_up_read_bank = '0;
        assign silu_up_read_addr = '0;
        assign silu_dst_write_valid = 1'b0;
        assign silu_dst_write_bank = '0;
        assign silu_dst_write_addr = '0;
        assign silu_dst_write_strb = '0;
        assign silu_dst_write_data = '0;
    end

    if (REAL_ATTENTION) begin : real_attention
        assign score_cmd_ready = !gemm_pipe_valid_r;
        assign score_done_valid = gemm_done_valid && gemm_owner_r == 3;
        assign score_done_error = gemm_done_error;
        assign score_done_tag = gemm_done_tag;
        assign score_done_bank_count = gemm_done_bank_count;
        assign score_done_bank = gemm_done_bank;
        assign value_cmd_ready = !gemm_pipe_valid_r;
        assign value_done_valid = gemm_done_valid && gemm_owner_r == 5;
        assign value_done_error = gemm_done_error;
        assign value_done_tag = gemm_done_tag;
        assign value_done_bank_count = gemm_done_bank_count;
        assign value_done_bank = gemm_done_bank;
        assign attention_a_req = '0;
        assign attention_a_bank = '0;
        assign attention_a_addr = '0;
        assign attention_b_req = '0;
        assign attention_b_bank = '0;
        assign attention_b_addr = '0;
        assign attention_dst_valid = '0;
        assign attention_dst_bank = '0;
        assign attention_dst_addr = '0;
        assign attention_dst_strb = '0;
        assign attention_dst_data = '0;
        assign score_probe_write_valid = 1'b0;
    end else if (PROBE_SCORE) begin : probe_score
        assign score_cmd_ready = probe_cmd_ready;
        assign score_done_valid = probe_done_valid;
        assign score_done_error = 1'b0;
        assign score_done_tag = 4'd4;
        assign score_done_bank_count = 2'd3;
        assign score_done_bank = {4'd10, 4'd8, 4'd4};
        assign score_probe_write_valid = probe_write_valid;
    end else begin : no_probe_score
        assign score_cmd_ready = 1'b0;
        assign score_done_valid = 1'b0;
        assign score_done_error = 1'b0;
        assign score_done_tag = '0;
        assign score_done_bank_count = '0;
        assign score_done_bank = '0;
        assign score_probe_write_valid = 1'b0;
    end

    if (!REAL_ATTENTION) begin : no_attention
        assign attention_a_req = '0;
        assign attention_a_bank = '0;
        assign attention_a_addr = '0;
        assign attention_b_req = '0;
        assign attention_b_bank = '0;
        assign attention_b_addr = '0;
        assign attention_dst_valid = '0;
        assign attention_dst_bank = '0;
        assign attention_dst_addr = '0;
        assign attention_dst_strb = '0;
        assign attention_dst_data = '0;
        assign value_cmd_ready = 1'b0;
        assign value_done_valid = 1'b0;
        assign value_done_error = 1'b0;
        assign value_done_tag = '0;
        assign value_done_bank_count = '0;
        assign value_done_bank = '0;
    end

    if (REAL_SOFTMAX) begin : real_softmax
        smollm2_softmax_executor softmax (
            .aclk(aclk), .aresetn(aresetn),
            .cmd_valid(compute_cmd_valid[4]), .cmd_ready(softmax_cmd_ready),
            .cmd_opcode(compute_cmd_opcode[4]),
            .cmd_bank(compute_cmd_bank[4]),
            .cmd_payload(compute_cmd_payload[4]),
            .done_valid(softmax_done_valid),
            .done_ready(compute_done_ready[4]),
            .done_tag(softmax_done_tag),
            .done_bank_count(softmax_done_bank_count),
            .done_bank(softmax_done_bank),
            .done_error(softmax_done_error),
            .data_read_valid(softmax_data_read_valid),
            .data_read_ready(softmax_data_read_ready),
            .data_read_bank(softmax_data_read_bank),
            .data_read_addr(softmax_data_read_addr),
            .data_rsp_valid(softmax_data_rsp_valid),
            .data_rsp_bank(softmax_data_rsp_bank),
            .data_rsp_data(softmax_data_rsp_data),
            .data_write_valid(softmax_data_write_valid),
            .data_write_ready(softmax_data_write_ready),
            .data_write_bank(softmax_data_write_bank),
            .data_write_addr(softmax_data_write_addr),
            .data_write_strb(softmax_data_write_strb),
            .data_write_data(softmax_data_write_data)
        );
    end else begin : no_softmax
        assign softmax_cmd_ready = 1'b0;
        assign softmax_done_valid = 1'b0;
        assign softmax_done_tag = '0;
        assign softmax_done_bank_count = '0;
        assign softmax_done_bank = '0;
        assign softmax_done_error = 1'b0;
        assign softmax_data_read_valid = 1'b0;
        assign softmax_data_read_bank = '0;
        assign softmax_data_read_addr = '0;
        assign softmax_data_write_valid = 1'b0;
        assign softmax_data_write_bank = '0;
        assign softmax_data_write_addr = '0;
        assign softmax_data_write_strb = '0;
        assign softmax_data_write_data = '0;
    end

    if (REAL_ROPE) begin : real_rope
        smollm2_rope_executor rope (
            .aclk(aclk), .aresetn(aresetn),
            .cmd_valid(compute_cmd_valid[2]), .cmd_ready(rope_cmd_ready),
            .cmd_opcode(compute_cmd_opcode[2]),
            .cmd_bank(compute_cmd_bank[2]),
            .cmd_payload(compute_cmd_payload[2]),
            .done_valid(rope_done_valid), .done_ready(compute_done_ready[2]),
            .done_tag(rope_done_tag),
            .done_bank_count(rope_done_bank_count),
            .done_bank(rope_done_bank), .done_error(rope_done_error),
            .data_read_valid(rope_data_read_valid),
            .data_read_ready(rope_data_read_ready),
            .data_read_bank(rope_data_read_bank),
            .data_read_addr(rope_data_read_addr),
            .data_rsp_valid(rope_data_rsp_valid),
            .data_rsp_bank(rope_data_rsp_bank),
            .data_rsp_data(rope_data_rsp_data),
            .coeff_read_valid(rope_coeff_read_valid),
            .coeff_read_ready(rope_coeff_read_ready),
            .coeff_read_bank(rope_coeff_read_bank),
            .coeff_read_addr(rope_coeff_read_addr),
            .coeff_rsp_valid(rope_coeff_rsp_valid),
            .coeff_rsp_bank(rope_coeff_rsp_bank),
            .coeff_rsp_data(rope_coeff_rsp_data),
            .data_write_valid(rope_data_write_valid),
            .data_write_ready(rope_data_write_ready),
            .data_write_bank(rope_data_write_bank),
            .data_write_addr(rope_data_write_addr),
            .data_write_strb(rope_data_write_strb),
            .data_write_data(rope_data_write_data)
        );
    end else begin : no_rope
        assign rope_cmd_ready = 1'b0;
        assign rope_done_valid = 1'b0;
        assign rope_done_tag = '0;
        assign rope_done_bank_count = '0;
        assign rope_done_bank = '0;
        assign rope_done_error = 1'b0;
        assign rope_data_read_valid = 1'b0;
        assign rope_data_read_bank = '0;
        assign rope_data_read_addr = '0;
        assign rope_coeff_read_valid = 1'b0;
        assign rope_coeff_read_bank = '0;
        assign rope_coeff_read_addr = '0;
        assign rope_data_write_valid = 1'b0;
        assign rope_data_write_bank = '0;
        assign rope_data_write_addr = '0;
        assign rope_data_write_strb = '0;
        assign rope_data_write_data = '0;
    end

    if (REAL_RMS) begin : real_rms
        smollm2_rmsnorm_executor rms (
            .aclk(aclk), .aresetn(aresetn),
            .cmd_valid(compute_cmd_valid[1]),
            .cmd_ready(rms_cmd_ready),
            .cmd_opcode(compute_cmd_opcode[1]),
            .cmd_bank(compute_cmd_bank[1]),
            .cmd_payload(compute_cmd_payload[1]),
            .done_valid(rms_done_valid),
            .done_ready(compute_done_ready[1]),
            .done_tag(rms_done_tag),
            .done_bank_count(rms_done_bank_count),
            .done_bank(rms_done_bank),
            .done_error(rms_done_error),
            .src_read_valid(rms_src_read_valid),
            .src_read_ready(rms_src_read_ready),
            .src_read_bank(rms_src_read_bank),
            .src_read_addr(rms_src_read_addr),
            .src_rsp_valid(rms_src_rsp_valid),
            .src_rsp_bank(rms_src_rsp_bank),
            .src_rsp_data(rms_src_rsp_data),
            .gamma_read_valid(rms_gamma_read_valid),
            .gamma_read_ready(rms_gamma_read_ready),
            .gamma_read_bank(rms_gamma_read_bank),
            .gamma_read_addr(rms_gamma_read_addr),
            .gamma_rsp_valid(rms_gamma_rsp_valid),
            .gamma_rsp_bank(rms_gamma_rsp_bank),
            .gamma_rsp_data(rms_gamma_rsp_data),
            .dst_write_valid(rms_dst_write_valid),
            .dst_write_ready(rms_dst_write_ready),
            .dst_write_bank(rms_dst_write_bank),
            .dst_write_addr(rms_dst_write_addr),
            .dst_write_strb(rms_dst_write_strb),
            .dst_write_data(rms_dst_write_data)
        );
    end else begin : probe_rms
        assign rms_cmd_ready = probe_cmd_ready;
        assign rms_done_valid = probe_done_valid;
        assign rms_done_tag = 4'd0;
        assign rms_done_bank_count = 2'd3;
        assign rms_done_bank = {4'd2, 4'd3, 4'd0};
        assign rms_done_error = 1'b0;
        assign rms_src_read_valid = 1'b0;
        assign rms_src_read_bank = '0;
        assign rms_src_read_addr = '0;
        assign rms_gamma_read_valid = 1'b0;
        assign rms_gamma_read_bank = '0;
        assign rms_gamma_read_addr = '0;
        assign rms_dst_write_valid = probe_write_valid;
        assign rms_dst_write_bank = 4'd2;
        assign rms_dst_write_addr = probe_write_addr;
        assign rms_dst_write_strb = 16'hffff;
        assign rms_dst_write_data = probe_write_data;
    end

    // The dispatcher has already checked ISA legality when this register
    // accepts the record. GEMM sees it on the following clock edge.
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            gemm_pipe_valid_r <= 1'b0;
            gemm_owner_r <= '0;
            gemm_pipe_opcode_r <= '0;
            gemm_pipe_bank_r <= '0;
            gemm_pipe_payload_r <= '0;
        end else if (!gemm_pipe_valid_r &&
                     (compute_cmd_valid[0] ||
                      (REAL_ATTENTION && (compute_cmd_valid[3] ||
                                          compute_cmd_valid[5])))) begin
            gemm_pipe_valid_r <= 1'b1;
            gemm_owner_r <= compute_cmd_valid[0] ? 3'd0 :
                            compute_cmd_valid[3] ? 3'd3 : 3'd5;
            gemm_pipe_opcode_r <= compute_cmd_valid[0] ?
                compute_cmd_opcode[0] : compute_cmd_valid[3] ?
                compute_cmd_opcode[3] : compute_cmd_opcode[5];
            gemm_pipe_bank_r <= compute_cmd_valid[0] ?
                compute_cmd_bank[0] : compute_cmd_valid[3] ?
                compute_cmd_bank[3] : compute_cmd_bank[5];
            gemm_pipe_payload_r <= compute_cmd_valid[0] ?
                compute_cmd_payload[0] : compute_cmd_valid[3] ?
                compute_cmd_payload[3] : compute_cmd_payload[5];
        end else if (gemm_pipe_valid_r && gemm_cmd_ready) begin
            gemm_pipe_valid_r <= 1'b0;
        end
    end

    // The router response has no backpressure. GEMM issues at most one
    // outstanding read per role, so a one-cycle registered boundary keeps
    // each data word, bank ID and valid indication aligned.
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            act_rsp_valid_r <= 1'b0;
            weight_rsp_valid_r <= 1'b0;
            act_rsp_bank_r <= '0;
            weight_rsp_bank_r <= '0;
            act_rsp_data_r <= '0;
            weight_rsp_data_r <= '0;
        end else begin
            act_rsp_valid_r <= compute_role_rsp_valid[gemm_owner_r == 3 ? 11 :
                                                    gemm_owner_r == 5 ? 15 : 3];
            weight_rsp_valid_r <= compute_role_rsp_valid[gemm_owner_r == 3 ? 12 :
                                                       gemm_owner_r == 5 ? 16 : 4];
            if (compute_role_rsp_valid[gemm_owner_r == 3 ? 11 :
                                       gemm_owner_r == 5 ? 15 : 3]) begin
                act_rsp_bank_r <= compute_role_rsp_bank[gemm_owner_r == 3 ? 11 :
                                                      gemm_owner_r == 5 ? 15 : 3];
                act_rsp_data_r <= gemm_owner_r == 0 ?
                    compute_role_rsp_wide_data[3] :
                    {128'd0, compute_role_rsp_data[gemm_owner_r == 3 ? 11 : 15]};
            end
            if (compute_role_rsp_valid[gemm_owner_r == 3 ? 12 :
                                       gemm_owner_r == 5 ? 16 : 4]) begin
                weight_rsp_bank_r <= compute_role_rsp_bank[gemm_owner_r == 3 ? 12 :
                                                         gemm_owner_r == 5 ? 16 : 4];
                weight_rsp_data_r <= gemm_owner_r == 0 ?
                    compute_role_rsp_wide_data[4] :
                    {128'd0, compute_role_rsp_data[gemm_owner_r == 3 ? 12 : 16]};
            end
        end
    end

    smollm2_dma_control_fabric_wide #(
        .DMA_DATA_WIDTH(DMA_DATA_WIDTH),
        .ALLOW_ZERO_RMS_PROBE(!REAL_RMS)
    ) fabric (.*);
    smollm2_gemm_systolic_wide_executor gemm (
        .aclk(aclk), .aresetn(aresetn),
        .cmd_valid(gemm_pipe_valid_r), .cmd_ready(gemm_cmd_ready),
        .cmd_opcode(gemm_pipe_opcode_r),
        .cmd_bank(gemm_pipe_bank_r),
        .cmd_payload(gemm_pipe_payload_r),
        .done_valid(gemm_done_valid), .done_ready(gemm_core_done_ready),
        .done_tag(gemm_done_tag), .done_bank_count(gemm_done_bank_count),
        .done_bank(gemm_done_bank), .done_error(gemm_done_error),
        .act_read_valid(act_read_valid), .act_read_ready(act_read_ready),
        .act_read_bank(act_read_bank), .act_read_addr(act_read_addr),
        .act_rsp_valid(act_rsp_valid), .act_rsp_bank(act_rsp_bank),
        .act_rsp_data(act_rsp_data),
        .weight_read_valid(weight_read_valid),
        .weight_read_ready(weight_read_ready),
        .weight_read_bank(weight_read_bank),
        .weight_read_addr(weight_read_addr),
        .weight_rsp_valid(weight_rsp_valid),
        .weight_rsp_bank(weight_rsp_bank),
        .weight_rsp_data(weight_rsp_data),
        .dst_write_valid(dst_write_valid), .dst_write_ready(dst_write_ready),
        .dst_write_bank(dst_write_bank), .dst_write_addr(dst_write_addr),
        .dst_write_strb(dst_write_strb), .dst_write_data(dst_write_data)
    );

    always_comb begin
        compute_cmd_ready = '0;
        compute_cmd_ready[0] = !gemm_pipe_valid_r;
        compute_cmd_ready[1] = rms_cmd_ready;
        compute_cmd_ready[2] = rope_cmd_ready;
        compute_cmd_ready[3] = score_cmd_ready;
        compute_cmd_ready[4] = softmax_cmd_ready;
        compute_cmd_ready[5] = value_cmd_ready;
        compute_cmd_ready[6] = compute_cmd_opcode[6] == 4'd10 ?
                               silu_cmd_ready : add_cmd_ready;
        compute_done_valid = '0;
        compute_done_valid[0] = gemm_done_valid && gemm_owner_r == 0;
        compute_done_valid[1] = rms_done_valid;
        compute_done_valid[2] = rope_done_valid;
        compute_done_valid[3] = score_done_valid;
        compute_done_valid[4] = softmax_done_valid;
        compute_done_valid[5] = value_done_valid;
        compute_done_valid[6] = vector_silu_r ? silu_done_valid : add_done_valid;
        compute_done_tag = '0;
        compute_done_tag[0] = gemm_done_tag;
        compute_done_bank_count = '0;
        compute_done_bank_count[0] = gemm_done_bank_count;
        compute_done_bank_count[1] = rms_done_bank_count;
        compute_done_bank_count[2] = rope_done_bank_count;
        compute_done_bank_count[3] = score_done_bank_count;
        compute_done_bank_count[4] = softmax_done_bank_count;
        compute_done_bank_count[5] = value_done_bank_count;
        compute_done_bank_count[6] = vector_silu_r ?
                                     silu_done_bank_count : add_done_bank_count;
        compute_done_bank = '0;
        compute_done_bank[0] = gemm_done_bank;
        compute_done_bank[1] = rms_done_bank;
        compute_done_bank[2] = rope_done_bank;
        compute_done_bank[3] = score_done_bank;
        compute_done_bank[4] = softmax_done_bank;
        compute_done_bank[5] = value_done_bank;
        compute_done_bank[6] = vector_silu_r ? silu_done_bank : add_done_bank;
        compute_done_error = '0;
        compute_done_error[0] = gemm_done_error;
        compute_done_error[1] = rms_done_error;
        compute_done_error[2] = rope_done_error;
        compute_done_error[3] = score_done_error;
        compute_done_error[4] = softmax_done_error;
        compute_done_error[5] = value_done_error;
        compute_done_error[6] = vector_silu_r ? silu_done_error : add_done_error;
        compute_done_tag[1] = rms_done_tag;
        compute_done_tag[2] = rope_done_tag;
        compute_done_tag[3] = score_done_tag;
        compute_done_tag[4] = softmax_done_tag;
        compute_done_tag[5] = value_done_tag;
        compute_done_tag[6] = vector_silu_r ? silu_done_tag : add_done_tag;

        compute_role_read_valid = '0;
        compute_role_read_bank = '0;
        compute_role_read_addr = '0;
        compute_role_read_wide = '0;
        compute_role_read_valid[3] = gemm_owner_r == 0 && act_read_valid;
        compute_role_read_bank[3] = act_read_bank;
        compute_role_read_addr[3] = act_read_addr;
        compute_role_read_wide[3] = 1'b1;
        compute_role_read_valid[4] = gemm_owner_r == 0 && weight_read_valid;
        compute_role_read_bank[4] = weight_read_bank;
        compute_role_read_addr[4] = weight_read_addr;
        compute_role_read_wide[4] = 1'b1;
        compute_role_read_valid[6] = rms_src_read_valid;
        compute_role_read_bank[6] = rms_src_read_bank;
        compute_role_read_addr[6] = rms_src_read_addr;
        compute_role_read_valid[7] = rms_gamma_read_valid;
        compute_role_read_bank[7] = rms_gamma_read_bank;
        compute_role_read_addr[7] = rms_gamma_read_addr;
        compute_role_read_valid[9] = rope_data_read_valid;
        compute_role_read_bank[9] = rope_data_read_bank;
        compute_role_read_addr[9] = rope_data_read_addr;
        compute_role_read_valid[10] = rope_coeff_read_valid;
        compute_role_read_bank[10] = rope_coeff_read_bank;
        compute_role_read_addr[10] = rope_coeff_read_addr;
        compute_role_read_valid[14] = softmax_data_read_valid;
        compute_role_read_bank[14] = softmax_data_read_bank;
        compute_role_read_addr[14] = softmax_data_read_addr;
        compute_role_read_valid[11] = REAL_ATTENTION && gemm_owner_r == 3 && act_read_valid;
        compute_role_read_bank[11] = act_read_bank;
        compute_role_read_addr[11] = act_read_addr;
        compute_role_read_valid[12] = REAL_ATTENTION && gemm_owner_r == 3 && weight_read_valid;
        compute_role_read_bank[12] = weight_read_bank;
        compute_role_read_addr[12] = weight_read_addr;
        compute_role_read_valid[15] = REAL_ATTENTION && gemm_owner_r == 5 && act_read_valid;
        compute_role_read_bank[15] = act_read_bank;
        compute_role_read_addr[15] = act_read_addr;
        compute_role_read_valid[16] = REAL_ATTENTION && gemm_owner_r == 5 && weight_read_valid;
        compute_role_read_bank[16] = weight_read_bank;
        compute_role_read_addr[16] = weight_read_addr;
        compute_role_read_valid[18] = vector_silu_r ?
                                      silu_gate_read_valid : add_left_read_valid;
        compute_role_read_bank[18] = vector_silu_r ?
                                     silu_gate_read_bank : add_left_read_bank;
        compute_role_read_addr[18] = vector_silu_r ?
                                     silu_gate_read_addr : add_left_read_addr;
        compute_role_read_valid[19] = vector_silu_r ?
                                      silu_up_read_valid : add_right_read_valid;
        compute_role_read_bank[19] = vector_silu_r ?
                                     silu_up_read_bank : add_right_read_bank;
        compute_role_read_addr[19] = vector_silu_r ?
                                     silu_up_read_addr : add_right_read_addr;
        compute_role_write_valid = '0;
        compute_role_write_bank = '0;
        compute_role_write_addr = '0;
        compute_role_write_strb = '0;
        compute_role_write_data = '0;
        compute_role_write_valid[5] = gemm_owner_r == 0 && dst_write_valid;
        compute_role_write_bank[5] = dst_write_bank;
        compute_role_write_addr[5] = dst_write_addr;
        compute_role_write_strb[5] = dst_write_strb;
        compute_role_write_data[5] = dst_write_data;
        compute_role_write_valid[8] = rms_dst_write_valid;
        compute_role_write_bank[8] = rms_dst_write_bank;
        compute_role_write_addr[8] = rms_dst_write_addr;
        compute_role_write_strb[8] = rms_dst_write_strb;
        compute_role_write_data[8] = rms_dst_write_data;
        compute_role_write_valid[9] = rope_data_write_valid;
        compute_role_write_bank[9] = rope_data_write_bank;
        compute_role_write_addr[9] = rope_data_write_addr;
        compute_role_write_strb[9] = rope_data_write_strb;
        compute_role_write_data[9] = rope_data_write_data;
        compute_role_write_valid[13] = REAL_ATTENTION ?
            (gemm_owner_r == 3 && dst_write_valid) : score_probe_write_valid;
        compute_role_write_bank[13] = 4'd10;
        compute_role_write_addr[13] = REAL_ATTENTION ?
            dst_write_addr : probe_write_addr;
        compute_role_write_strb[13] = REAL_ATTENTION ?
            dst_write_strb : 16'hffff;
        compute_role_write_data[13] = REAL_ATTENTION ?
            dst_write_data : probe_write_data;
        compute_role_write_valid[14] = softmax_data_write_valid;
        compute_role_write_bank[14] = softmax_data_write_bank;
        compute_role_write_addr[14] = softmax_data_write_addr;
        compute_role_write_strb[14] = softmax_data_write_strb;
        compute_role_write_data[14] = softmax_data_write_data;
        compute_role_write_valid[17] = REAL_ATTENTION &&
                                       gemm_owner_r == 5 && dst_write_valid;
        compute_role_write_bank[17] = dst_write_bank;
        compute_role_write_addr[17] = dst_write_addr;
        compute_role_write_strb[17] = dst_write_strb;
        compute_role_write_data[17] = dst_write_data;
        compute_role_write_valid[20] = vector_silu_r ?
                                       silu_dst_write_valid : add_dst_write_valid;
        compute_role_write_bank[20] = vector_silu_r ?
                                      silu_dst_write_bank : add_dst_write_bank;
        compute_role_write_addr[20] = vector_silu_r ?
                                      silu_dst_write_addr : add_dst_write_addr;
        compute_role_write_strb[20] = vector_silu_r ?
                                      silu_dst_write_strb : add_dst_write_strb;
        compute_role_write_data[20] = vector_silu_r ?
                                      silu_dst_write_data : add_dst_write_data;
    end
    assign act_read_ready = compute_role_read_ready[gemm_owner_r == 3 ? 11 :
                                                    gemm_owner_r == 5 ? 15 : 3];
    assign act_rsp_valid = act_rsp_valid_r;
    assign act_rsp_bank = act_rsp_bank_r;
    assign act_rsp_data = act_rsp_data_r;
    assign weight_read_ready = compute_role_read_ready[gemm_owner_r == 3 ? 12 :
                                                       gemm_owner_r == 5 ? 16 : 4];
    assign weight_rsp_valid = weight_rsp_valid_r;
    assign weight_rsp_bank = weight_rsp_bank_r;
    assign weight_rsp_data = weight_rsp_data_r;
    assign dst_write_ready = compute_role_write_ready[gemm_owner_r == 3 ? 13 :
                                                     gemm_owner_r == 5 ? 17 : 5];
    assign gemm_core_done_ready = compute_done_ready[gemm_owner_r];
    assign probe_cmd_valid = (!REAL_RMS && compute_cmd_valid[1]) ||
                             (PROBE_SCORE && !REAL_ATTENTION && compute_cmd_valid[3]);
    assign probe_done_ready = (!REAL_RMS && compute_done_ready[1]) ||
                              (PROBE_SCORE && !REAL_ATTENTION && compute_done_ready[3]);
    assign probe_write_ready = (PROBE_SCORE && !REAL_ATTENTION) ?
                                            compute_role_write_ready[13] :
                                            compute_role_write_ready[8];
    for (genvar i=0; i<2; i++) begin : attention_ports
        localparam int A_ROLE = i == 0 ? 11 : 15;
        localparam int B_ROLE = i == 0 ? 12 : 16;
        localparam int D_ROLE = i == 0 ? 13 : 17;
        assign attention_a_ready[i] = compute_role_read_ready[A_ROLE];
        assign attention_a_rsp_valid[i] = compute_role_rsp_valid[A_ROLE];
        assign attention_a_rsp_bank[i] = compute_role_rsp_bank[A_ROLE];
        assign attention_a_rsp_data[i] = compute_role_rsp_data[A_ROLE];
        assign attention_b_ready[i] = compute_role_read_ready[B_ROLE];
        assign attention_b_rsp_valid[i] = compute_role_rsp_valid[B_ROLE];
        assign attention_b_rsp_bank[i] = compute_role_rsp_bank[B_ROLE];
        assign attention_b_rsp_data[i] = compute_role_rsp_data[B_ROLE];
        assign attention_dst_ready[i] = compute_role_write_ready[D_ROLE];
    end
    assign score_write_accepted = REAL_ATTENTION && gemm_owner_r == 3 &&
                                  dst_write_valid && dst_write_ready;
    assign score_write_addr = dst_write_addr;
    assign score_write_strb = dst_write_strb;
    assign score_write_data = dst_write_data;
    assign value_write_accepted = REAL_ATTENTION && gemm_owner_r == 5 &&
                                  dst_write_valid && dst_write_ready;
    assign value_write_addr = dst_write_addr;
    assign value_write_strb = dst_write_strb;
    assign value_write_data = dst_write_data;
    assign rms_src_read_ready = compute_role_read_ready[6];
    assign rms_src_rsp_valid = compute_role_rsp_valid[6];
    assign rms_src_rsp_bank = compute_role_rsp_bank[6];
    assign rms_src_rsp_data = compute_role_rsp_data[6];
    assign rms_gamma_read_ready = compute_role_read_ready[7];
    assign rms_gamma_rsp_valid = compute_role_rsp_valid[7];
    assign rms_gamma_rsp_bank = compute_role_rsp_bank[7];
    assign rms_gamma_rsp_data = compute_role_rsp_data[7];
    assign rms_dst_write_ready = compute_role_write_ready[8];
    assign rms_write_accepted = REAL_RMS && rms_dst_write_valid && rms_dst_write_ready;
    assign rms_write_bank = rms_dst_write_bank;
    assign rms_write_addr = rms_dst_write_addr;
    assign rms_write_data = rms_dst_write_data;
    assign rope_data_read_ready = compute_role_read_ready[9];
    assign rope_data_rsp_valid = compute_role_rsp_valid[9];
    assign rope_data_rsp_bank = compute_role_rsp_bank[9];
    assign rope_data_rsp_data = compute_role_rsp_data[9];
    assign rope_coeff_read_ready = compute_role_read_ready[10];
    assign rope_coeff_rsp_valid = compute_role_rsp_valid[10];
    assign rope_coeff_rsp_bank = compute_role_rsp_bank[10];
    assign rope_coeff_rsp_data = compute_role_rsp_data[10];
    assign rope_data_write_ready = compute_role_write_ready[9];
    assign rope_write_accepted = REAL_ROPE && rope_data_write_valid &&
                                 rope_data_write_ready;
    assign rope_write_bank = rope_data_write_bank;
    assign rope_write_addr = rope_data_write_addr;
    assign rope_write_data = rope_data_write_data;
    assign softmax_data_read_ready = compute_role_read_ready[14];
    assign softmax_data_rsp_valid = compute_role_rsp_valid[14];
    assign softmax_data_rsp_bank = compute_role_rsp_bank[14];
    assign softmax_data_rsp_data = compute_role_rsp_data[14];
    assign softmax_data_write_ready = compute_role_write_ready[14];
    assign softmax_write_accepted = REAL_SOFTMAX && softmax_data_write_valid &&
                                    softmax_data_write_ready;
    assign softmax_write_bank = softmax_data_write_bank;
    assign softmax_write_addr = softmax_data_write_addr;
    assign softmax_write_data = softmax_data_write_data;
    assign add_left_read_ready = compute_role_read_ready[18];
    assign add_left_rsp_valid = compute_role_rsp_valid[18];
    assign add_left_rsp_bank = compute_role_rsp_bank[18];
    assign add_left_rsp_data = compute_role_rsp_data[18];
    assign add_right_read_ready = compute_role_read_ready[19];
    assign add_right_rsp_valid = compute_role_rsp_valid[19];
    assign add_right_rsp_bank = compute_role_rsp_bank[19];
    assign add_right_rsp_data = compute_role_rsp_data[19];
    assign add_dst_write_ready = compute_role_write_ready[20];
    assign add_write_accepted = REAL_ADD && add_dst_write_valid &&
                                add_dst_write_ready && !vector_silu_r;
    assign add_write_bank = add_dst_write_bank;
    assign add_write_addr = add_dst_write_addr;
    assign add_write_data = add_dst_write_data;
    assign silu_gate_read_ready = compute_role_read_ready[18];
    assign silu_gate_rsp_valid = compute_role_rsp_valid[18];
    assign silu_gate_rsp_bank = compute_role_rsp_bank[18];
    assign silu_gate_rsp_data = compute_role_rsp_data[18];
    assign silu_up_read_ready = compute_role_read_ready[19];
    assign silu_up_rsp_valid = compute_role_rsp_valid[19];
    assign silu_up_rsp_bank = compute_role_rsp_bank[19];
    assign silu_up_rsp_data = compute_role_rsp_data[19];
    assign silu_dst_write_ready = compute_role_write_ready[20];
    assign silu_write_accepted = REAL_SILU && silu_dst_write_valid &&
                                 silu_dst_write_ready && vector_silu_r;
    assign silu_write_bank = silu_dst_write_bank;
    assign silu_write_addr = silu_dst_write_addr;
    assign silu_write_data = silu_dst_write_data;
    assign gemm_write_accepted = dst_write_valid && dst_write_ready;
    assign gemm_write_bank = dst_write_bank;
    assign gemm_write_addr = dst_write_addr;
    assign gemm_write_strb = dst_write_strb;
    assign gemm_write_data = dst_write_data;
endmodule
