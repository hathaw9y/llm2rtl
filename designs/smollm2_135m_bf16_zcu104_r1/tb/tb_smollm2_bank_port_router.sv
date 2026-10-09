`timescale 1ns/1ps

module tb_smollm2_bank_port_router;
    logic aclk = 0;
    always #5 aclk = ~aclk;
    logic aresetn = 0;
    logic [0:12] bank_busy = '0;
    logic [0:12][4:0] bank_owner_port = '0;
    logic [0:20] role_read_valid = '0, role_read_ready;
    logic [0:20][3:0] role_read_bank = '0;
    logic [0:20][15:0] role_read_addr = '0;
    logic [0:20] role_rsp_valid;
    logic [0:20][3:0] role_rsp_bank;
    logic [0:20][127:0] role_rsp_data;
    logic [0:20] role_write_valid = '0, role_write_ready;
    logic [0:20][3:0] role_write_bank = '0;
    logic [0:20][15:0] role_write_addr = '0, role_write_strb = '0;
    logic [0:20][127:0] role_write_data = '0;
    logic [0:12] bank_ena, bank_enb;
    logic [0:12][15:0] bank_wea, bank_addra, bank_addrb;
    logic [0:12][127:0] bank_dina, bank_doutb;
    logic router_error;
    logic [2:0] router_error_code;
    logic [4:0] router_error_role;
    logic [3:0] router_error_bank;
    logic [127:0] mem [0:12][0:63];
    logic [127:0] read_pipe [0:12][0:2];
    int capacity [0:12] = '{2304,2304,2304,36864,2304,2304,768,
                             512,24576,24576,36864,2304,6144};
    int read_role_by_bank [0:12] = '{6,19,3,4,11,6,2,10,12,16,14,3,2};

    smollm2_bank_port_router dut (.*);

    always_ff @(posedge aclk) begin
        for (int bank = 0; bank < 13; bank++) begin
            if (bank_ena[bank]) begin
                if (bank_addra[bank] >= 64) $fatal(1, "test memory write range");
                for (int lane = 0; lane < 16; lane++) begin
                    if (bank_wea[bank][lane])
                        mem[bank][bank_addra[bank]][lane*8 +: 8] <=
                            bank_dina[bank][lane*8 +: 8];
                end
            end
            if (bank_enb[bank]) begin
                if (bank_addrb[bank] >= 64) $fatal(1, "test memory read range");
                read_pipe[bank][0] <= mem[bank][bank_addrb[bank]];
            end
            read_pipe[bank][1] <= read_pipe[bank][0];
            read_pipe[bank][2] <= read_pipe[bank][1];
        end
    end

    for (genvar bank = 0; bank < 13; bank++) begin : read_outputs
        assign bank_doutb[bank] = read_pipe[bank][2];
    end

    task automatic write_word(input int role, input int bank,
                              input int addr, input logic [127:0] value);
        @(negedge aclk);
        role_write_bank[role] = 4'(bank);
        role_write_addr[role] = 16'(addr);
        role_write_strb[role] = 16'hffff;
        role_write_data[role] = value;
        role_write_valid[role] = 1;
        #1;
        if (!role_write_ready[role]) $fatal(1, "write not ready");
        @(posedge aclk);
        #1;
        role_write_valid[role] = 0;
    endtask

    task automatic read_word(input int role, input int bank,
                             input int addr, input logic [127:0] expected);
        @(negedge aclk);
        role_read_bank[role] = 4'(bank);
        role_read_addr[role] = 16'(addr);
        role_read_valid[role] = 1;
        #1;
        if (!role_read_ready[role]) $fatal(1, "read not ready");
        @(posedge aclk);
        #1;
        role_read_valid[role] = 0;
        repeat (2) @(posedge aclk);
        #1;
        if (!role_rsp_valid[role] || role_rsp_bank[role] != 4'(bank) ||
            role_rsp_data[role] !== expected)
            $fatal(1, "read response mismatch role=%0d bank=%0d", role, bank);
    endtask

    initial begin
        for (int bank = 0; bank < 13; bank++)
            for (int addr = 0; addr < 64; addr++) mem[bank][addr] = '0;
        repeat (2) @(posedge aclk);
        @(negedge aclk); aresetn = 1;

        bank_busy[0] = 1;
        bank_owner_port[0] = 5'd1;
        write_word(1, 0, 4, 128'h0123456789abcdef0011223344556677);
        @(negedge aclk);
        role_write_bank[1] = 0; role_write_addr[1] = 4;
        role_write_strb[1] = 16'h0003;
        role_write_data[1] = 128'hbeef;
        role_write_valid[1] = 1;
        #1;
        if (!role_write_ready[1]) $fatal(1, "partial write not ready");
        @(posedge aclk); #1;
        role_write_valid[1] = 0;
        @(negedge aclk); bank_owner_port[0] = 5'd6;
        read_word(6, 0, 4, 128'h0123456789abcdef001122334455beef);

        bank_busy[2] = 1; bank_owner_port[2] = 5'd3;
        bank_busy[3] = 1; bank_owner_port[3] = 5'd4;
        bank_busy[4] = 1; bank_owner_port[4] = 5'd5;
        mem[2][2] = 128'h1111;
        mem[3][7] = 128'h3333;
        @(negedge aclk);
        role_read_bank[3] = 2; role_read_addr[3] = 2; role_read_valid[3] = 1;
        role_read_bank[4] = 3; role_read_addr[4] = 7; role_read_valid[4] = 1;
        role_write_bank[5] = 4; role_write_addr[5] = 10;
        role_write_strb[5] = '1; role_write_data[5] = 128'h5555;
        role_write_valid[5] = 1;
        #1;
        if (!role_read_ready[3] || !role_read_ready[4] || !role_write_ready[5])
            $fatal(1, "GEMM ports not ready together");
        @(posedge aclk);
        #1;
        role_read_valid[3] = 0; role_read_valid[4] = 0; role_write_valid[5] = 0;
        repeat (2) @(posedge aclk);
        #1;
        if (!role_rsp_valid[3] || !role_rsp_valid[4] ||
            role_rsp_data[3] !== 128'h1111 || role_rsp_data[4] !== 128'h3333 ||
            mem[4][10] !== 128'h5555)
            $fatal(1, "concurrent GEMM routing failed");

        bank_busy[10] = 1; bank_owner_port[10] = 5'd14;
        mem[10][5] = 128'haaaa;
        @(negedge aclk);
        role_read_bank[14] = 10; role_read_addr[14] = 5; role_read_valid[14] = 1;
        role_write_bank[14] = 10; role_write_addr[14] = 6;
        role_write_strb[14] = '1; role_write_data[14] = 128'hbbbb;
        role_write_valid[14] = 1;
        #1;
        if (!role_read_ready[14] || !role_write_ready[14])
            $fatal(1, "in-place ports not ready together");
        @(posedge aclk);
        #1;
        role_read_valid[14] = 0; role_write_valid[14] = 0;
        repeat (2) @(posedge aclk);
        #1;
        if (!role_rsp_valid[14] || role_rsp_data[14] !== 128'haaaa ||
            mem[10][6] !== 128'hbbbb)
            $fatal(1, "in-place routing failed");

        for (int bank = 0; bank < 13; bank++) begin
            bank_busy[bank] = 1;
            bank_owner_port[bank] = 5'(read_role_by_bank[bank]);
            role_read_bank[read_role_by_bank[bank]] = 4'(bank);
            role_read_addr[read_role_by_bank[bank]] = 16'(capacity[bank] - 1);
            #1;
            if (!role_read_ready[read_role_by_bank[bank]])
                $fatal(1, "last word rejected bank %0d", bank);
            role_read_addr[read_role_by_bank[bank]] = 16'(capacity[bank]);
            #1;
            if (role_read_ready[read_role_by_bank[bank]])
                $fatal(1, "past-end word accepted bank %0d", bank);
        end

        @(negedge aclk);
        bank_owner_port[0] = 5'd1;
        role_read_bank[6] = 0; role_read_addr[6] = 0; role_read_valid[6] = 1;
        #1;
        if (role_read_ready[6]) $fatal(1, "owner mismatch accepted");
        @(posedge aclk);
        #1;
        role_read_valid[6] = 0;
        @(posedge aclk); #1;
        if (!router_error || router_error_code != 3 ||
            router_error_role != 6 || router_error_bank != 0)
            $fatal(1, "owner mismatch not reported");

        @(negedge aclk); aresetn = 0;
        @(posedge aclk); #1;
        @(negedge aclk); aresetn = 1;
        role_read_bank[2] = 13; role_read_addr[2] = 0; role_read_valid[2] = 1;
        #1;
        if (role_read_ready[2]) $fatal(1, "bank 13 accepted");
        @(posedge aclk); #1;
        role_read_valid[2] = 0;
        @(posedge aclk); #1;
        if (!router_error || router_error_code != 1 || router_error_bank != 13)
            $fatal(1, "out-of-range bank not reported");

        @(negedge aclk); aresetn = 0;
        @(posedge aclk); #1;
        @(negedge aclk); aresetn = 1;
        bank_busy[0] = 1; bank_owner_port[0] = 5'd1;
        role_read_bank[1] = 0; role_read_addr[1] = 0; role_read_valid[1] = 1;
        #1;
        if (role_read_ready[1]) $fatal(1, "write-only role read accepted");
        @(posedge aclk); #1;
        role_read_valid[1] = 0;
        @(posedge aclk); #1;
        if (!router_error || router_error_code != 2 || router_error_role != 1)
            $fatal(1, "unsupported role access not reported");

        @(negedge aclk); aresetn = 0;
        @(posedge aclk); #1;
        @(negedge aclk); aresetn = 1;
        bank_busy[3] = 1; bank_owner_port[3] = 5'd6;
        role_read_bank[6] = 3; role_read_addr[6] = 0; role_read_valid[6] = 1;
        #1;
        if (role_read_ready[6]) $fatal(1, "unsupported role-bank pair accepted");
        @(posedge aclk); #1;
        role_read_valid[6] = 0;
        @(posedge aclk); #1;
        if (!router_error || router_error_code != 5 ||
            router_error_role != 6 || router_error_bank != 3)
            $fatal(1, "unsupported role-bank pair not reported");
        $display("PASS smollm2_bank_port_router");
        $finish;
    end
endmodule
