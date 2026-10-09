`timescale 1ns/1ps
module tb_smollm2_add_executor;
    logic aclk=0, aresetn=0;
    always #5 aclk=~aclk;
    logic cmd_valid, cmd_ready;
    logic [3:0] cmd_opcode;
    logic [2:0][3:0] cmd_bank;
    logic [111:0] cmd_payload;
    logic done_valid, done_ready, done_error;
    logic [3:0] done_tag;
    logic [1:0] done_bank_count;
    logic [2:0][3:0] done_bank;
    logic left_read_valid, left_read_ready, left_rsp_valid;
    logic [3:0] left_read_bank, left_rsp_bank;
    logic [15:0] left_read_addr;
    logic [127:0] left_rsp_data;
    logic right_read_valid, right_read_ready, right_rsp_valid;
    logic [3:0] right_read_bank, right_rsp_bank;
    logic [15:0] right_read_addr;
    logic [127:0] right_rsp_data;
    logic dst_write_valid, dst_write_ready;
    logic [3:0] dst_write_bank;
    logic [15:0] dst_write_addr, dst_write_strb;
    logic [127:0] dst_write_data;
    logic [127:0] left_mem[0:2303], right_mem[0:2303], expected[0:2303];
    logic [2:0] left_pipe_valid, right_pipe_valid;
    logic [2:0][15:0] left_pipe_addr, right_pipe_addr;
    int rows, writes, mismatches;

    smollm2_add_executor dut (.*);
    assign left_read_ready=1'b1;
    assign right_read_ready=1'b1;
    assign dst_write_ready=1'b1;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            left_pipe_valid <= '0;
            right_pipe_valid <= '0;
            left_pipe_addr <= '0;
            right_pipe_addr <= '0;
            left_rsp_valid <= 0;
            right_rsp_valid <= 0;
            left_rsp_bank <= 0;
            right_rsp_bank <= 0;
            left_rsp_data <= 0;
            right_rsp_data <= 0;
        end else begin
            left_pipe_valid <= {left_pipe_valid[1:0], left_read_valid};
            right_pipe_valid <= {right_pipe_valid[1:0], right_read_valid};
            left_pipe_addr <= {left_pipe_addr[1:0], left_read_addr};
            right_pipe_addr <= {right_pipe_addr[1:0], right_read_addr};
            left_rsp_valid <= left_pipe_valid[2];
            right_rsp_valid <= right_pipe_valid[2];
            if (left_pipe_valid[2]) begin
                left_rsp_bank <= cmd_bank[0];
                left_rsp_data <= left_mem[left_pipe_addr[2]];
            end
            if (right_pipe_valid[2]) begin
                right_rsp_bank <= cmd_bank[1];
                right_rsp_data <= right_mem[right_pipe_addr[2]];
            end
        end
    end

    always @(posedge aclk) begin
        if (aresetn && dst_write_valid && dst_write_ready) begin
            if (dst_write_bank != cmd_bank[2] ||
                dst_write_strb != 16'hffff ||
                dst_write_addr != 16'(writes) ||
                dst_write_data !== expected[writes]) begin
                if (mismatches < 5)
                    $display("ADD mismatch word=%0d got=%032h expected=%032h addr=%0d",
                        writes, dst_write_data, expected[writes], dst_write_addr);
                mismatches = mismatches+1;
            end
            writes = writes+1;
        end
    end

    task automatic run_phase(input string phase, input int row_count,
                              input logic [2:0][3:0] banks);
        begin
            $readmemh({"vectors/", phase, "_left_words.hex"}, left_mem);
            $readmemh({"vectors/", phase, "_right_words.hex"}, right_mem);
            $readmemh({"vectors/", phase, "_expected_words.hex"}, expected);
            rows=row_count; writes=0; mismatches=0;
            @(negedge aclk);
            cmd_bank=banks;
            cmd_payload=112'(row_count);
            cmd_opcode=4'd9;
            cmd_valid=1;
            @(negedge aclk);
            cmd_valid=0;
            wait(done_valid);
            if (done_error || done_tag != banks[0] ||
                done_bank_count != 2'd3 || done_bank != banks ||
                writes != row_count*72 || mismatches != 0)
                $fatal(1, "ADD %s FAIL rows=%0d writes=%0d mismatches=%0d error=%b",
                    phase, row_count, writes, mismatches, done_error);
            $display("PASS ADD %s rows=%0d elements=%0d mismatches=0",
                     phase, row_count, row_count*576);
            @(negedge aclk);
            done_ready = 1;
            @(negedge aclk);
            done_ready = 0;
        end
    endtask

    initial begin
        cmd_valid=0; cmd_opcode=0; cmd_bank='0; cmd_payload=0;
        done_ready=0;
        rows=0; writes=0; mismatches=0;
        repeat(8) @(negedge aclk);
        aresetn=1;
        run_phase("prefill", 32, {4'd5,4'd1,4'd0});
        run_phase("decode", 1, {4'd0,4'd1,4'd5});
        run_phase("edge", 1, {4'd5,4'd1,4'd0});
        @(negedge aclk);
        cmd_bank = {4'd5,4'd1,4'd0};
        cmd_payload = 0;
        cmd_opcode = 4'd9;
        cmd_valid = 1;
        @(negedge aclk);
        cmd_valid = 0;
        wait(done_valid);
        if (!done_error || done_bank != cmd_bank || done_bank_count != 3)
            $fatal(1, "ADD invalid-row error response failed");
        done_ready = 1;
        @(negedge aclk);
        done_ready = 0;
        $display("PASS ADD invalid row error response");
        $display("PASS smollm2_add_executor");
        $finish;
    end

    initial begin
        #5000000;
        $fatal(1, "ADD timeout");
    end
endmodule
