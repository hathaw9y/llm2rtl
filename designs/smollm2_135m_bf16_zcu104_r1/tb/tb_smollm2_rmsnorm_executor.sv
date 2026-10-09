`timescale 1ns/1ps
module tb_smollm2_rmsnorm_executor;
    logic aclk = 0, aresetn = 0;
    always #5 aclk = ~aclk;
    logic cmd_valid, cmd_ready, done_valid, done_ready, done_error;
    logic [3:0] cmd_opcode, done_tag;
    logic [2:0][3:0] cmd_bank, done_bank;
    logic [111:0] cmd_payload;
    logic [1:0] done_bank_count;
    logic src_read_valid, src_read_ready, src_rsp_valid;
    logic [3:0] src_read_bank, src_rsp_bank;
    logic [15:0] src_read_addr;
    logic [127:0] src_rsp_data;
    logic gamma_read_valid, gamma_read_ready, gamma_rsp_valid;
    logic [3:0] gamma_read_bank, gamma_rsp_bank;
    logic [15:0] gamma_read_addr;
    logic [127:0] gamma_rsp_data;
    logic dst_write_valid, dst_write_ready;
    logic [3:0] dst_write_bank;
    logic [15:0] dst_write_addr, dst_write_strb;
    logic [127:0] dst_write_data;
    int writes, expected_rows, cycles;
    smollm2_rmsnorm_executor dut (.*);
    assign src_read_ready = 1'b1;
    assign gamma_read_ready = 1'b1;
    assign dst_write_ready = 1'b1;
    always_ff @(posedge aclk) begin
        src_rsp_valid <= src_read_valid && src_read_ready;
        src_rsp_bank <= src_read_bank;
        src_rsp_data <= {8{16'h3f80}}; // x=1
        gamma_rsp_valid <= gamma_read_valid && gamma_read_ready;
        gamma_rsp_bank <= gamma_read_bank;
        gamma_rsp_data <= {8{16'h3f80}}; // gamma=1
        if (aresetn && dst_write_valid && dst_write_ready) begin
            if (dst_write_bank != 4'd2 || dst_write_strb != 16'hffff ||
                dst_write_addr != writes || dst_write_data !== {8{16'h3f80}})
                $fatal(1, "bad output word=%0d addr=%0d data=%h", writes,
                       dst_write_addr, dst_write_data);
            writes <= writes + 1;
        end
    end
    task automatic run_rows(input int rows);
        begin
            @(negedge aclk);
            writes = 0; expected_rows = rows;
            cmd_opcode = 4'd4; cmd_bank[0] = 4'd0;
            cmd_bank[1] = 4'd3; cmd_bank[2] = 4'd2;
            cmd_payload = 112'(rows); cmd_valid = 1;
            @(negedge aclk); cmd_valid = 0;
            cycles = 0;
            while (!done_valid && cycles < 300000) begin
                @(negedge aclk); cycles++;
            end
            if (!done_valid || done_error || done_tag != 0 ||
                done_bank_count != 3 || done_bank[0] != 0 ||
                done_bank[1] != 3 || done_bank[2] != 2 ||
                writes != rows*72)
                $fatal(1, "RMS rows=%0d failed: done=%b err=%b writes=%0d",
                       rows, done_valid, done_error, writes);
            $display("RMS rows=%0d words=%0d cycles=%0d PASS", rows, writes, cycles);
            @(negedge aclk);
        end
    endtask
    task automatic reject_rows(input int rows);
        begin
            @(negedge aclk);
            cmd_opcode = 4'd4; cmd_bank[0] = 4'd0;
            cmd_bank[1] = 4'd3; cmd_bank[2] = 4'd2;
            cmd_payload = 112'(rows); cmd_valid = 1;
            @(negedge aclk); cmd_valid = 0;
            if (!done_valid || !done_error || dst_write_valid)
                $fatal(1, "invalid rows=%0d not rejected", rows);
            @(negedge aclk);
        end
    endtask
    initial begin
        cmd_valid = 0; done_ready = 1; cmd_opcode = 0;
        cmd_bank = '0; cmd_payload = '0; writes = 0;
        src_rsp_valid = 0; gamma_rsp_valid = 0;
        repeat (5) @(negedge aclk);
        aresetn = 1;
        run_rows(1);
        run_rows(32);
        reject_rows(0);
        reject_rows(33);
        $display("RMSNORM EXECUTOR PASS");
        $finish;
    end
endmodule
