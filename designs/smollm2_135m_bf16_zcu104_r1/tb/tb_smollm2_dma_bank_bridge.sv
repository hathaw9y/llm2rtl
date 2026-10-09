`timescale 1ns/1ps

module tb_smollm2_dma_bank_bridge;
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

    logic wr_req [13], wr_grant [13], load_start [13], load_done [13],
          load_abort [13], load_valid [13], load_ready [13], load_last [13];
    logic [22:0] load_offset [13];
    logic [63:0] load_data [13];
    logic [7:0] load_keep [13];
    logic rd_req [13], rd_grant [13], store_start [13], store_done [13],
          store_abort [13], store_valid [13], store_ready [13], store_last [13];
    logic [22:0] store_offset [13], store_btt [13];
    logic [63:0] store_data [13];
    logic [7:0] store_keep [13];
    logic bridge_fault, bridge_fault_load, bridge_fault_store;
    int load_write_count = 0;
    logic drop_store_response = 0;
    logic [2:0] bridge_fault_code;
    logic [3:0] bridge_fault_bank;

    smollm2_bank_subsystem banks (.*);
    smollm2_dma_bank_bridge bridge (
        .aclk(aclk), .aresetn(aresetn), .bank_busy(bank_busy),
        .bank_owner_port(bank_owner_port),
        .wr_req(wr_req), .wr_grant(wr_grant),
        .load_start(load_start), .load_done(load_done), .load_abort(load_abort),
        .load_offset(load_offset), .load_data(load_data), .load_keep(load_keep),
        .load_valid(load_valid), .load_ready(load_ready), .load_last(load_last),
        .rd_req(rd_req), .rd_grant(rd_grant),
        .store_start(store_start), .store_done(store_done),
        .store_abort(store_abort), .store_offset(store_offset),
        .store_btt(store_btt), .store_data(store_data),
        .store_keep(store_keep), .store_valid(store_valid),
        .store_ready(store_ready), .store_last(store_last),
        .role1_write_valid(role_write_valid[1]),
        .role1_write_ready(role_write_ready[1]),
        .role1_write_bank(role_write_bank[1]),
        .role1_write_addr(role_write_addr[1]),
        .role1_write_strb(role_write_strb[1]),
        .role1_write_data(role_write_data[1]),
        .role2_read_valid(role_read_valid[2]),
        .role2_read_ready(role_read_ready[2]),
        .role2_read_bank(role_read_bank[2]),
        .role2_read_addr(role_read_addr[2]),
        .role2_rsp_valid(role_rsp_valid[2] && !drop_store_response),
        .role2_rsp_bank(role_rsp_bank[2]),
        .role2_rsp_data(role_rsp_data[2]),
        .bridge_fault(bridge_fault), .bridge_fault_load(bridge_fault_load),
        .bridge_fault_store(bridge_fault_store), .bridge_fault_code(bridge_fault_code),
        .bridge_fault_bank(bridge_fault_bank)
    );

    always @(posedge aclk) begin
        if (aresetn && role_write_valid[1]) begin
            if (!role_write_ready[1] || role_write_strb[1] != 16'hffff)
                $fatal(1, "registered LOAD write rejected");
            case (load_write_count)
                0: if (role_write_bank[1] != 0 || role_write_addr[1] != 2 ||
                       role_write_data[1] !==
                           128'h8899aabbccddeeff0011223344556677)
                       $fatal(1, "B0 registered LOAD write mismatch");
                1: if (role_write_bank[1] != 3 || role_write_addr[1] != 0 ||
                       role_write_data[1] !==
                           128'h22222222222222221111111111111111)
                       $fatal(1, "B3 first registered LOAD write mismatch");
                2: if (role_write_bank[1] != 3 || role_write_addr[1] != 1 ||
                       role_write_data[1] !==
                           128'h44444444444444443333333333333333)
                       $fatal(1, "B3 second registered LOAD write mismatch");
                default: $fatal(1, "unexpected extra LOAD write");
            endcase
            if (load_done[role_write_bank[1]])
                $fatal(1, "LOAD done before bank write drains");
            load_write_count <= load_write_count + 1;
        end
    end

    task automatic acquire(input int bank, input int role);
        @(negedge aclk);
        bank_acquire_valid[bank] = 1;
        bank_acquire_port[bank] = 5'(role);
        @(posedge aclk); #1;
        bank_acquire_valid[bank] = 0;
        if (!bank_busy[bank] || bank_owner_port[bank] != 5'(role))
            $fatal(1, "acquire failed");
    endtask
    task automatic release_bank(input int bank, input int role);
        @(negedge aclk);
        bank_release_valid[bank] = 1;
        bank_release_port[bank] = 5'(role);
        @(posedge aclk); #1;
        bank_release_valid[bank] = 0;
        if (bank_busy[bank]) $fatal(1, "release failed");
    endtask
    task automatic load_beat(input int bank, input logic [63:0] data,
                             input logic last);
        @(negedge aclk);
        load_data[bank] = data;
        load_keep[bank] = 8'hff;
        load_last[bank] = last;
        load_valid[bank] = 1;
        do @(posedge aclk); while (!load_ready[bank]);
        #1; load_valid[bank] = 0;
    endtask

    initial begin
        for (int i = 0; i < 13; i++) begin
            wr_req[i] = 0; load_start[i] = 0; load_abort[i] = 0;
            load_offset[i] = 0; load_data[i] = 0; load_keep[i] = 0;
            load_valid[i] = 0; load_last[i] = 0;
            rd_req[i] = 0; store_start[i] = 0; store_abort[i] = 0;
            store_offset[i] = 0; store_btt[i] = 0; store_ready[i] = 0;
        end
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        acquire(0, 1);
        @(negedge aclk);
        wr_req[0] = 1;
        #1; if (!wr_grant[0]) $fatal(1, "LOAD grant missing");
        wr_req[0] = 0;
        load_start[0] = 1;
        load_offset[0] = 23'd32;
        @(posedge aclk); #1; load_start[0] = 0;
        load_beat(0, 64'h0011223344556677, 0);
        load_beat(0, 64'h8899aabbccddeeff, 1);
        wait (load_done[0]);
        if (load_write_count != 1)
            $fatal(1, "LOAD done before exactly one bank write");
        if (bridge_fault || router_error) $fatal(1, "LOAD bridge fault");
        release_bank(0, 1);
        acquire(0, 6);
        @(negedge aclk);
        role_read_valid[6] = 1;
        role_read_bank[6] = 0;
        role_read_addr[6] = 2;
        #1; if (!role_read_ready[6]) $fatal(1, "compute read blocked");
        @(posedge aclk); #1; role_read_valid[6] = 0;
        repeat (2) @(posedge aclk); #1;
        if (!role_rsp_valid[6] ||
            role_rsp_data[6] !== 128'h8899aabbccddeeff0011223344556677)
            $fatal(1, "LOAD data not visible to compute");
        release_bank(0, 6);

        acquire(3, 1);
        @(negedge aclk);
        wr_req[3] = 1;
        #1; if (!wr_grant[3]) $fatal(1, "B3 LOAD grant missing");
        wr_req[3] = 0;
        load_start[3] = 1;
        @(posedge aclk); #1; load_start[3] = 0;
        load_beat(3, 64'h1111111111111111, 0);
        load_beat(3, 64'h2222222222222222, 0);
        load_beat(3, 64'h3333333333333333, 0);
        load_beat(3, 64'h4444444444444444, 1);
        wait (load_done[3]);
        if (load_write_count != 3 || bridge_fault || router_error)
            $fatal(1, "B3 LOAD did not drain both bank writes");
        release_bank(3, 1);
        acquire(3, 4);
        @(negedge aclk);
        role_read_valid[4] = 1;
        role_read_bank[4] = 3;
        role_read_addr[4] = 1;
        #1; if (!role_read_ready[4]) $fatal(1, "B3 compute read blocked");
        @(posedge aclk); #1; role_read_valid[4] = 0;
        repeat (2) @(posedge aclk); #1;
        if (!role_rsp_valid[4] ||
            role_rsp_data[4] !== 128'h44444444444444443333333333333333)
            $fatal(1, "B3 LOAD data not visible to compute");
        release_bank(3, 4);

        acquire(5, 9);
        @(negedge aclk);
        role_write_valid[9] = 1;
        role_write_bank[9] = 5;
        role_write_addr[9] = 2;
        role_write_strb[9] = '1;
        role_write_data[9] = 128'h8899aabbccddeeff0011223344556677;
        #1; if (!role_write_ready[9]) $fatal(1, "compute write blocked");
        @(posedge aclk); #1; role_write_valid[9] = 0;
        release_bank(5, 9);
        acquire(5, 2);
        @(negedge aclk);
        rd_req[5] = 1;
        #1; if (!rd_grant[5]) $fatal(1, "STORE grant missing");
        rd_req[5] = 0;
        store_start[5] = 1;
        store_offset[5] = 23'd32;
        store_btt[5] = 23'd16;
        store_ready[5] = 1;
        @(posedge aclk); #1; store_start[5] = 0;
        for (int beat = 0; beat < 2; beat++) begin
            do @(posedge aclk); while (!(store_valid[5] && store_ready[5]));
            if (store_data[5] !== (beat == 0 ? 64'h0011223344556677 :
                                               64'h8899aabbccddeeff))
                $fatal(1, "STORE data mismatch beat %0d got %h", beat, store_data[5]);
            if (store_keep[5] != 8'hff || store_last[5] != (beat == 1))
                $fatal(1, "STORE keep/last mismatch");
        end
        wait (store_done[5]);
        if (bridge_fault || router_error) $fatal(1, "STORE bridge fault %d", bridge_fault_code);
        release_bank(5, 2);
        @(negedge aclk); wr_req[0] = 1;
        @(posedge aclk); #1; wr_req[0] = 0;
        if (!bridge_fault || !bridge_fault_load || bridge_fault_store ||
            bridge_fault_code != 3'd3 || bridge_fault_bank != 0)
            $fatal(1, "unowned grant did not fault");
        @(negedge aclk); aresetn = 0;
        repeat (2) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        acquire(5, 2);
        @(negedge aclk);
        drop_store_response = 1;
        store_start[5] = 1;
        store_offset[5] = 23'd32;
        store_btt[5] = 23'd16;
        @(posedge aclk); #1; store_start[5] = 0;
        repeat (15) @(posedge aclk);
        #1;
        if (!bridge_fault || bridge_fault_load || !bridge_fault_store ||
            bridge_fault_code != 3'd5 || bridge_fault_bank != 5)
            $fatal(1, "missing STORE read response did not fault");
        $display("PASS smollm2_dma_bank_bridge");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "timeout");
    end
endmodule
