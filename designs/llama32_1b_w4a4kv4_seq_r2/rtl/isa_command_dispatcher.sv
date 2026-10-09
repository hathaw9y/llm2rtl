`timescale 1ns/1ps

module isa_command_dispatcher (
    input  logic         aclk,
    input  logic         aresetn,
    input  logic         start,
    input  logic [10:0]  command_count,
    output logic         busy,
    output logic         done,
    output logic         error,
    output logic [7:0]   error_code,
    output logic [9:0]   current_pc,
    output logic         cmd_mem_en,
    output logic [10:0]  cmd_mem_addr,
    input  logic [127:0] cmd_mem_rdata,
    output logic         dma_cmd_valid,
    input  logic         dma_cmd_ready,
    output logic [255:0] dma_cmd_data,
    input  logic         dma_rsp_valid,
    output logic         dma_rsp_ready,
    input  logic         dma_rsp_error,
    input  logic [15:0]  dma_rsp_tag,
    output logic         gemm_cmd_valid,
    input  logic         gemm_cmd_ready,
    output logic [255:0] gemm_cmd_data,
    input  logic         gemm_rsp_valid,
    output logic         gemm_rsp_ready,
    input  logic         gemm_rsp_error,
    input  logic [15:0]  gemm_rsp_tag,
    output logic [11:0]  bank_state
);

    localparam logic [7:0] OP_LOAD  = 8'h01;
    localparam logic [7:0] OP_STORE = 8'h02;
    localparam logic [7:0] OP_GEMM  = 8'h10;

    localparam logic [2:0] B_FREE  = 3'd0;
    localparam logic [2:0] B_FILL  = 3'd1;
    localparam logic [2:0] B_READY = 3'd2;
    localparam logic [2:0] B_COMP  = 3'd3;
    localparam logic [2:0] B_DRAIN = 3'd4;
    localparam logic [2:0] B_FAULT = 3'd5;

    localparam logic [7:0] E_NONE       = 8'h00;
    localparam logic [7:0] E_COUNT      = 8'h01;
    localparam logic [7:0] E_OPCODE     = 8'h02;
    localparam logic [7:0] E_BANK       = 8'h03;
    localparam logic [7:0] E_OPERAND    = 8'h04;
    localparam logic [7:0] E_EXECUTOR   = 8'h05;
    localparam logic [7:0] E_TAG        = 8'h06;
    localparam logic [7:0] E_NEED_RESET = 8'h07;

    typedef enum logic [2:0] {
        IDLE, FETCH_LO, FETCH_HI, CHECK_READY,
        ISSUE, WAIT_COMPLETION, DONE_STATE, ERROR_STATE
    } state_t;

    state_t       state_r;
    logic [9:0]   pc_r;
    logic [10:0]  command_count_r;
    logic [255:0] command_r;
    logic         fetch_wait_r;
    logic [2:0]   banks_r [0:3];
    logic [7:0]   error_r;

    logic [7:0]  opcode_w;
    logic [15:0] tag_w;
    logic [7:0]  src0_w;
    logic [7:0]  src1_w;
    logic [7:0]  dst_w;
    logic [31:0] arg0_w;
    logic [31:0] arg1_w;
    logic [31:0] arg2_w;
    logic        release_src0_w;
    logic        release_src1_w;
    logic        release_store_w;
    logic        is_dma_w;
    logic        known_w;
    logic        legal_w;
    logic        bank_ids_legal_w;
    logic        banks_eligible_w;
    logic        any_fault_w;
    logic        rsp_valid_w;
    logic        rsp_error_w;
    logic [15:0] rsp_tag_w;
    logic        rsp_handshake_w;

    assign opcode_w = command_r[7:0];
    assign release_src0_w = command_r[8];
    assign release_src1_w = command_r[9];
    assign release_store_w = command_r[10];
    assign tag_w = command_r[31:16];
    assign src0_w = command_r[39:32];
    assign src1_w = command_r[47:40];
    assign dst_w = command_r[55:48];
    assign arg0_w = command_r[95:64];
    assign arg1_w = command_r[127:96];
    assign arg2_w = command_r[159:128];
    assign is_dma_w = (opcode_w == OP_LOAD) || (opcode_w == OP_STORE);
    assign known_w = is_dma_w || (opcode_w == OP_GEMM);

    always_comb begin
        bank_ids_legal_w = 1'b0;
        legal_w = 1'b0;
        banks_eligible_w = 1'b0;
        case (opcode_w)
            OP_LOAD: begin
                bank_ids_legal_w = (dst_w < 8'd4);
                legal_w = bank_ids_legal_w && (arg2_w != 32'd0);
                if (bank_ids_legal_w) begin
                    banks_eligible_w = (banks_r[dst_w[1:0]] == B_FREE);
                end
            end
            OP_STORE: begin
                bank_ids_legal_w = (src0_w < 8'd4);
                legal_w = bank_ids_legal_w && (arg2_w != 32'd0);
                if (bank_ids_legal_w) begin
                    banks_eligible_w = (banks_r[src0_w[1:0]] == B_READY);
                end
            end
            OP_GEMM: begin
                bank_ids_legal_w = (src0_w < 8'd4) &&
                                   (src1_w < 8'd4) &&
                                   (dst_w < 8'd4);
                legal_w = bank_ids_legal_w &&
                          (dst_w != src0_w) && (dst_w != src1_w) &&
                          (arg0_w != 32'd0) &&
                          (arg1_w != 32'd0) &&
                          (arg2_w != 32'd0);
                if (bank_ids_legal_w) begin
                    banks_eligible_w =
                        (banks_r[src0_w[1:0]] == B_READY) &&
                        (banks_r[src1_w[1:0]] == B_READY) &&
                        (banks_r[dst_w[1:0]] == B_FREE);
                end
            end
            default: begin
                bank_ids_legal_w = 1'b0;
                legal_w = 1'b0;
                banks_eligible_w = 1'b0;
            end
        endcase
    end

    assign any_fault_w = (banks_r[0] == B_FAULT) ||
                         (banks_r[1] == B_FAULT) ||
                         (banks_r[2] == B_FAULT) ||
                         (banks_r[3] == B_FAULT);
    assign rsp_valid_w = is_dma_w ? dma_rsp_valid : gemm_rsp_valid;
    assign rsp_error_w = is_dma_w ? dma_rsp_error : gemm_rsp_error;
    assign rsp_tag_w = is_dma_w ? dma_rsp_tag : gemm_rsp_tag;
    assign rsp_handshake_w = rsp_valid_w &&
                             (is_dma_w ? dma_rsp_ready : gemm_rsp_ready);

    always_comb begin
        busy = (state_r == FETCH_LO) || (state_r == FETCH_HI) ||
               (state_r == CHECK_READY) || (state_r == ISSUE) ||
               (state_r == WAIT_COMPLETION);
        done = (state_r == DONE_STATE);
        error = (state_r == ERROR_STATE);
        error_code = error_r;
        current_pc = pc_r;
        bank_state = {banks_r[3], banks_r[2], banks_r[1], banks_r[0]};

        cmd_mem_en = 1'b0;
        cmd_mem_addr = {pc_r, 1'b0};
        if ((state_r == FETCH_LO) && !fetch_wait_r) begin
            cmd_mem_en = 1'b1;
            cmd_mem_addr = {pc_r, 1'b0};
        end else if ((state_r == FETCH_HI) && !fetch_wait_r) begin
            cmd_mem_en = 1'b1;
            cmd_mem_addr = {pc_r, 1'b0} + 11'd1;
        end

        dma_cmd_valid = (state_r == ISSUE) && is_dma_w;
        gemm_cmd_valid = (state_r == ISSUE) && (opcode_w == OP_GEMM);
        dma_cmd_data = command_r;
        gemm_cmd_data = command_r;
        dma_rsp_ready = (state_r == WAIT_COMPLETION) && is_dma_w;
        gemm_rsp_ready = (state_r == WAIT_COMPLETION) &&
                         (opcode_w == OP_GEMM);
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE;
            pc_r <= 10'd0;
            command_count_r <= 11'd0;
            command_r <= 256'd0;
            fetch_wait_r <= 1'b0;
            error_r <= E_NONE;
            banks_r[0] <= B_FREE;
            banks_r[1] <= B_FREE;
            banks_r[2] <= B_FREE;
            banks_r[3] <= B_FREE;
        end else begin
            case (state_r)
                IDLE: begin
                    if (start) begin
                        pc_r <= 10'd0;
                        command_count_r <= command_count;
                        fetch_wait_r <= 1'b0;
                        error_r <= E_NONE;
                        if ((command_count == 11'd0) ||
                            (command_count > 11'd1024)) begin
                            error_r <= E_COUNT;
                            state_r <= ERROR_STATE;
                        end else begin
                            state_r <= FETCH_LO;
                        end
                    end
                end
                FETCH_LO: begin
                    if (!fetch_wait_r) begin
                        fetch_wait_r <= 1'b1;
                    end else begin
                        command_r[127:0] <= cmd_mem_rdata;
                        fetch_wait_r <= 1'b0;
                        state_r <= FETCH_HI;
                    end
                end
                FETCH_HI: begin
                    if (!fetch_wait_r) begin
                        fetch_wait_r <= 1'b1;
                    end else begin
                        command_r[255:128] <= cmd_mem_rdata;
                        fetch_wait_r <= 1'b0;
                        state_r <= CHECK_READY;
                    end
                end
                CHECK_READY: begin
                    if (!known_w) begin
                        error_r <= E_OPCODE;
                        state_r <= ERROR_STATE;
                    end else if (!legal_w) begin
                        error_r <= bank_ids_legal_w ? E_OPERAND : E_BANK;
                        state_r <= ERROR_STATE;
                    end else if (banks_eligible_w) begin
                        // Deliberately independent of executor ready.
                        state_r <= ISSUE;
                    end
                end
                ISSUE: begin
                    if ((is_dma_w && dma_cmd_ready) ||
                        (!is_dma_w && gemm_cmd_ready)) begin
                        if (opcode_w == OP_LOAD) begin
                            banks_r[dst_w[1:0]] <= B_FILL;
                        end else if (opcode_w == OP_STORE) begin
                            banks_r[src0_w[1:0]] <= B_DRAIN;
                        end else begin
                            banks_r[dst_w[1:0]] <= B_COMP;
                        end
                        state_r <= WAIT_COMPLETION;
                    end
                end
                WAIT_COMPLETION: begin
                    if (rsp_handshake_w) begin
                        if ((rsp_tag_w != tag_w) || rsp_error_w) begin
                            error_r <= (rsp_tag_w != tag_w) ? E_TAG : E_EXECUTOR;
                            if (opcode_w == OP_LOAD) begin
                                banks_r[dst_w[1:0]] <= B_FAULT;
                            end else if (opcode_w == OP_STORE) begin
                                banks_r[src0_w[1:0]] <= B_READY;
                            end else begin
                                banks_r[dst_w[1:0]] <= B_FAULT;
                            end
                            state_r <= ERROR_STATE;
                        end else begin
                            if (opcode_w == OP_LOAD) begin
                                banks_r[dst_w[1:0]] <= B_READY;
                            end else if (opcode_w == OP_STORE) begin
                                banks_r[src0_w[1:0]] <= release_store_w ?
                                                               B_FREE : B_READY;
                            end else begin
                                banks_r[dst_w[1:0]] <= B_READY;
                                if (release_src0_w) banks_r[src0_w[1:0]] <= B_FREE;
                                if (release_src1_w) banks_r[src1_w[1:0]] <= B_FREE;
                            end
                            if ({1'b0, pc_r} + 11'd1 == command_count_r) begin
                                state_r <= DONE_STATE;
                            end else begin
                                pc_r <= pc_r + 10'd1;
                                fetch_wait_r <= 1'b0;
                                state_r <= FETCH_LO;
                            end
                        end
                    end
                end
                DONE_STATE: begin
                    if (start) begin
                        pc_r <= 10'd0;
                        command_count_r <= command_count;
                        fetch_wait_r <= 1'b0;
                        error_r <= E_NONE;
                        if ((command_count == 11'd0) ||
                            (command_count > 11'd1024)) begin
                            error_r <= E_COUNT;
                            state_r <= ERROR_STATE;
                        end else begin
                            state_r <= FETCH_LO;
                        end
                    end
                end
                ERROR_STATE: begin
                    if (start) begin
                        if (any_fault_w) begin
                            error_r <= E_NEED_RESET;
                        end else begin
                            pc_r <= 10'd0;
                            command_count_r <= command_count;
                            fetch_wait_r <= 1'b0;
                            error_r <= E_NONE;
                            if ((command_count == 11'd0) ||
                                (command_count > 11'd1024)) begin
                                error_r <= E_COUNT;
                            end else begin
                                state_r <= FETCH_LO;
                            end
                        end
                    end
                end
                default: begin
                    error_r <= E_OPERAND;
                    state_r <= ERROR_STATE;
                end
            endcase
        end
    end
endmodule
