`timescale 1ns/1ps
module tb_smollm2_dma_control_fabric;
    logic aclk;
    logic aresetn;
    logic cmd_dispatcher_start;
    logic cmd_dispatcher_busy;
    logic cmd_dispatcher_done;
    logic cmd_dispatcher_error;
    logic [7:0] cmd_dispatcher_error_code;
    logic [9:0] current_pc;
    logic cmd_enb;
    logic [9:0] cmd_addrb;
    logic [127:0] cmd_doutb;
    logic [6:0] compute_cmd_valid;
    logic [6:0] compute_cmd_ready;
    logic [6:0][3:0] compute_cmd_opcode;
    logic [6:0][2:0][3:0] compute_cmd_bank;
    logic [6:0][111:0] compute_cmd_payload;
    logic [6:0] compute_done_valid;
    logic [6:0] compute_done_ready;
    logic [6:0][3:0] compute_done_tag;
    logic [6:0][1:0] compute_done_bank_count;
    logic [6:0][2:0][3:0] compute_done_bank;
    logic [6:0] compute_done_error;
    logic [0:20] compute_role_read_valid;
    logic [0:20] compute_role_read_ready;
    logic [0:20][3:0] compute_role_read_bank;
    logic [0:20][15:0] compute_role_read_addr;
    logic [0:20] compute_role_rsp_valid;
    logic [0:20][3:0] compute_role_rsp_bank;
    logic [0:20][127:0] compute_role_rsp_data;
    logic [0:20] compute_role_write_valid;
    logic [0:20] compute_role_write_ready;
    logic [0:20][3:0] compute_role_write_bank;
    logic [0:20][15:0] compute_role_write_addr;
    logic [0:20][15:0] compute_role_write_strb;
    logic [0:20][127:0] compute_role_write_data;
    logic [71:0] m_axis_mm2s_cmd_tdata;
    logic m_axis_mm2s_cmd_tvalid;
    logic m_axis_mm2s_cmd_tready;
    logic [63:0] s_axis_mm2s_tdata;
    logic [7:0] s_axis_mm2s_tkeep;
    logic s_axis_mm2s_tvalid;
    logic s_axis_mm2s_tready;
    logic s_axis_mm2s_tlast;
    logic [7:0] s_axis_mm2s_sts_tdata;
    logic s_axis_mm2s_sts_tkeep;
    logic s_axis_mm2s_sts_tvalid;
    logic s_axis_mm2s_sts_tready;
    logic s_axis_mm2s_sts_tlast;
    logic [71:0] m_axis_s2mm_cmd_tdata;
    logic m_axis_s2mm_cmd_tvalid;
    logic m_axis_s2mm_cmd_tready;
    logic [63:0] m_axis_s2mm_tdata;
    logic [7:0] m_axis_s2mm_tkeep;
    logic m_axis_s2mm_tvalid;
    logic m_axis_s2mm_tready;
    logic m_axis_s2mm_tlast;
    logic [7:0] s_axis_s2mm_sts_tdata;
    logic s_axis_s2mm_sts_tkeep;
    logic s_axis_s2mm_sts_tvalid;
    logic s_axis_s2mm_sts_tready;
    logic s_axis_s2mm_sts_tlast;
    logic [0:12] bank_busy;
    logic [0:12][4:0] bank_owner_port;
    logic [12:0] bank_tensor_valid;
    logic [12:0][15:0] tensor_progress;
    logic [12:0] write_pending;
    logic bank_tensor_state_error;
    logic subsystem_error;
    logic [1:0] subsystem_error_code;
    logic ownership_error;
    logic [2:0] ownership_error_code;
    logic router_error;
    logic [2:0] router_error_code;
    logic [4:0] router_error_role;
    logic [3:0] router_error_bank;
    logic bridge_fault;
    logic [2:0] bridge_fault_code;
    logic [3:0] bridge_fault_bank;
    logic external_role_fault;
    logic system_recovery_required;
    smollm2_dma_control_fabric dut (.*);
    initial aclk = 0;
    always #2.5 aclk = ~aclk;

    localparam logic [127:0] B0_WORD = 128'h0123456789abcdef0011223344556677;
    localparam logic [127:0] B9_WORD = 128'hffeeddccbbaa99887766554433221100;
    localparam logic [127:0] B5_WORD = 128'h11112222333344445555666677778888;
    logic [127:0] rom [0:15];
    logic [3:0] load_tag, store_tag;
    always_ff @(posedge aclk) if (cmd_enb) cmd_doutb <= rom[cmd_addrb];

    function automatic logic [127:0] dma_record(
        input logic [3:0] op, input logic [3:0] bank,
        input logic [31:0] offset, input logic [22:0] btt,
        input logic [31:0] addr);
        dma_record = {op, bank, 8'd0, offset, btt, addr, 25'd0};
    endfunction
    task automatic start_chunk;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(posedge aclk); #1; cmd_dispatcher_start = 0;
    endtask
    task automatic send_load_beat(input logic [63:0] data,
                                  input logic last);
        @(negedge aclk);
        s_axis_mm2s_tdata = data;
        s_axis_mm2s_tkeep = 8'hff;
        s_axis_mm2s_tlast = last;
        s_axis_mm2s_tvalid = 1;
        do @(posedge aclk); while (!s_axis_mm2s_tready);
        #1; s_axis_mm2s_tvalid = 0;
    endtask
    task automatic send_load_word(input logic [127:0] word);
        send_load_beat(word[63:0], 0);
        send_load_beat(word[127:64], 1);
    endtask
    task automatic send_load_status(input logic [3:0] tag);
        @(negedge aclk);
        s_axis_mm2s_sts_tdata = {4'h8, tag};
        s_axis_mm2s_sts_tkeep = 1;
        s_axis_mm2s_sts_tlast = 1;
        s_axis_mm2s_sts_tvalid = 1;
        do @(posedge aclk); while (!s_axis_mm2s_sts_tready);
        #1; s_axis_mm2s_sts_tvalid = 0;
    endtask
    task automatic send_store_status(input logic [3:0] tag);
        @(negedge aclk);
        s_axis_s2mm_sts_tdata = {4'h8, tag};
        s_axis_s2mm_sts_tkeep = 1;
        s_axis_s2mm_sts_tlast = 1;
        s_axis_s2mm_sts_tvalid = 1;
        do @(posedge aclk); while (!s_axis_s2mm_sts_tready);
        #1; s_axis_s2mm_sts_tvalid = 0;
    endtask

    initial begin
        aresetn = 0; cmd_dispatcher_start = 0;
        compute_cmd_ready = '1; compute_done_valid = '0;
        compute_done_tag = '0; compute_done_bank_count = '0;
        compute_done_bank = '0; compute_done_error = '0;
        compute_role_read_valid = '0; compute_role_read_bank = '0;
        compute_role_read_addr = '0;
        compute_role_write_valid = '0; compute_role_write_bank = '0;
        compute_role_write_addr = '0; compute_role_write_strb = '0;
        compute_role_write_data = '0;
        m_axis_mm2s_cmd_tready = 1;
        s_axis_mm2s_tdata = 0; s_axis_mm2s_tkeep = 0;
        s_axis_mm2s_tvalid = 0; s_axis_mm2s_tlast = 0;
        s_axis_mm2s_sts_tdata = 0; s_axis_mm2s_sts_tkeep = 0;
        s_axis_mm2s_sts_tvalid = 0; s_axis_mm2s_sts_tlast = 0;
        m_axis_s2mm_cmd_tready = 1; m_axis_s2mm_tready = 1;
        s_axis_s2mm_sts_tdata = 0; s_axis_s2mm_sts_tkeep = 0;
        s_axis_s2mm_sts_tvalid = 0; s_axis_s2mm_sts_tlast = 0;
        for (int i = 0; i < 16; i++) rom[i] = '0;
        rom[0] = dma_record(4'd1, 4'd0, 32'd0, 23'd16, 32'h1000);
        rom[1] = {4'd11, 124'd0};
        rom[2] = '0;
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        start_chunk();
        do @(posedge aclk); while (!m_axis_mm2s_cmd_tvalid);
        load_tag = m_axis_mm2s_cmd_tdata[67:64];
        if (m_axis_mm2s_cmd_tdata[63:32] != 32'h1000)
            $fatal(1, "chunk1 LOAD address mismatch");
        send_load_word(B0_WORD);
        repeat (8) @(posedge aclk);
        #1;
        if (cmd_dispatcher_done || !bank_busy[0] || bank_tensor_valid[0] ||
            current_pc != 10'd1)
            $fatal(1, "FENCE advanced before LOAD DDR status pc=%0d busy=%b valid=%b",
                   current_pc, bank_busy[0], bank_tensor_valid[0]);
        send_load_status(load_tag);
        wait (cmd_dispatcher_done);
        #1;
        if (cmd_dispatcher_error || !bank_tensor_valid[0] || bank_busy[0] ||
            system_recovery_required) $fatal(1, "chunk1 completion mismatch");

        // PS replaces the command BRAM contents only after END/DONE.
        @(negedge aclk);
        rom[0] = dma_record(4'd1, 4'd9, 32'd0, 23'd16, 32'h2000);
        rom[1] = {4'd9, 4'd0, 4'd9, 4'd5, 112'd1};
        rom[2] = dma_record(4'd2, 4'd5, 32'd0, 23'd16, 32'h3000);
        rom[3] = {4'd11, 124'd0};
        rom[4] = '0;
        start_chunk();
        do @(posedge aclk); while (!m_axis_mm2s_cmd_tvalid);
        load_tag = m_axis_mm2s_cmd_tdata[67:64];
        if (m_axis_mm2s_cmd_tdata[63:32] != 32'h2000)
            $fatal(1, "chunk2 LOAD address mismatch");
        send_load_word(B9_WORD);
        send_load_status(load_tag);
        do @(posedge aclk); while (!compute_cmd_valid[6]);
        if (compute_cmd_opcode[6] != 4'd9 ||
            compute_cmd_bank[6][0] != 0 || compute_cmd_bank[6][1] != 9 ||
            compute_cmd_bank[6][2] != 5)
            $fatal(1, "ADD routing mismatch");
        @(negedge aclk);
        compute_role_read_valid[18] = 1;
        compute_role_read_valid[19] = 1;
        compute_role_read_bank[18] = 0;
        compute_role_read_bank[19] = 9;
        compute_role_read_addr[18] = 0;
        compute_role_read_addr[19] = 0;
        #1;
        if (!compute_role_read_ready[18] || !compute_role_read_ready[19])
            $fatal(1, "ADD source banks not acquired");
        @(posedge aclk); #1;
        compute_role_read_valid[18] = 0;
        compute_role_read_valid[19] = 0;
        repeat (2) @(posedge aclk);
        #1;
        if (!compute_role_rsp_valid[18] || !compute_role_rsp_valid[19] ||
            compute_role_rsp_data[18] !== B0_WORD ||
            compute_role_rsp_data[19] !== B9_WORD)
            $fatal(1, "ADD source data mismatch");
        @(negedge aclk);
        compute_role_write_valid[20] = 1;
        compute_role_write_bank[20] = 5;
        compute_role_write_addr[20] = 0;
        compute_role_write_strb[20] = '1;
        compute_role_write_data[20] = B5_WORD;
        #1;
        if (!compute_role_write_ready[20])
            $fatal(1, "ADD output bank not acquired");
        @(posedge aclk); #1; compute_role_write_valid[20] = 0;
        @(negedge aclk);
        compute_done_tag[6] = 0;
        compute_done_bank_count[6] = 3;
        compute_done_bank[6][0] = 0;
        compute_done_bank[6][1] = 9;
        compute_done_bank[6][2] = 5;
        compute_done_valid[6] = 1;
        @(posedge aclk); #1; compute_done_valid[6] = 0;
        do @(posedge aclk); while (!m_axis_s2mm_cmd_tvalid);
        store_tag = m_axis_s2mm_cmd_tdata[67:64];
        if (m_axis_s2mm_cmd_tdata[63:32] != 32'h3000)
            $fatal(1, "STORE address mismatch");
        for (int beat = 0; beat < 2; beat++) begin
            do @(posedge aclk); while (!(m_axis_s2mm_tvalid && m_axis_s2mm_tready));
            if (m_axis_s2mm_tdata !==
                (beat == 0 ? B5_WORD[63:0] : B5_WORD[127:64]) ||
                m_axis_s2mm_tkeep != 8'hff ||
                m_axis_s2mm_tlast != (beat == 1))
                $fatal(1, "STORE stream mismatch beat %0d", beat);
        end
        repeat (8) @(posedge aclk);
        #1;
        if (cmd_dispatcher_done || !bank_busy[5] || current_pc != 10'd3)
            $fatal(1, "FENCE advanced before STORE DDR status pc=%0d", current_pc);
        send_store_status(store_tag);
        wait (cmd_dispatcher_done);
        #1;
        if (cmd_dispatcher_error || !bank_tensor_valid[0] ||
            !bank_tensor_valid[9] || !bank_tensor_valid[5] ||
            bank_busy[5] || system_recovery_required ||
            ownership_error || router_error || bank_tensor_state_error)
            $fatal(1, "chunk2 completion mismatch");

        @(negedge aclk);
        rom[0] = dma_record(4'd2, 4'd5, 32'd0, 23'd16, 32'h4000);
        rom[1] = {4'd11, 124'd0};
        rom[2] = '0;
        start_chunk();
        do @(posedge aclk); while (!m_axis_s2mm_cmd_tvalid);
        store_tag = m_axis_s2mm_cmd_tdata[67:64];
        for (int beat = 0; beat < 2; beat++) begin
            do @(posedge aclk); while (!(m_axis_s2mm_tvalid && m_axis_s2mm_tready));
        end
        send_store_status(store_tag + 4'd1);
        wait (cmd_dispatcher_error);
        #1;
        if (cmd_dispatcher_done || !system_recovery_required ||
            bank_busy[5] || !bank_tensor_valid[5])
            $fatal(1, "bad DDR status did not enter recoverable error state");
        @(negedge aclk); aresetn = 0;
        repeat (2) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        #1;
        if (system_recovery_required || (|bank_tensor_valid) || (|bank_busy))
            $fatal(1, "coordinated reset did not clear control state");

        // An executor response with the wrong bank list must retain ownership
        // and request coherent recovery, even though its tag is correct.
        rom[0] = dma_record(4'd1, 4'd0, 32'd0, 23'd16, 32'h5000);
        rom[1] = dma_record(4'd1, 4'd9, 32'd0, 23'd16, 32'h5010);
        rom[2] = {4'd9, 4'd0, 4'd9, 4'd5, 112'd1};
        rom[3] = '0;
        start_chunk();
        do @(posedge aclk); while (!m_axis_mm2s_cmd_tvalid);
        load_tag = m_axis_mm2s_cmd_tdata[67:64];
        send_load_word(B0_WORD);
        send_load_status(load_tag);
        do @(posedge aclk); while (!m_axis_mm2s_cmd_tvalid);
        load_tag = m_axis_mm2s_cmd_tdata[67:64];
        send_load_word(B9_WORD);
        send_load_status(load_tag);
        do @(posedge aclk); while (!compute_cmd_valid[6]);
        @(negedge aclk);
        compute_done_tag[6] = 0;
        compute_done_bank_count[6] = 3;
        compute_done_bank[6][0] = 0;
        compute_done_bank[6][1] = 8;
        compute_done_bank[6][2] = 5;
        compute_done_valid[6] = 1;
        @(posedge aclk); #1; compute_done_valid[6] = 0;
        repeat (3) @(posedge aclk);
        #1;
        if (!system_recovery_required || cmd_dispatcher_error_code != 8'h03 ||
            !bank_busy[0] || !bank_busy[9] || !bank_busy[5] ||
            bank_tensor_valid[5] || cmd_dispatcher_done)
            $fatal(1, "wrong executor bank list released ownership");

        @(negedge aclk); aresetn = 0;
        repeat (2) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        #1;
        if (system_recovery_required || (|bank_tensor_valid) || (|bank_busy))
            $fatal(1, "compute response recovery reset failed");
        $display("PASS smollm2_dma_control_fabric");
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "timeout");
    end
endmodule
