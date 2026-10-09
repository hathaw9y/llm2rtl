`timescale 1ns/1ps

module tb_bank_tensor_state_tracker;
    localparam int BANK_NUM = 13;
    logic aclk = 1'b0;
    always #5 aclk = ~aclk;
    logic aresetn = 1'b0;
    logic [BANK_NUM-1:0] wr_issue_valid = '0;
    logic [BANK_NUM-1:0][1:0] wr_issue_kind = '0;
    logic [BANK_NUM-1:0][15:0] wr_issue_index = '0;
    logic [BANK_NUM-1:0][15:0] wr_issue_count = '0;
    logic [BANK_NUM-1:0][15:0] wr_issue_total = '0;
    logic [BANK_NUM-1:0] wr_complete_valid = '0;
    logic [BANK_NUM-1:0] wr_complete_error = '0;
    logic [BANK_NUM-1:0] tensor_valid;
    logic [BANK_NUM-1:0][15:0] tensor_progress;
    logic [BANK_NUM-1:0] write_pending;
    logic state_error;

    bank_tensor_state_tracker #(.BANK_NUM(BANK_NUM)) dut (.*);

    task automatic issue(input int bank, input logic [1:0] kind,
                         input int index, input int count, input int total);
        @(negedge aclk);
        wr_issue_valid[bank] = 1'b1;
        wr_issue_kind[bank] = kind;
        wr_issue_index[bank] = 16'(index);
        wr_issue_count[bank] = 16'(count);
        wr_issue_total[bank] = 16'(total);
        @(posedge aclk);
        #1;
        wr_issue_valid[bank] = 1'b0;
    endtask

    task automatic complete(input int bank, input logic error_bit);
        @(negedge aclk);
        wr_complete_valid[bank] = 1'b1;
        wr_complete_error[bank] = error_bit;
        @(posedge aclk);
        #1;
        wr_complete_valid[bank] = 1'b0;
        wr_complete_error[bank] = 1'b0;
    endtask

    task automatic expect_bank(input int bank, input logic expected_valid,
                               input logic expected_pending, input int expected_progress);
        if (tensor_valid[bank] !== expected_valid ||
            write_pending[bank] !== expected_pending ||
            tensor_progress[bank] !== 16'(expected_progress)) begin
            $fatal(1, "bank %0d valid=%b pending=%b progress=%0d expected %b %b %0d",
                bank, tensor_valid[bank], write_pending[bank], tensor_progress[bank],
                expected_valid, expected_pending, expected_progress);
        end
    endtask

    initial begin
        repeat (2) @(posedge aclk);
        @(negedge aclk);
        aresetn = 1'b1;
        for (int bank = 0; bank < BANK_NUM; bank++) begin
            expect_bank(bank, 1'b0, 1'b0, 0);
        end

        issue(3, 2'd0, 0, 1, 1);
        expect_bank(3, 1'b0, 1'b1, 0);
        complete(3, 1'b0);
        expect_bank(3, 1'b1, 1'b0, 1);

        for (int row = 0; row < 32; row++) begin
            issue(0, 2'd1, row, 1, 32);
            expect_bank(0, 1'b0, 1'b1, row);
            complete(0, 1'b0);
            expect_bank(0, (row == 31), 1'b0, row + 1);
        end

        for (int n = 0; n < 1536; n += 192) begin
            issue(10, 2'd1, n, 192, 1536);
            expect_bank(10, 1'b0, 1'b1, n);
            complete(10, 1'b0);
            expect_bank(10, (n == 1344), 1'b0, n + 192);
        end

        issue(10, 2'd2, 0, 0, 0);
        expect_bank(10, 1'b0, 1'b1, 1536);
        complete(10, 1'b0);
        expect_bank(10, 1'b1, 1'b0, 1536);
        issue(10, 2'd2, 0, 0, 0);
        complete(10, 1'b1);
        expect_bank(10, 1'b0, 1'b0, 0);

        // An END/DONE gap has no reset and retains the completed hidden bank.
        repeat (4) @(posedge aclk);
        expect_bank(0, 1'b1, 1'b0, 32);

        @(negedge aclk);
        wr_issue_valid[2] = 1'b1;
        wr_issue_valid[4] = 1'b1;
        wr_issue_kind[2] = 2'd0;
        wr_issue_kind[4] = 2'd0;
        wr_issue_count[2] = 16'd1;
        wr_issue_count[4] = 16'd1;
        wr_issue_total[2] = 16'd1;
        wr_issue_total[4] = 16'd1;
        @(posedge aclk);
        #1;
        wr_issue_valid = '0;
        expect_bank(2, 1'b0, 1'b1, 0);
        expect_bank(4, 1'b0, 1'b1, 0);
        @(negedge aclk);
        wr_complete_valid[2] = 1'b1;
        wr_complete_valid[4] = 1'b1;
        @(posedge aclk);
        #1;
        wr_complete_valid = '0;
        expect_bank(2, 1'b1, 1'b0, 1);
        expect_bank(4, 1'b1, 1'b0, 1);

        issue(1, 2'd0, 0, 1, 1);
        issue(1, 2'd0, 0, 1, 1);
        if (state_error !== 1'b1) $fatal(1, "overlap did not flag error");
        complete(1, 1'b0);
        expect_bank(1, 1'b1, 1'b0, 1);

        @(negedge aclk);
        aresetn = 1'b0;
        @(posedge aclk);
        #1;
        if (state_error !== 1'b0) $fatal(1, "reset did not clear error");
        @(negedge aclk);
        aresetn = 1'b1;
        issue(5, 2'd1, 5, 1, 32);
        if (state_error !== 1'b1 || write_pending[5] !== 1'b0)
            $fatal(1, "out-of-order part accepted");

        $display("PASS bank_tensor_state_tracker");
        $finish;
    end
endmodule
