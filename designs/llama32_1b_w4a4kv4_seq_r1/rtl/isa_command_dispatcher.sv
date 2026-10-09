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

    localparam logic [7:0] OPCODE_DMA_LOAD  = 8'h01;
    localparam logic [7:0] OPCODE_DMA_STORE = 8'h02;
    localparam logic [7:0] OPCODE_GEMM      = 8'h10;

    localparam logic [2:0] BANK_FREE           = 3'd0;
    localparam logic [2:0] BANK_FILLING        = 3'd1;
    localparam logic [2:0] BANK_READY          = 3'd2;
    localparam logic [2:0] BANK_COMPUTE_ACTIVE = 3'd3;
    localparam logic [2:0] BANK_DRAINING       = 3'd4;
    localparam logic [2:0] BANK_FAULT          = 3'd5;

    localparam logic [7:0] ERROR_NONE             = 8'h00;
    localparam logic [7:0] ERROR_COMMAND_COUNT    = 8'h01;
    localparam logic [7:0] ERROR_UNKNOWN_OPCODE   = 8'h02;
    localparam logic [7:0] ERROR_BANK_ID          = 8'h03;
    localparam logic [7:0] ERROR_ARGUMENT         = 8'h04;
    localparam logic [7:0] ERROR_EXECUTOR         = 8'h05;
    localparam logic [7:0] ERROR_TAG_MISMATCH     = 8'h06;
    localparam logic [7:0] ERROR_RESET_REQUIRED   = 8'h07;

    typedef enum logic [2:0] {
        IDLE,
        FETCH_LO,
        FETCH_HI,
        CHECK_READY,
        ISSUE,
        WAIT_COMPLETION,
        DONE_STATE,
        ERROR_STATE
    } state_t;

    state_t       state_r;
    logic [9:0]   pc_r;
    logic [10:0]  command_count_r;
    logic [255:0] command_r;
    logic         fetch_wait_r;
    logic [2:0]   bank_state_r [0:3];
    logic [7:0]   terminal_error_r;

    logic [7:0]   opcode_w;
    logic         release_src0_w;
    logic         release_src1_w;
    logic         release_store_src_w;
    logic [15:0]  tag_w;
    logic [7:0]   src0_bank_w;
    logic [7:0]   src1_bank_w;
    logic [7:0]   dst_bank_w;
    logic [31:0]  arg0_w;
    logic [31:0]  arg1_w;
    logic [31:0]  arg2_w;
    logic         opcode_known_w;
    logic         operands_legal_w;
    logic         banks_ready_w;
    logic         executor_ready_w;
    logic         selected_dma_w;
    logic         any_fault_w;
    logic         selected_rsp_valid_w;
    logic         selected_rsp_error_w;
    logic [15:0]  selected_rsp_tag_w;
    logic         selected_rsp_handshake_w;

    assign opcode_w    = command_r[7:0];
    assign release_src0_w      = command_r[8];
    assign release_src1_w      = command_r[9];
    assign release_store_src_w = command_r[10];
    assign tag_w       = command_r[31:16];
    assign src0_bank_w = command_r[39:32];
    assign src1_bank_w = command_r[47:40];
    assign dst_bank_w  = command_r[55:48];
    assign arg0_w      = command_r[95:64];
    assign arg1_w      = command_r[127:96];
    assign arg2_w      = command_r[159:128];

    assign selected_dma_w = (opcode_w == OPCODE_DMA_LOAD) ||
                            (opcode_w == OPCODE_DMA_STORE);
    assign opcode_known_w = selected_dma_w || (opcode_w == OPCODE_GEMM);

    always_comb begin
        operands_legal_w = 1'b0;
        banks_ready_w    = 1'b0;
        executor_ready_w = 1'b0;

        case (opcode_w)
            OPCODE_DMA_LOAD: begin
                operands_legal_w = (dst_bank_w < 8'd4) && (arg2_w != 32'd0);
                if (dst_bank_w < 8'd4) begin
                    banks_ready_w = (bank_state_r[dst_bank_w[1:0]] == BANK_FREE);
                end
                executor_ready_w = dma_cmd_ready;
            end
            OPCODE_DMA_STORE: begin
                operands_legal_w = (src0_bank_w < 8'd4) && (arg2_w != 32'd0);
                if (src0_bank_w < 8'd4) begin
                    banks_ready_w = (bank_state_r[src0_bank_w[1:0]] == BANK_READY);
                end
                executor_ready_w = dma_cmd_ready;
            end
            OPCODE_GEMM: begin
                operands_legal_w = (src0_bank_w < 8'd4) &&
                                   (src1_bank_w < 8'd4) &&
                                   (dst_bank_w < 8'd4) &&
                                   (arg0_w != 32'd0) &&
                                   (arg1_w != 32'd0) &&
                                   (arg2_w != 32'd0);
                if ((src0_bank_w < 8'd4) &&
                    (src1_bank_w < 8'd4) &&
                    (dst_bank_w < 8'd4)) begin
                    banks_ready_w =
                        (bank_state_r[src0_bank_w[1:0]] == BANK_READY) &&
                        (bank_state_r[src1_bank_w[1:0]] == BANK_READY) &&
                        (bank_state_r[dst_bank_w[1:0]] == BANK_FREE);
                end
                executor_ready_w = gemm_cmd_ready;
            end
            default: begin
                operands_legal_w = 1'b0;
                banks_ready_w    = 1'b0;
                executor_ready_w = 1'b0;
            end
        endcase
    end

    assign any_fault_w = (bank_state_r[0] == BANK_FAULT) ||
                         (bank_state_r[1] == BANK_FAULT) ||
                         (bank_state_r[2] == BANK_FAULT) ||
                         (bank_state_r[3] == BANK_FAULT);

    assign selected_rsp_valid_w = selected_dma_w ? dma_rsp_valid : gemm_rsp_valid;
    assign selected_rsp_error_w = selected_dma_w ? dma_rsp_error : gemm_rsp_error;
    assign selected_rsp_tag_w   = selected_dma_w ? dma_rsp_tag : gemm_rsp_tag;
    assign selected_rsp_handshake_w = selected_rsp_valid_w &&
                                      (selected_dma_w ? dma_rsp_ready : gemm_rsp_ready);

    always_comb begin
        busy          = (state_r == FETCH_LO) || (state_r == FETCH_HI) ||
                        (state_r == CHECK_READY) || (state_r == ISSUE) ||
                        (state_r == WAIT_COMPLETION);
        done          = (state_r == DONE_STATE);
        error         = (state_r == ERROR_STATE);
        error_code    = terminal_error_r;
        current_pc    = pc_r;
        bank_state    = {bank_state_r[3], bank_state_r[2],
                         bank_state_r[1], bank_state_r[0]};

        cmd_mem_en    = 1'b0;
        cmd_mem_addr  = {pc_r, 1'b0};
        if ((state_r == FETCH_LO) && !fetch_wait_r) begin
            cmd_mem_en   = 1'b1;
            cmd_mem_addr = {pc_r, 1'b0};
        end else if ((state_r == FETCH_HI) && !fetch_wait_r) begin
            cmd_mem_en   = 1'b1;
            cmd_mem_addr = {pc_r, 1'b0} + 11'd1;
        end

        dma_cmd_valid  = (state_r == ISSUE) && selected_dma_w;
        gemm_cmd_valid = (state_r == ISSUE) && !selected_dma_w &&
                         (opcode_w == OPCODE_GEMM);
        dma_cmd_data   = command_r;
        gemm_cmd_data  = command_r;

        dma_rsp_ready  = (state_r == WAIT_COMPLETION) && selected_dma_w;
        gemm_rsp_ready = (state_r == WAIT_COMPLETION) && !selected_dma_w &&
                         (opcode_w == OPCODE_GEMM);
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r         <= IDLE;
            pc_r            <= 10'd0;
            command_count_r <= 11'd0;
            command_r       <= 256'd0;
            fetch_wait_r    <= 1'b0;
            terminal_error_r <= ERROR_NONE;
            bank_state_r[0] <= BANK_FREE;
            bank_state_r[1] <= BANK_FREE;
            bank_state_r[2] <= BANK_FREE;
            bank_state_r[3] <= BANK_FREE;
        end else begin
            case (state_r)
                IDLE: begin
                    if (start) begin
                        pc_r             <= 10'd0;
                        command_count_r  <= command_count;
                        terminal_error_r <= ERROR_NONE;
                        fetch_wait_r     <= 1'b0;
                        if ((command_count == 11'd0) ||
                            (command_count > 11'd1024)) begin
                            terminal_error_r <= ERROR_COMMAND_COUNT;
                            state_r          <= ERROR_STATE;
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
                        fetch_wait_r     <= 1'b0;
                        state_r          <= FETCH_HI;
                    end
                end

                FETCH_HI: begin
                    if (!fetch_wait_r) begin
                        fetch_wait_r <= 1'b1;
                    end else begin
                        command_r[255:128] <= cmd_mem_rdata;
                        fetch_wait_r       <= 1'b0;
                        state_r            <= CHECK_READY;
                    end
                end

                CHECK_READY: begin
                    if (!opcode_known_w) begin
                        terminal_error_r <= ERROR_UNKNOWN_OPCODE;
                        state_r          <= ERROR_STATE;
                    end else if (!operands_legal_w) begin
                        terminal_error_r <= ((opcode_w == OPCODE_DMA_LOAD) &&
                                             (dst_bank_w >= 8'd4)) ||
                                            ((opcode_w == OPCODE_DMA_STORE) &&
                                             (src0_bank_w >= 8'd4)) ||
                                            ((opcode_w == OPCODE_GEMM) &&
                                             ((src0_bank_w >= 8'd4) ||
                                              (src1_bank_w >= 8'd4) ||
                                              (dst_bank_w >= 8'd4))) ?
                                            ERROR_BANK_ID : ERROR_ARGUMENT;
                        state_r <= ERROR_STATE;
                    end else if (banks_ready_w && executor_ready_w) begin
                        state_r <= ISSUE;
                    end
                end

                ISSUE: begin
                    if ((selected_dma_w && dma_cmd_ready) ||
                        (!selected_dma_w && gemm_cmd_ready)) begin
                        if (opcode_w == OPCODE_DMA_LOAD) begin
                            bank_state_r[dst_bank_w[1:0]] <= BANK_FILLING;
                        end else if (opcode_w == OPCODE_DMA_STORE) begin
                            bank_state_r[src0_bank_w[1:0]] <= BANK_DRAINING;
                        end else begin
                            bank_state_r[dst_bank_w[1:0]] <= BANK_COMPUTE_ACTIVE;
                        end
                        state_r <= WAIT_COMPLETION;
                    end
                end

                WAIT_COMPLETION: begin
                    if (selected_rsp_handshake_w) begin
                        if (selected_rsp_tag_w != tag_w) begin
                            terminal_error_r <= ERROR_TAG_MISMATCH;
                            if (opcode_w == OPCODE_DMA_LOAD) begin
                                bank_state_r[dst_bank_w[1:0]] <= BANK_FAULT;
                            end else if (opcode_w == OPCODE_DMA_STORE) begin
                                bank_state_r[src0_bank_w[1:0]] <= BANK_READY;
                            end else begin
                                bank_state_r[dst_bank_w[1:0]] <= BANK_FAULT;
                            end
                            state_r <= ERROR_STATE;
                        end else if (selected_rsp_error_w) begin
                            terminal_error_r <= ERROR_EXECUTOR;
                            if (opcode_w == OPCODE_DMA_LOAD) begin
                                bank_state_r[dst_bank_w[1:0]] <= BANK_FAULT;
                            end else if (opcode_w == OPCODE_DMA_STORE) begin
                                bank_state_r[src0_bank_w[1:0]] <= BANK_READY;
                            end else begin
                                bank_state_r[dst_bank_w[1:0]] <= BANK_FAULT;
                            end
                            state_r <= ERROR_STATE;
                        end else begin
                            if (opcode_w == OPCODE_DMA_LOAD) begin
                                bank_state_r[dst_bank_w[1:0]] <= BANK_READY;
                            end else if (opcode_w == OPCODE_DMA_STORE) begin
                                bank_state_r[src0_bank_w[1:0]] <=
                                    release_store_src_w ? BANK_FREE : BANK_READY;
                            end else begin
                                bank_state_r[dst_bank_w[1:0]] <= BANK_READY;
                                if (release_src0_w) begin
                                    bank_state_r[src0_bank_w[1:0]] <= BANK_FREE;
                                end
                                if (release_src1_w) begin
                                    bank_state_r[src1_bank_w[1:0]] <= BANK_FREE;
                                end
                            end

                            if ({1'b0, pc_r} + 11'd1 == command_count_r) begin
                                state_r <= DONE_STATE;
                            end else begin
                                pc_r         <= pc_r + 10'd1;
                                fetch_wait_r <= 1'b0;
                                state_r      <= FETCH_LO;
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    if (start) begin
                        pc_r             <= 10'd0;
                        command_count_r  <= command_count;
                        terminal_error_r <= ERROR_NONE;
                        fetch_wait_r     <= 1'b0;
                        if ((command_count == 11'd0) ||
                            (command_count > 11'd1024)) begin
                            terminal_error_r <= ERROR_COMMAND_COUNT;
                            state_r          <= ERROR_STATE;
                        end else begin
                            state_r <= FETCH_LO;
                        end
                    end
                end

                ERROR_STATE: begin
                    if (start) begin
                        if (any_fault_w) begin
                            terminal_error_r <= ERROR_RESET_REQUIRED;
                        end else begin
                            pc_r             <= 10'd0;
                            command_count_r  <= command_count;
                            terminal_error_r <= ERROR_NONE;
                            fetch_wait_r     <= 1'b0;
                            if ((command_count == 11'd0) ||
                                (command_count > 11'd1024)) begin
                                terminal_error_r <= ERROR_COMMAND_COUNT;
                            end else begin
                                state_r <= FETCH_LO;
                            end
                        end
                    end
                end

                default: begin
                    state_r          <= ERROR_STATE;
                    terminal_error_r <= ERROR_ARGUMENT;
                end
            endcase
        end
    end

endmodule
