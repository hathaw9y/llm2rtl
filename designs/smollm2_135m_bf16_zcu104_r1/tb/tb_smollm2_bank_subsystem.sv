`timescale 1ns/1ps

module tb_smollm2_bank_subsystem;
    logic aclk = 0;
    always #2.5 aclk = ~aclk;
    logic aresetn = 0;
    logic [0:12] bank_acquire_valid = '0, bank_release_valid = '0, bank_busy;
    logic [0:12][4:0] bank_acquire_port = '0, bank_release_port = '0;
    logic [0:12][4:0] bank_owner_port;
    logic [0:20] role_read_valid = '0, role_read_ready, role_rsp_valid;
    logic [0:20][3:0] role_read_bank = '0, role_rsp_bank;
    logic [0:20][15:0] role_read_addr = '0;
    logic [0:20][127:0] role_rsp_data;
    logic [0:20] role_write_valid = '0, role_write_ready;
    logic [0:20][3:0] role_write_bank = '0;
    logic [0:20][15:0] role_write_addr = '0, role_write_strb = '0;
    logic [0:20][127:0] role_write_data = '0;
    logic subsystem_error, ownership_error, router_error;
    logic [1:0] subsystem_error_code;
    logic [2:0] ownership_error_code, router_error_code;
    logic [4:0] router_error_role;
    logic [3:0] router_error_bank;
    smollm2_bank_subsystem dut (.*);

    task automatic acquire(input int bank, input int role);
        @(negedge aclk);
        bank_acquire_valid[bank] = 1;
        bank_acquire_port[bank] = 5'(role);
        @(posedge aclk); #1;
        bank_acquire_valid[bank] = 0;
        if (!bank_busy[bank] || bank_owner_port[bank] != 5'(role))
            $fatal(1, "acquire failed bank %0d role %0d", bank, role);
    endtask

    task automatic release_bank(input int bank, input int role);
        @(negedge aclk);
        bank_release_valid[bank] = 1;
        bank_release_port[bank] = 5'(role);
        @(posedge aclk); #1;
        bank_release_valid[bank] = 0;
        if (bank_busy[bank]) $fatal(1, "release failed bank %0d", bank);
    endtask

    task automatic write_word(input int role, input int bank,
                              input int addr, input logic [127:0] value);
        @(negedge aclk);
        role_write_bank[role] = 4'(bank);
        role_write_addr[role] = 16'(addr);
        role_write_strb[role] = '1;
        role_write_data[role] = value;
        role_write_valid[role] = 1;
        #1;
        if (!role_write_ready[role]) $fatal(1, "write blocked role %0d", role);
        @(posedge aclk); #1;
        role_write_valid[role] = 0;
    endtask

    task automatic read_word(input int role, input int bank,
                             input int addr, input logic [127:0] expected);
        @(negedge aclk);
        role_read_bank[role] = 4'(bank);
        role_read_addr[role] = 16'(addr);
        role_read_valid[role] = 1;
        #1;
        if (!role_read_ready[role]) $fatal(1, "read blocked role %0d", role);
        @(posedge aclk); #1;
        role_read_valid[role] = 0;
        repeat (2) @(posedge aclk);
        #1;
        if (!role_rsp_valid[role] || role_rsp_bank[role] != 4'(bank) ||
            role_rsp_data[role] !== expected)
            $fatal(1, "read mismatch role %0d bank %0d", role, bank);
    endtask

    initial begin
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        acquire(0, 1);
        write_word(1, 0, 4, 128'h0123456789abcdef0011223344556677);
        release_bank(0, 1);
        acquire(0, 6);
        read_word(6, 0, 4, 128'h0123456789abcdef0011223344556677);
        release_bank(0, 6);

        acquire(2, 8);
        write_word(8, 2, 2, 128'h2222);
        release_bank(2, 8);
        acquire(3, 1);
        write_word(1, 3, 7, 128'h3333);
        release_bank(3, 1);
        acquire(2, 3);
        acquire(3, 4);
        acquire(12, 5);
        @(negedge aclk);
        role_read_bank[3] = 2; role_read_addr[3] = 2; role_read_valid[3] = 1;
        role_read_bank[4] = 3; role_read_addr[4] = 7; role_read_valid[4] = 1;
        role_write_bank[5] = 12; role_write_addr[5] = 10;
        role_write_strb[5] = '1; role_write_data[5] = 128'h5555;
        role_write_valid[5] = 1;
        #1;
        if (!role_read_ready[3] || !role_read_ready[4] || !role_write_ready[5])
            $fatal(1, "three-bank concurrent access blocked");
        @(posedge aclk); #1;
        role_read_valid[3] = 0; role_read_valid[4] = 0; role_write_valid[5] = 0;
        repeat (2) @(posedge aclk); #1;
        if (!role_rsp_valid[3] || !role_rsp_valid[4] ||
            role_rsp_data[3] !== 128'h2222 || role_rsp_data[4] !== 128'h3333)
            $fatal(1, "three-bank responses mismatched");
        release_bank(2, 3);
        release_bank(3, 4);
        release_bank(12, 5);
        acquire(12, 2);
        read_word(2, 12, 10, 128'h5555);
        release_bank(12, 2);

        acquire(10, 13);
        write_word(13, 10, 5, 128'haaaa);
        release_bank(10, 13);
        acquire(10, 14);
        @(negedge aclk);
        role_read_bank[14] = 10; role_read_addr[14] = 5; role_read_valid[14] = 1;
        role_write_bank[14] = 10; role_write_addr[14] = 6;
        role_write_strb[14] = '1; role_write_data[14] = 128'hbbbb;
        role_write_valid[14] = 1;
        #1;
        if (!role_read_ready[14] || !role_write_ready[14])
            $fatal(1, "in-place access blocked");
        @(posedge aclk); #1;
        role_read_valid[14] = 0; role_write_valid[14] = 0;
        repeat (2) @(posedge aclk); #1;
        if (!role_rsp_valid[14] || role_rsp_data[14] !== 128'haaaa)
            $fatal(1, "in-place read mismatched");
        read_word(14, 10, 6, 128'hbbbb);
        release_bank(10, 14);

        if (subsystem_error || ownership_error || router_error)
            $fatal(1, "unexpected subsystem error");
        // Reset ownership and read outputs; stored B0 data remains.
        @(negedge aclk); aresetn = 0;
        repeat (2) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        acquire(0, 6);
        read_word(6, 0, 4, 128'h0123456789abcdef0011223344556677);

        // A client with the wrong role cannot overwrite the owned bank.
        @(negedge aclk);
        role_write_bank[1] = 0; role_write_addr[1] = 4;
        role_write_data[1] = 128'hbad; role_write_strb[1] = '1;
        role_write_valid[1] = 1;
        #1;
        if (role_write_ready[1]) $fatal(1, "wrong role write accepted");
        @(posedge aclk); #1;
        role_write_valid[1] = 0;
        repeat (2) @(posedge aclk);
        #1;
        if (!router_error || !subsystem_error || subsystem_error_code != 2)
            $fatal(1, "wrong role error not propagated");
        read_word(6, 0, 4, 128'h0123456789abcdef0011223344556677);
        $display("PASS smollm2_bank_subsystem");
        $finish;
    end
endmodule
