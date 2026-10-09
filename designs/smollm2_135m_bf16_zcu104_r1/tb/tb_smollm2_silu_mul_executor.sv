`timescale 1ns/1ps
module tb_smollm2_silu_mul_executor;
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
    logic gate_read_valid, gate_read_ready, gate_rsp_valid;
    logic [3:0] gate_read_bank, gate_rsp_bank;
    logic [15:0] gate_read_addr;
    logic [127:0] gate_rsp_data;
    logic up_read_valid, up_read_ready, up_rsp_valid;
    logic [3:0] up_read_bank, up_rsp_bank;
    logic [15:0] up_read_addr;
    logic [127:0] up_rsp_data;
    logic dst_write_valid, dst_write_ready;
    logic [3:0] dst_write_bank;
    logic [15:0] dst_write_addr, dst_write_strb;
    logic [127:0] dst_write_data;
    logic [127:0] gate_mem[0:6143], up_mem[0:6143], expected[0:6143];
    logic [2:0] gate_pipe_valid, up_pipe_valid;
    logic [2:0][15:0] gate_pipe_addr, up_pipe_addr;
    int rows, writes, mismatches;

    smollm2_silu_mul_executor dut (.*);
    assign gate_read_ready=1'b1;
    assign up_read_ready=1'b1;
    assign dst_write_ready=1'b1;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            gate_pipe_valid <= '0;
            up_pipe_valid <= '0;
            gate_pipe_addr <= '0;
            up_pipe_addr <= '0;
            gate_rsp_valid <= 0;
            up_rsp_valid <= 0;
            gate_rsp_bank <= 0;
            up_rsp_bank <= 0;
            gate_rsp_data <= 0;
            up_rsp_data <= 0;
        end else begin
            gate_pipe_valid <= {gate_pipe_valid[1:0], gate_read_valid};
            up_pipe_valid <= {up_pipe_valid[1:0], up_read_valid};
            gate_pipe_addr <= {gate_pipe_addr[1:0], gate_read_addr};
            up_pipe_addr <= {up_pipe_addr[1:0], up_read_addr};
            gate_rsp_valid <= gate_pipe_valid[2];
            up_rsp_valid <= up_pipe_valid[2];
            if (gate_pipe_valid[2]) begin
                gate_rsp_bank <= cmd_bank[0];
                gate_rsp_data <= gate_mem[gate_pipe_addr[2]];
            end
            if (up_pipe_valid[2]) begin
                up_rsp_bank <= cmd_bank[1];
                up_rsp_data <= up_mem[up_pipe_addr[2]];
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
                    $display("SILU_MUL mismatch word=%0d got=%032h expected=%032h addr=%0d",
                        writes, dst_write_data, expected[writes], dst_write_addr);
                mismatches = mismatches+1;
            end
            writes = writes+1;
        end
    end

    task automatic run_phase(input string phase, input int row_count,
                              input logic [2:0][3:0] banks);
        begin
            $readmemh({"vectors/", phase, "_gate_words.hex"}, gate_mem);
            $readmemh({"vectors/", phase, "_up_words.hex"}, up_mem);
            $readmemh({"vectors/", phase, "_expected_words.hex"}, expected);
            rows=row_count; writes=0; mismatches=0;
            @(negedge aclk);
            cmd_bank=banks;
            cmd_payload=112'(row_count);
            cmd_opcode=4'd10;
            cmd_valid=1;
            @(negedge aclk);
            cmd_valid=0;
            wait(done_valid);
            if (done_error || done_tag != banks[0] ||
                done_bank_count != 2'd3 || done_bank != banks ||
                writes != row_count*192 || mismatches != 0)
                $fatal(1, "SILU_MUL %s FAIL rows=%0d writes=%0d mismatches=%0d error=%b",
                    phase, row_count, writes, mismatches, done_error);
            $display("PASS SILU_MUL %s rows=%0d elements=%0d mismatches=0",
                     phase, row_count, row_count*1536);
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
        run_phase("prefill32", 32, {4'd10,4'd9,4'd8});
        run_phase("decode1", 1, {4'd10,4'd9,4'd8});
        run_phase("edge", 1, {4'd10,4'd9,4'd8});
        @(negedge aclk);
        cmd_bank = {4'd10,4'd9,4'd8};
        cmd_payload = 0;
        cmd_opcode = 4'd10;
        cmd_valid = 1;
        @(negedge aclk);
        cmd_valid = 0;
        wait(done_valid);
        if (!done_error || done_bank != cmd_bank || done_bank_count != 3)
            $fatal(1, "SILU_MUL invalid-row error response failed");
        done_ready = 1;
        @(negedge aclk);
        done_ready = 0;
        $display("PASS SILU_MUL invalid row error response");
        gate_mem[0][15:0] = 16'h7f80;
        writes = 0;
        @(negedge aclk);
        cmd_payload = 112'd1;
        cmd_valid = 1;
        @(negedge aclk);
        cmd_valid = 0;
        wait(done_valid);
        if (!done_error || done_bank != cmd_bank || writes != 0)
            $fatal(1, "SILU_MUL nonfinite input error response failed");
        done_ready = 1;
        @(negedge aclk);
        done_ready = 0;
        $display("PASS SILU_MUL nonfinite input error response");
        $display("PASS smollm2_silu_mul_executor");
        $finish;
    end

    initial begin
        #20000000;
        $fatal(1, "SILU_MUL timeout");
    end
endmodule
