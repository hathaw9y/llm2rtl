`timescale 1ns/1ps

module tb_smollm2_gemm_wide_bank_integration;
    logic aclk = 0;
    always #2.5 aclk = ~aclk;
    logic aresetn = 0;
    logic [0:12] bank_acquire_valid = '0, bank_release_valid = '0, bank_busy;
    logic [0:12][4:0] bank_acquire_port = '0, bank_release_port = '0;
    logic [0:12][4:0] bank_owner_port;
    logic [0:20] role_read_valid, role_read_ready, role_read_wide;
    logic [0:20][3:0] role_read_bank, role_rsp_bank;
    logic [0:20][15:0] role_read_addr;
    logic [0:20] role_rsp_valid, role_write_valid, role_write_ready;
    logic [0:20][127:0] role_rsp_data, role_write_data;
    logic [0:20][255:0] role_rsp_wide_data;
    logic [0:20][3:0] role_write_bank;
    logic [0:20][15:0] role_write_addr, role_write_strb;
    logic subsystem_error, ownership_error, router_error;
    logic [1:0] subsystem_error_code;
    logic [2:0] ownership_error_code, router_error_code;
    logic [4:0] router_error_role;
    logic [3:0] router_error_bank;

    logic cmd_valid = 0, cmd_ready, done_valid, done_ready = 0, done_error;
    logic [3:0] cmd_opcode = 4'd3, done_tag;
    logic [2:0][3:0] cmd_bank = {4'd4, 4'd3, 4'd2}, done_bank;
    logic [111:0] cmd_payload = {49'd0,16'd0,16'd1,6'd0,6'd1,11'd16,8'd1};
    logic [1:0] done_bank_count;
    logic act_read_valid, act_read_ready, weight_read_valid, weight_read_ready;
    logic [3:0] act_read_bank, weight_read_bank, dst_write_bank;
    logic [15:0] act_read_addr, weight_read_addr, dst_write_addr;
    logic act_rsp_valid, weight_rsp_valid, dst_write_valid, dst_write_ready;
    logic [3:0] act_rsp_bank, weight_rsp_bank;
    logic [255:0] act_rsp_data, weight_rsp_data;
    logic [15:0] dst_write_strb;
    logic [127:0] dst_write_data;

    logic manual_write_valid = 0, manual_read_valid = 0;
    logic [4:0] manual_role = 0;
    logic [3:0] manual_bank = 0;
    logic [15:0] manual_addr = 0, manual_strb = '1;
    logic [127:0] manual_data = 0;

    smollm2_bank_subsystem_wide banks (
        .aclk(aclk), .aresetn(aresetn),
        .bank_acquire_valid(bank_acquire_valid),
        .bank_acquire_port(bank_acquire_port),
        .bank_release_valid(bank_release_valid),
        .bank_release_port(bank_release_port),
        .bank_busy(bank_busy), .bank_owner_port(bank_owner_port),
        .role_read_valid(role_read_valid), .role_read_ready(role_read_ready),
        .role_read_bank(role_read_bank), .role_read_addr(role_read_addr),
        .role_read_wide(role_read_wide),
        .role_rsp_valid(role_rsp_valid), .role_rsp_bank(role_rsp_bank),
        .role_rsp_data(role_rsp_data), .role_rsp_wide_data(role_rsp_wide_data),
        .role_write_valid(role_write_valid), .role_write_ready(role_write_ready),
        .role_write_bank(role_write_bank), .role_write_addr(role_write_addr),
        .role_write_strb(role_write_strb), .role_write_data(role_write_data),
        .subsystem_error(subsystem_error),
        .subsystem_error_code(subsystem_error_code),
        .ownership_error(ownership_error),
        .ownership_error_code(ownership_error_code),
        .router_error(router_error), .router_error_code(router_error_code),
        .router_error_role(router_error_role), .router_error_bank(router_error_bank)
    );

    smollm2_gemm_systolic_wide_executor gemm (
        .aclk(aclk), .aresetn(aresetn), .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready), .cmd_opcode(cmd_opcode), .cmd_bank(cmd_bank),
        .cmd_payload(cmd_payload), .done_valid(done_valid),
        .done_ready(done_ready), .done_tag(done_tag),
        .done_bank_count(done_bank_count), .done_bank(done_bank),
        .done_error(done_error), .act_read_valid(act_read_valid),
        .act_read_ready(act_read_ready), .act_read_bank(act_read_bank),
        .act_read_addr(act_read_addr), .act_rsp_valid(act_rsp_valid),
        .act_rsp_bank(act_rsp_bank), .act_rsp_data(act_rsp_data),
        .weight_read_valid(weight_read_valid),
        .weight_read_ready(weight_read_ready),
        .weight_read_bank(weight_read_bank),
        .weight_read_addr(weight_read_addr),
        .weight_rsp_valid(weight_rsp_valid),
        .weight_rsp_bank(weight_rsp_bank),
        .weight_rsp_data(weight_rsp_data),
        .dst_write_valid(dst_write_valid),
        .dst_write_ready(dst_write_ready),
        .dst_write_bank(dst_write_bank),
        .dst_write_addr(dst_write_addr),
        .dst_write_strb(dst_write_strb),
        .dst_write_data(dst_write_data)
    );

    always_comb begin
        role_read_valid = '0; role_read_bank = '0; role_read_addr = '0;
        role_read_wide = '0;
        role_write_valid = '0; role_write_bank = '0;
        role_write_addr = '0; role_write_strb = '0; role_write_data = '0;
        role_read_valid[3] = act_read_valid;
        role_read_bank[3] = act_read_bank;
        role_read_addr[3] = act_read_addr;
        role_read_wide[3] = 1'b1;
        role_read_valid[4] = weight_read_valid;
        role_read_bank[4] = weight_read_bank;
        role_read_addr[4] = weight_read_addr;
        role_read_wide[4] = 1'b1;
        role_write_valid[5] = dst_write_valid;
        role_write_bank[5] = dst_write_bank;
        role_write_addr[5] = dst_write_addr;
        role_write_strb[5] = dst_write_strb;
        role_write_data[5] = dst_write_data;
        if (manual_write_valid) begin
            role_write_valid[manual_role] = 1'b1;
            role_write_bank[manual_role] = manual_bank;
            role_write_addr[manual_role] = manual_addr;
            role_write_strb[manual_role] = manual_strb;
            role_write_data[manual_role] = manual_data;
        end
        if (manual_read_valid) begin
            role_read_valid[manual_role] = 1'b1;
            role_read_bank[manual_role] = manual_bank;
            role_read_addr[manual_role] = manual_addr;
        end
    end
    assign act_read_ready = role_read_ready[3];
    assign weight_read_ready = role_read_ready[4];
    assign dst_write_ready = role_write_ready[5];
    assign act_rsp_valid = role_rsp_valid[3];
    assign act_rsp_bank = role_rsp_bank[3];
    assign act_rsp_data = role_rsp_wide_data[3];
    assign weight_rsp_valid = role_rsp_valid[4];
    assign weight_rsp_bank = role_rsp_bank[4];
    assign weight_rsp_data = role_rsp_wide_data[4];

    task automatic acquire(input int bank, input int role);
        @(negedge aclk);
        bank_acquire_valid[bank] = 1;
        bank_acquire_port[bank] = 5'(role);
        @(posedge aclk); #1;
        bank_acquire_valid[bank] = 0;
        if (!bank_busy[bank] || bank_owner_port[bank] != 5'(role))
            $fatal(1, "acquire bank %0d role %0d", bank, role);
    endtask
    task automatic release_bank(input int bank, input int role);
        @(negedge aclk);
        bank_release_valid[bank] = 1;
        bank_release_port[bank] = 5'(role);
        @(posedge aclk); #1;
        bank_release_valid[bank] = 0;
        if (bank_busy[bank]) $fatal(1, "release bank %0d", bank);
    endtask
    task automatic write_word(input int role, input int bank, input int addr,
                              input logic [127:0] value);
        @(negedge aclk);
        manual_role = 5'(role); manual_bank = 4'(bank);
        manual_addr = 16'(addr); manual_data = value;
        manual_write_valid = 1;
        #1;
        if (!role_write_ready[role]) $fatal(1, "write blocked");
        @(posedge aclk); #1;
        manual_write_valid = 0;
    endtask

    initial begin
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        acquire(2, 8);
        write_word(8, 2, 0, {8{16'h3f80}});
        write_word(8, 2, 1, {8{16'h3f80}});
        release_bank(2, 8);
        acquire(3, 1);
        write_word(1, 3, 0, {8{16'h3f80}});
        write_word(1, 3, 1, {8{16'h3f80}});
        release_bank(3, 1);
        acquire(2, 3); acquire(3, 4); acquire(4, 5);
        @(negedge aclk); cmd_valid = 1;
        if (!cmd_ready) $fatal(1, "GEMM not ready");
        @(negedge aclk); cmd_valid = 0;
        wait (done_valid); #1;
        if (done_error || done_bank_count != 3 || done_bank != cmd_bank ||
            done_tag != 2 || subsystem_error)
            $fatal(1, "GEMM completion or bank error");
        done_ready = 1;
        @(negedge aclk); done_ready = 0;
        release_bank(2, 3); release_bank(3, 4); release_bank(4, 5);
        acquire(4, 11);
        @(negedge aclk);
        manual_role = 11; manual_bank = 4; manual_addr = 0;
        manual_read_valid = 1;
        #1;
        if (!role_read_ready[11]) $fatal(1, "result read blocked");
        @(posedge aclk); #1; manual_read_valid = 0;
        repeat (2) @(posedge aclk); #1;
        if (!role_rsp_valid[11] || role_rsp_data[11][15:0] != 16'h4180)
            $fatal(1, "result mismatch %h", role_rsp_data[11][15:0]);
        $display("PASS smollm2_gemm_wide_bank_integration");
        $finish;
    end
endmodule
