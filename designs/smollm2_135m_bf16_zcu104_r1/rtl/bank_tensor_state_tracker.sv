`timescale 1ns/1ps

module bank_tensor_state_tracker #(
    parameter int BANK_NUM = 13,
    parameter int PROGRESS_WIDTH = 16
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic [BANK_NUM-1:0] wr_issue_valid,
    input  logic [BANK_NUM-1:0][1:0] wr_issue_kind,
    input  logic [BANK_NUM-1:0][PROGRESS_WIDTH-1:0] wr_issue_index,
    input  logic [BANK_NUM-1:0][PROGRESS_WIDTH-1:0] wr_issue_count,
    input  logic [BANK_NUM-1:0][PROGRESS_WIDTH-1:0] wr_issue_total,
    input  logic [BANK_NUM-1:0] wr_complete_valid,
    input  logic [BANK_NUM-1:0] wr_complete_error,
    output logic [BANK_NUM-1:0] tensor_valid,
    output logic [BANK_NUM-1:0][PROGRESS_WIDTH-1:0] tensor_progress,
    output logic [BANK_NUM-1:0] write_pending,
    output logic state_error
);

    localparam logic [1:0] KIND_FULL = 2'd0;
    localparam logic [1:0] KIND_PART = 2'd1;
    localparam logic [1:0] KIND_INPLACE = 2'd2;

    logic [BANK_NUM-1:0] valid_r;
    logic [BANK_NUM-1:0] pending_r;
    logic [BANK_NUM-1:0][PROGRESS_WIDTH-1:0] progress_r;
    logic [BANK_NUM-1:0][PROGRESS_WIDTH-1:0] total_r;
    logic [BANK_NUM-1:0][1:0] pending_kind_r;
    logic [BANK_NUM-1:0][PROGRESS_WIDTH-1:0] pending_index_r;
    logic [BANK_NUM-1:0][PROGRESS_WIDTH-1:0] pending_count_r;

    assign tensor_valid = valid_r;
    assign tensor_progress = progress_r;
    assign write_pending = pending_r;

    always_ff @(posedge aclk) begin : state_update
        logic [PROGRESS_WIDTH:0] next_progress;
        logic issue_legal;
        if (!aresetn) begin
            valid_r <= '0;
            pending_r <= '0;
            progress_r <= '0;
            total_r <= '0;
            pending_kind_r <= '0;
            pending_index_r <= '0;
            pending_count_r <= '0;
            state_error <= 1'b0;
        end else begin
            for (int i = 0; i < BANK_NUM; i++) begin
                next_progress = {1'b0, wr_issue_index[i]} +
                                {1'b0, wr_issue_count[i]};
                issue_legal = 1'b0;
                case (wr_issue_kind[i])
                    KIND_FULL: begin
                        issue_legal = (wr_issue_index[i] == '0) &&
                            (wr_issue_count[i] != '0) &&
                            (wr_issue_count[i] == wr_issue_total[i]);
                    end
                    KIND_PART: begin
                        issue_legal = (wr_issue_count[i] != '0) &&
                            (wr_issue_total[i] != '0) &&
                            (next_progress <= {1'b0, wr_issue_total[i]}) &&
                            ((wr_issue_index[i] == '0) ||
                             (!valid_r[i] &&
                              (progress_r[i] == wr_issue_index[i]) &&
                              (total_r[i] == wr_issue_total[i])));
                    end
                    KIND_INPLACE: begin
                        issue_legal = valid_r[i] &&
                            (wr_issue_index[i] == '0) &&
                            (wr_issue_count[i] == '0) &&
                            (wr_issue_total[i] == '0);
                    end
                    default: issue_legal = 1'b0;
                endcase

                if (wr_issue_valid[i] && wr_complete_valid[i]) begin
                    state_error <= 1'b1;
                end else if (wr_issue_valid[i]) begin
                    if (pending_r[i] || !issue_legal) begin
                        state_error <= 1'b1;
                    end else begin
                        pending_r[i] <= 1'b1;
                        pending_kind_r[i] <= wr_issue_kind[i];
                        pending_index_r[i] <= wr_issue_index[i];
                        pending_count_r[i] <= wr_issue_count[i];
                        valid_r[i] <= 1'b0;
                        if ((wr_issue_kind[i] == KIND_FULL) ||
                            ((wr_issue_kind[i] == KIND_PART) &&
                             (wr_issue_index[i] == '0))) begin
                            progress_r[i] <= '0;
                            total_r[i] <= wr_issue_total[i];
                        end
                    end
                end else if (wr_complete_valid[i]) begin
                    if (!pending_r[i]) begin
                        state_error <= 1'b1;
                    end else begin
                        pending_r[i] <= 1'b0;
                        if (wr_complete_error[i]) begin
                            valid_r[i] <= 1'b0;
                            progress_r[i] <= '0;
                        end else begin
                            case (pending_kind_r[i])
                                KIND_FULL: begin
                                    progress_r[i] <= total_r[i];
                                    valid_r[i] <= 1'b1;
                                end
                                KIND_PART: begin
                                    next_progress =
                                        {1'b0, pending_index_r[i]} +
                                        {1'b0, pending_count_r[i]};
                                    progress_r[i] <= next_progress[PROGRESS_WIDTH-1:0];
                                    valid_r[i] <=
                                        (next_progress == {1'b0, total_r[i]});
                                end
                                KIND_INPLACE: valid_r[i] <= 1'b1;
                                default: state_error <= 1'b1;
                            endcase
                        end
                    end
                end
            end
        end
    end
endmodule
