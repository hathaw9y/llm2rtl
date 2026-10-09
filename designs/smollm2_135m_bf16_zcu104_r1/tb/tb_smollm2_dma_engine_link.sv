`timescale 1ns/1ps
module tb_smollm2_dma_engine_link;
    logic aclk;
    logic aresetn;
    logic [0:12] bank_busy;
    logic [0:12][4:0] bank_owner_port;
    logic mm2s_cmd_valid;
    logic mm2s_cmd_ready;
    logic [31:0] mm2s_cmd_addr;
    logic [22:0] mm2s_cmd_btt;
    logic [31:0] mm2s_cmd_offset;
    logic [3:0] mm2s_cmd_bank;
    logic mm2s_sts_valid;
    logic mm2s_sts_ready;
    logic [3:0] mm2s_sts_tag;
    logic mm2s_sts_error;
    logic [7:0] mm2s_sts_error_code;
    logic s2mm_cmd_valid;
    logic s2mm_cmd_ready;
    logic [31:0] s2mm_cmd_addr;
    logic [22:0] s2mm_cmd_btt;
    logic [31:0] s2mm_cmd_offset;
    logic [3:0] s2mm_cmd_bank;
    logic s2mm_sts_valid;
    logic s2mm_sts_ready;
    logic [3:0] s2mm_sts_tag;
    logic s2mm_sts_error;
    logic [7:0] s2mm_sts_error_code;
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
    logic role1_write_valid;
    logic role1_write_ready;
    logic [3:0] role1_write_bank;
    logic [15:0] role1_write_addr;
    logic [15:0] role1_write_strb;
    logic [127:0] role1_write_data;
    logic role2_read_valid;
    logic role2_read_ready;
    logic [3:0] role2_read_bank;
    logic [15:0] role2_read_addr;
    logic role2_rsp_valid;
    logic [3:0] role2_rsp_bank;
    logic [127:0] role2_rsp_data;
    logic bridge_fault;
    logic [2:0] bridge_fault_code;
    logic [3:0] bridge_fault_bank;
    logic mm2s_engine_faulted;
    logic s2mm_engine_faulted;
    logic recovery_required;
    logic [3:0] mm2s_engine_status_tag;
    logic [3:0] mm2s_engine_received_tag;
    logic [7:0] mm2s_engine_raw_status;
    logic [3:0] s2mm_engine_status_tag;
    logic [3:0] s2mm_engine_received_tag;
    logic [7:0] s2mm_engine_raw_status;
    smollm2_dma_engine_link dut (.*);
    initial aclk = 0;
    always #2.5 aclk = ~aclk;

    logic [2:0] read_pipe_valid = '0;
    logic [2:0][3:0] read_pipe_bank = '0;
    logic [127:0] last_load_word = '0;
    logic [15:0] last_load_addr = '0;
    int load_write_count = 0;
    assign role1_write_ready = role1_write_valid &&
        bank_busy[role1_write_bank] && bank_owner_port[role1_write_bank] == 5'd1;
    assign role2_read_ready = role2_read_valid &&
        bank_busy[role2_read_bank] && bank_owner_port[role2_read_bank] == 5'd2;
    assign role2_rsp_valid = read_pipe_valid[2];
    assign role2_rsp_bank = read_pipe_bank[2];
    assign role2_rsp_data = 128'h8899aabbccddeeff0011223344556677;
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            read_pipe_valid <= '0;
            read_pipe_bank <= '0;
        end else begin
            read_pipe_valid[0] <= role2_read_valid && role2_read_ready;
            read_pipe_bank[0] <= role2_read_bank;
            for (int stage = 1; stage < 3; stage++) begin
                read_pipe_valid[stage] <= read_pipe_valid[stage-1];
                read_pipe_bank[stage] <= read_pipe_bank[stage-1];
            end
            if (role1_write_valid && role1_write_ready) begin
                last_load_word <= role1_write_data;
                last_load_addr <= role1_write_addr;
                load_write_count <= load_write_count + 1;
            end
        end
    end

    task automatic issue_load(input logic [3:0] bank,
                              input logic [31:0] offset);
        @(negedge aclk);
        mm2s_cmd_bank = bank;
        mm2s_cmd_offset = offset;
        mm2s_cmd_addr = 32'h1000;
        mm2s_cmd_btt = 23'd16;
        mm2s_cmd_valid = 1;
        do @(posedge aclk); while (!mm2s_cmd_ready);
        #1; mm2s_cmd_valid = 0;
    endtask
    task automatic issue_store;
        @(negedge aclk);
        s2mm_cmd_bank = 4'd5;
        s2mm_cmd_offset = 32'd32;
        s2mm_cmd_addr = 32'h2000;
        s2mm_cmd_btt = 23'd16;
        s2mm_cmd_valid = 1;
        do @(posedge aclk); while (!s2mm_cmd_ready);
        #1; s2mm_cmd_valid = 0;
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

    logic [3:0] load_tag, store_tag;
    initial begin
        aresetn = 0;
        bank_busy = '0;
        bank_owner_port = '0;
        mm2s_cmd_valid = 0; mm2s_cmd_addr = 0; mm2s_cmd_btt = 0;
        mm2s_cmd_offset = 0; mm2s_cmd_bank = 0; mm2s_sts_ready = 0;
        s2mm_cmd_valid = 0; s2mm_cmd_addr = 0; s2mm_cmd_btt = 0;
        s2mm_cmd_offset = 0; s2mm_cmd_bank = 0; s2mm_sts_ready = 0;
        m_axis_mm2s_cmd_tready = 1;
        s_axis_mm2s_tdata = 0; s_axis_mm2s_tkeep = 0;
        s_axis_mm2s_tvalid = 0; s_axis_mm2s_tlast = 0;
        s_axis_mm2s_sts_tdata = 0; s_axis_mm2s_sts_tkeep = 0;
        s_axis_mm2s_sts_tvalid = 0; s_axis_mm2s_sts_tlast = 0;
        m_axis_s2mm_cmd_tready = 1;
        m_axis_s2mm_tready = 1;
        s_axis_s2mm_sts_tdata = 0; s_axis_s2mm_sts_tkeep = 0;
        s_axis_s2mm_sts_tvalid = 0; s_axis_s2mm_sts_tlast = 0;
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1;

        bank_busy[0] = 1; bank_owner_port[0] = 5'd1;
        issue_load(4'd0, 32'd32);
        do @(posedge aclk); while (!m_axis_mm2s_cmd_tvalid);
        load_tag = m_axis_mm2s_cmd_tdata[67:64];
        if (m_axis_mm2s_cmd_tdata[63:32] != 32'h1000 ||
            m_axis_mm2s_cmd_tdata[22:0] != 23'd16)
            $fatal(1, "LOAD descriptor mismatch");
        send_load_beat(64'h0011223344556677, 0);
        send_load_beat(64'h8899aabbccddeeff, 1);
        repeat (6) @(posedge aclk);
        #1;
        if (mm2s_sts_valid || load_write_count != 1 || last_load_addr != 2 ||
            last_load_word !== 128'h8899aabbccddeeff0011223344556677)
            $fatal(1, "LOAD completed early or local write mismatch");
        send_load_status(load_tag);
        wait (mm2s_sts_valid);
        if (mm2s_sts_tag != 0 || mm2s_sts_error ||
            mm2s_engine_status_tag != load_tag)
            $fatal(1, "LOAD status mapping mismatch");
        @(negedge aclk); mm2s_sts_ready = 1;
        @(posedge aclk); #1; mm2s_sts_ready = 0;
        bank_busy[0] = 0;

        bank_busy[5] = 1; bank_owner_port[5] = 5'd2;
        issue_store();
        do @(posedge aclk); while (!m_axis_s2mm_cmd_tvalid);
        store_tag = m_axis_s2mm_cmd_tdata[67:64];
        if (m_axis_s2mm_cmd_tdata[63:32] != 32'h2000 ||
            m_axis_s2mm_cmd_tdata[22:0] != 23'd16)
            $fatal(1, "STORE descriptor mismatch");
        for (int beat = 0; beat < 2; beat++) begin
            do @(posedge aclk); while (!(m_axis_s2mm_tvalid && m_axis_s2mm_tready));
            if (m_axis_s2mm_tdata !== (beat == 0 ? 64'h0011223344556677 :
                                                   64'h8899aabbccddeeff) ||
                m_axis_s2mm_tkeep != 8'hff || m_axis_s2mm_tlast != (beat == 1))
                $fatal(1, "STORE stream mismatch beat %0d", beat);
        end
        repeat (4) @(posedge aclk);
        #1; if (s2mm_sts_valid) $fatal(1, "STORE completed before DDR status");
        send_store_status(store_tag);
        wait (s2mm_sts_valid);
        if (s2mm_sts_tag != 5 || s2mm_sts_error ||
            s2mm_engine_status_tag != store_tag)
            $fatal(1, "STORE status mapping mismatch");
        @(negedge aclk); s2mm_sts_ready = 1;
        @(posedge aclk); #1; s2mm_sts_ready = 0;
        bank_busy[5] = 0;

        bank_busy[3] = 1; bank_owner_port[3] = 5'd1;
        issue_load(4'd3, 32'h00800000);
        repeat (7) @(posedge aclk);
        #1;
        if (m_axis_mm2s_cmd_tvalid) $fatal(1, "truncated offset issued to DDR");
        wait (mm2s_sts_valid);
        if (mm2s_sts_tag != 3 || !mm2s_sts_error ||
            mm2s_sts_error_code != 8'h06 || recovery_required)
            $fatal(1, "high offset response tag=%0d err=%b code=%h recovery=%b",
                   mm2s_sts_tag, mm2s_sts_error, mm2s_sts_error_code,
                   recovery_required);
        @(negedge aclk); mm2s_sts_ready = 1;
        @(posedge aclk); #1; mm2s_sts_ready = 0;
        bank_busy[3] = 0;

        bank_busy[0] = 1; bank_owner_port[0] = 5'd1;
        issue_load(4'd0, 32'd32);
        do @(posedge aclk); while (!m_axis_mm2s_cmd_tvalid);
        load_tag = m_axis_mm2s_cmd_tdata[67:64];
        send_load_status(load_tag + 4'd1);
        wait (mm2s_sts_valid);
        if (!mm2s_sts_error || mm2s_sts_error_code != 8'h20 ||
            mm2s_sts_tag != 0 || !recovery_required || mm2s_cmd_ready)
            $fatal(1, "bad DataMover tag did not enter recovery");

        @(negedge aclk); aresetn = 0;
        repeat (2) @(posedge aclk);
        @(negedge aclk); aresetn = 1; bank_busy = '0;
        issue_load(4'd0, 32'd32);
        wait (bridge_fault);
        wait (mm2s_sts_valid);
        if (bridge_fault_code != 3'd3 || bridge_fault_bank != 0 ||
            !mm2s_sts_error || mm2s_sts_error_code != 8'h50 ||
            mm2s_sts_tag != 0 || !recovery_required ||
            !mm2s_engine_faulted || s2mm_engine_faulted)
            $fatal(1, "bridge denial did not reach LOAD command failure");
        $display("PASS smollm2_dma_engine_link");
        $finish;
    end
    initial begin
        #500000;
        $fatal(1, "timeout");
    end
endmodule
