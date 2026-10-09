`timescale 1ns/1ps

module isa_command_dispatcher #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer BTT_WIDTH = 23,
    parameter integer BANK_NUM = 16,
    parameter integer BANK_NUM_WIDTH = 4,
    parameter integer TAG_WIDTH = 4,
    parameter integer BANK_ADDR_WIDTH = 32,
    parameter integer CMD_DATA_WIDTH = 128,
    parameter integer OPCODE_WIDTH = 4
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic cmd_dispatcher_start,
    output logic cmd_dispatcher_busy,
    output logic cmd_dispatcher_done,
    output logic cmd_dispatcher_error,
    output logic [7:0] cmd_dispatcher_error_code,
    output logic [9:0] current_pc,

    output logic cmd_bram_enb,
    output logic [BANK_ADDR_WIDTH-1:0] cmd_bram_addrb,
    input  logic [CMD_DATA_WIDTH-1:0] cmd_bram_doutb,

    output logic m_ctrl_mm2s_cmd_valid,
    input  logic m_ctrl_mm2s_cmd_ready,
    output logic [AXI_ADDR_WIDTH-1:0] m_ctrl_mm2s_cmd_addr,
    output logic [BTT_WIDTH-1:0] m_ctrl_mm2s_cmd_btt,
    output logic [31:0] m_ctrl_mm2s_cmd_offset,
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
    output logic [31:0] m_ctrl_s2mm_cmd_offset,
    output logic [BANK_NUM_WIDTH-1:0] m_ctrl_s2mm_cmd_bank,
    output logic [TAG_WIDTH-1:0] m_ctrl_s2mm_cmd_tag,
    input  logic s_ctrl_s2mm_sts_valid,
    output logic m_ctrl_s2mm_sts_ready,
    input  logic [TAG_WIDTH-1:0] s_ctrl_s2mm_sts_tag,
    input  logic s_ctrl_s2mm_sts_error,

    output logic m_ctrl_sa_start,
    input  logic m_ctrl_sa_busy,
    output logic [5:0] m_ctrl_sa_m_size,
    output logic [10:0] m_ctrl_sa_n_size,
    output logic [11:0] m_ctrl_sa_k_size,
    output logic [BANK_NUM_WIDTH-1:0] m_ctrl_sa_act_bank,
    output logic [BANK_NUM_WIDTH-1:0] m_ctrl_sa_wgt_bank,
    output logic [BANK_NUM_WIDTH-1:0] m_ctrl_sa_out_bank,
    output logic [31:0] m_ctrl_sa_out_base_addr,
    input  logic s_ctrl_sa_done,
    output logic m_ctrl_sa_done_ready,
    input  logic s_ctrl_sa_error,
    input  logic [BANK_NUM_WIDTH-1:0] s_ctrl_sa_act_bank,
    input  logic [BANK_NUM_WIDTH-1:0] s_ctrl_sa_wgt_bank,
    input  logic [BANK_NUM_WIDTH-1:0] s_ctrl_sa_out_bank,

    output logic [OPCODE_WIDTH-1:0] bank_rd_acquire [1:BANK_NUM-1],
    output logic bank_rd_release [1:BANK_NUM-1],
    output logic [OPCODE_WIDTH-1:0] bank_wr_acquire [1:BANK_NUM-1],
    output logic bank_wr_release [1:BANK_NUM-1],
    input  logic bank_rd_busy [1:BANK_NUM-1],
    input  logic bank_wr_busy [1:BANK_NUM-1]
);

    localparam logic [3:0] OP_END   = 4'd0;
    localparam logic [3:0] OP_LOAD  = 4'd1;
    localparam logic [3:0] OP_STORE = 4'd2;
    localparam logic [3:0] OP_GEMM  = 4'd3;

    localparam logic [7:0] ERR_NONE       = 8'h00;
    localparam logic [7:0] ERR_OPCODE     = 8'h01;
    localparam logic [7:0] ERR_BANK_ZERO  = 8'h02;
    localparam logic [7:0] ERR_OPERAND    = 8'h03;
    localparam logic [7:0] ERR_RESPONSE   = 8'h04;
    localparam logic [7:0] ERR_EXECUTOR   = 8'h05;
    localparam logic [7:0] ERR_MISSING_END= 8'h06;

    typedef enum logic [2:0] {
        IDLE, FETCH, CHECK_ISSUE, END_DRAIN,
        ERROR_DRAIN, DONE_STATE, ERROR_STATE
    } state_t;

    state_t state_r;
    logic [9:0] pc_r;
    logic [1:0] fetch_phase_r;
    /* verilator lint_off UNUSED */
    logic [127:0] command_r; // Reserved command bits [24:0] are intentionally ignored.
    /* verilator lint_on UNUSED */
    logic [7:0] error_code_r;

    logic pending_mm2s_r [1:BANK_NUM-1];
    logic pending_s2mm_r [1:BANK_NUM-1];
    logic pending_sa_r [1:BANK_NUM-1];
    logic [BANK_NUM_WIDTH-1:0] pending_sa_act_r [1:BANK_NUM-1];
    logic [BANK_NUM_WIDTH-1:0] pending_sa_wgt_r [1:BANK_NUM-1];

    logic [3:0] opcode_w;
    logic [3:0] src1_w;
    logic [3:0] src2_w;
    logic [3:0] dst_w;
    logic [31:0] offset_shape_w;
    logic [22:0] btt_w;
    logic [31:0] axi_addr_w;
    logic [5:0] gemm_m_w;
    logic [10:0] gemm_n_w;
    logic [11:0] gemm_k_w;
    logic legal_w;
    logic bank_zero_w;
    logic banks_eligible_w;
    logic request_fire_w;
    logic pending_any_w;
    logic external_busy_any_w;

    logic mm2s_rsp_match_w;
    logic s2mm_rsp_match_w;
    logic sa_rsp_match_w;
    logic response_fault_w;
    logic executor_fault_w;

    integer pending_idx;
    integer pulse_idx;
    integer reset_idx;

    assign opcode_w = command_r[127:124];
    assign src1_w = command_r[123:120];
    assign src2_w = command_r[119:116];
    assign dst_w = command_r[115:112];
    assign offset_shape_w = command_r[111:80];
    assign btt_w = command_r[79:57];
    assign axi_addr_w = command_r[56:25];
    assign gemm_m_w = offset_shape_w[31:26];
    assign gemm_n_w = offset_shape_w[25:15];
    assign gemm_k_w = offset_shape_w[14:3];

    always_comb begin
        legal_w = 1'b0;
        bank_zero_w = 1'b0;
        banks_eligible_w = 1'b0;
        case (opcode_w)
            OP_END: begin
                legal_w = 1'b1;
                banks_eligible_w = 1'b1;
            end
            OP_LOAD: begin
                bank_zero_w = (dst_w == 4'd0);
                legal_w = !bank_zero_w && (btt_w != 23'd0);
                if (!bank_zero_w) begin
                    banks_eligible_w = !bank_rd_busy[dst_w] &&
                                       !bank_wr_busy[dst_w];
                end
            end
            OP_STORE: begin
                bank_zero_w = (dst_w == 4'd0);
                legal_w = !bank_zero_w && (btt_w != 23'd0);
                if (!bank_zero_w) begin
                    banks_eligible_w = !bank_rd_busy[dst_w] &&
                                       !bank_wr_busy[dst_w];
                end
            end
            OP_GEMM: begin
                bank_zero_w = (src1_w == 4'd0) || (src2_w == 4'd0) ||
                              (dst_w == 4'd0);
                legal_w = !bank_zero_w && (dst_w != src1_w) &&
                          (dst_w != src2_w) &&
                          (gemm_m_w != 6'd0) && (gemm_m_w <= 6'd32) &&
                          (gemm_n_w != 11'd0) && (gemm_n_w <= 11'd1024) &&
                          (gemm_k_w != 12'd0) && (gemm_k_w <= 12'd2048);
                if (!bank_zero_w) begin
                    banks_eligible_w =
                        !bank_rd_busy[src1_w] && !bank_wr_busy[src1_w] &&
                        !bank_rd_busy[src2_w] && !bank_wr_busy[src2_w] &&
                        !bank_rd_busy[dst_w] && !bank_wr_busy[dst_w];
                end
            end
            default: begin
                legal_w = 1'b0;
                banks_eligible_w = 1'b0;
            end
        endcase
    end

    always_comb begin
        pending_any_w = 1'b0;
        external_busy_any_w = 1'b0;
        for (pending_idx = 1; pending_idx < BANK_NUM; pending_idx = pending_idx + 1) begin
            pending_any_w = pending_any_w || pending_mm2s_r[pending_idx] ||
                            pending_s2mm_r[pending_idx] || pending_sa_r[pending_idx];
            external_busy_any_w = external_busy_any_w ||
                                  bank_rd_busy[pending_idx] || bank_wr_busy[pending_idx];
        end
    end

    always_comb begin
        mm2s_rsp_match_w = 1'b0;
        if (s_ctrl_mm2s_sts_tag != {TAG_WIDTH{1'b0}}) begin
            mm2s_rsp_match_w = pending_mm2s_r[s_ctrl_mm2s_sts_tag];
        end
        s2mm_rsp_match_w = 1'b0;
        if (s_ctrl_s2mm_sts_tag != {TAG_WIDTH{1'b0}}) begin
            s2mm_rsp_match_w = pending_s2mm_r[s_ctrl_s2mm_sts_tag];
        end
        sa_rsp_match_w = 1'b0;
        if (s_ctrl_sa_out_bank != {BANK_NUM_WIDTH{1'b0}}) begin
            sa_rsp_match_w = pending_sa_r[s_ctrl_sa_out_bank] &&
                             (pending_sa_act_r[s_ctrl_sa_out_bank] == s_ctrl_sa_act_bank) &&
                             (pending_sa_wgt_r[s_ctrl_sa_out_bank] == s_ctrl_sa_wgt_bank);
        end

        response_fault_w =
            (s_ctrl_mm2s_sts_valid && !mm2s_rsp_match_w) ||
            (s_ctrl_s2mm_sts_valid && !s2mm_rsp_match_w) ||
            (s_ctrl_sa_done && !sa_rsp_match_w);
        executor_fault_w =
            (s_ctrl_mm2s_sts_valid && mm2s_rsp_match_w && s_ctrl_mm2s_sts_error) ||
            (s_ctrl_s2mm_sts_valid && s2mm_rsp_match_w && s_ctrl_s2mm_sts_error) ||
            (s_ctrl_sa_done && sa_rsp_match_w && s_ctrl_sa_error);
    end

    always_comb begin
        cmd_dispatcher_busy = (state_r == FETCH) ||
                              (state_r == CHECK_ISSUE) ||
                              (state_r == END_DRAIN) ||
                              (state_r == ERROR_DRAIN);
        cmd_dispatcher_done = (state_r == DONE_STATE);
        cmd_dispatcher_error = (state_r == ERROR_STATE);
        cmd_dispatcher_error_code = error_code_r;
        current_pc = pc_r;

        cmd_bram_enb = (state_r == FETCH) && (fetch_phase_r == 2'd0);
        cmd_bram_addrb = {{(BANK_ADDR_WIDTH-10){1'b0}}, pc_r};

        m_ctrl_mm2s_cmd_valid = (state_r == CHECK_ISSUE) &&
                                (opcode_w == OP_LOAD) && legal_w &&
                                banks_eligible_w && !response_fault_w &&
                                !executor_fault_w;
        m_ctrl_mm2s_cmd_addr = axi_addr_w;
        m_ctrl_mm2s_cmd_btt = btt_w;
        m_ctrl_mm2s_cmd_offset = offset_shape_w;
        m_ctrl_mm2s_cmd_bank = dst_w;
        m_ctrl_mm2s_cmd_tag = dst_w;

        m_ctrl_s2mm_cmd_valid = (state_r == CHECK_ISSUE) &&
                                (opcode_w == OP_STORE) && legal_w &&
                                banks_eligible_w && !response_fault_w &&
                                !executor_fault_w;
        m_ctrl_s2mm_cmd_addr = axi_addr_w;
        m_ctrl_s2mm_cmd_btt = btt_w;
        m_ctrl_s2mm_cmd_offset = offset_shape_w;
        m_ctrl_s2mm_cmd_bank = dst_w;
        m_ctrl_s2mm_cmd_tag = dst_w;

        m_ctrl_sa_start = (state_r == CHECK_ISSUE) &&
                          (opcode_w == OP_GEMM) && legal_w &&
                          banks_eligible_w && !response_fault_w &&
                          !executor_fault_w;
        m_ctrl_sa_m_size = gemm_m_w;
        m_ctrl_sa_n_size = gemm_n_w;
        m_ctrl_sa_k_size = gemm_k_w;
        m_ctrl_sa_act_bank = src1_w;
        m_ctrl_sa_wgt_bank = src2_w;
        m_ctrl_sa_out_bank = dst_w;
        m_ctrl_sa_out_base_addr = 32'd0;

        m_ctrl_mm2s_sts_ready = aresetn;
        m_ctrl_s2mm_sts_ready = aresetn;
        m_ctrl_sa_done_ready = aresetn;

        request_fire_w =
            (m_ctrl_mm2s_cmd_valid && m_ctrl_mm2s_cmd_ready) ||
            (m_ctrl_s2mm_cmd_valid && m_ctrl_s2mm_cmd_ready) ||
            (m_ctrl_sa_start && !m_ctrl_sa_busy);

        for (pulse_idx = 1; pulse_idx < BANK_NUM; pulse_idx = pulse_idx + 1) begin
            bank_rd_acquire[pulse_idx] = {OPCODE_WIDTH{1'b0}};
            bank_wr_acquire[pulse_idx] = {OPCODE_WIDTH{1'b0}};
            bank_rd_release[pulse_idx] = 1'b0;
            bank_wr_release[pulse_idx] = 1'b0;
        end

        if (request_fire_w) begin
            case (opcode_w)
                OP_LOAD: bank_wr_acquire[dst_w] = OP_LOAD;
                OP_STORE: bank_rd_acquire[dst_w] = OP_STORE;
                OP_GEMM: begin
                    bank_rd_acquire[src1_w] = OP_GEMM;
                    bank_rd_acquire[src2_w] = OP_GEMM;
                    bank_rd_acquire[dst_w] = OP_GEMM;
                    bank_wr_acquire[dst_w] = OP_GEMM;
                end
                default: begin end
            endcase
        end

        if (s_ctrl_mm2s_sts_valid && mm2s_rsp_match_w) begin
            bank_wr_release[s_ctrl_mm2s_sts_tag] = 1'b1;
        end
        if (s_ctrl_s2mm_sts_valid && s2mm_rsp_match_w) begin
            bank_rd_release[s_ctrl_s2mm_sts_tag] = 1'b1;
        end
        if (s_ctrl_sa_done && sa_rsp_match_w) begin
            bank_rd_release[s_ctrl_sa_act_bank] = 1'b1;
            bank_rd_release[s_ctrl_sa_wgt_bank] = 1'b1;
            bank_rd_release[s_ctrl_sa_out_bank] = 1'b1;
            bank_wr_release[s_ctrl_sa_out_bank] = 1'b1;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE;
            pc_r <= 10'd0;
            fetch_phase_r <= 2'd0;
            command_r <= 128'd0;
            error_code_r <= ERR_NONE;
            for (reset_idx = 1; reset_idx < BANK_NUM; reset_idx = reset_idx + 1) begin
                pending_mm2s_r[reset_idx] <= 1'b0;
                pending_s2mm_r[reset_idx] <= 1'b0;
                pending_sa_r[reset_idx] <= 1'b0;
                pending_sa_act_r[reset_idx] <= {BANK_NUM_WIDTH{1'b0}};
                pending_sa_wgt_r[reset_idx] <= {BANK_NUM_WIDTH{1'b0}};
            end
        end else begin
            if (s_ctrl_mm2s_sts_valid && mm2s_rsp_match_w) begin
                pending_mm2s_r[s_ctrl_mm2s_sts_tag] <= 1'b0;
            end
            if (s_ctrl_s2mm_sts_valid && s2mm_rsp_match_w) begin
                pending_s2mm_r[s_ctrl_s2mm_sts_tag] <= 1'b0;
            end
            if (s_ctrl_sa_done && sa_rsp_match_w) begin
                pending_sa_r[s_ctrl_sa_out_bank] <= 1'b0;
            end

            if (response_fault_w || executor_fault_w) begin
                error_code_r <= response_fault_w ? ERR_RESPONSE : ERR_EXECUTOR;
                if ((state_r != IDLE) && (state_r != DONE_STATE) &&
                    (state_r != ERROR_STATE)) begin
                    state_r <= ERROR_DRAIN;
                end
            end else begin
                case (state_r)
                    IDLE: begin
                        if (cmd_dispatcher_start) begin
                            pc_r <= 10'd0;
                            fetch_phase_r <= 2'd0;
                            error_code_r <= ERR_NONE;
                            state_r <= FETCH;
                        end
                    end
                    FETCH: begin
                        if (fetch_phase_r == 2'd0) begin
                            fetch_phase_r <= 2'd1;
                        end else if (fetch_phase_r == 2'd1) begin
                            fetch_phase_r <= 2'd2;
                        end else begin
                            command_r <= cmd_bram_doutb;
                            fetch_phase_r <= 2'd0;
                            state_r <= CHECK_ISSUE;
                        end
                    end
                    CHECK_ISSUE: begin
                        if (opcode_w == OP_END) begin
                            state_r <= END_DRAIN;
                        end else if ((opcode_w != OP_LOAD) &&
                                     (opcode_w != OP_STORE) &&
                                     (opcode_w != OP_GEMM)) begin
                            error_code_r <= ERR_OPCODE;
                            state_r <= ERROR_DRAIN;
                        end else if (!legal_w) begin
                            error_code_r <= bank_zero_w ? ERR_BANK_ZERO : ERR_OPERAND;
                            state_r <= ERROR_DRAIN;
                        end else if (request_fire_w) begin
                            case (opcode_w)
                                OP_LOAD: pending_mm2s_r[dst_w] <= 1'b1;
                                OP_STORE: pending_s2mm_r[dst_w] <= 1'b1;
                                OP_GEMM: begin
                                    pending_sa_r[dst_w] <= 1'b1;
                                    pending_sa_act_r[dst_w] <= src1_w;
                                    pending_sa_wgt_r[dst_w] <= src2_w;
                                end
                                default: begin end
                            endcase
                            if (pc_r == 10'd1023) begin
                                error_code_r <= ERR_MISSING_END;
                                state_r <= ERROR_DRAIN;
                            end else begin
                                pc_r <= pc_r + 10'd1;
                                fetch_phase_r <= 2'd0;
                                state_r <= FETCH;
                            end
                        end
                    end
                    END_DRAIN: begin
                        if (!pending_any_w && !external_busy_any_w) begin
                            state_r <= DONE_STATE;
                        end
                    end
                    ERROR_DRAIN: begin
                        if (!pending_any_w && !external_busy_any_w) begin
                            state_r <= ERROR_STATE;
                        end
                    end
                    DONE_STATE: begin
                        if (cmd_dispatcher_start) begin
                            pc_r <= 10'd0;
                            fetch_phase_r <= 2'd0;
                            error_code_r <= ERR_NONE;
                            state_r <= FETCH;
                        end
                    end
                    ERROR_STATE: begin
                        if (cmd_dispatcher_start) begin
                            pc_r <= 10'd0;
                            fetch_phase_r <= 2'd0;
                            error_code_r <= ERR_NONE;
                            state_r <= FETCH;
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
