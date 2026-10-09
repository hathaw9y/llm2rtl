`timescale 1ns/1ps
module tb_smollm2_dma_load_checkpoint;
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
    logic [0:20] compute_role_read_wide = '0;
    logic [0:20][255:0] compute_role_rsp_wide_data;
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
    smollm2_dma_control_fabric_wide dut (.profile_events(), .*);
    initial aclk = 0;
    always #2.5 aclk = ~aclk;

    localparam int WEIGHT_ADDR = 'h1000;
    localparam int PREFILL_ADDR = 'h6000;
    localparam int DECODE_ADDR = 'h10000;
    logic [63:0] ddr [0:10239];
    logic [127:0] rom [0:15];
    logic [3:0] load_tag;
    always_ff @(posedge aclk) if (cmd_enb) cmd_doutb <= rom[cmd_addrb];

    function automatic logic [127:0] dma_record(
        input logic [3:0] bank, input logic [22:0] btt,
        input logic [31:0] addr);
        return {4'd1, bank, 8'd0, 32'd0, btt, addr, 25'd0};
    endfunction
    task automatic start_chunk;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(posedge aclk); #1; cmd_dispatcher_start = 0;
    endtask
    task automatic load_from_ddr(
        input int address, input int btt, input int bank);
        logic [3:0] tag;
        @(negedge aclk); m_axis_mm2s_cmd_tready = 1;
        do @(posedge aclk); while (!m_axis_mm2s_cmd_tvalid);
        if (m_axis_mm2s_cmd_tdata[63:32] !== address ||
            m_axis_mm2s_cmd_tdata[22:0] !== btt)
            $fatal(1, "wrong DMA_LOAD descriptor addr=%h btt=%0d",
                   m_axis_mm2s_cmd_tdata[63:32],
                   m_axis_mm2s_cmd_tdata[22:0]);
        tag = m_axis_mm2s_cmd_tdata[67:64];
        #1; m_axis_mm2s_cmd_tready = 0;
        for (int beat = 0; beat < btt/8; beat++) begin
            @(negedge aclk);
            s_axis_mm2s_tdata = ddr[(address/8)+beat];
            s_axis_mm2s_tkeep = 8'hff;
            s_axis_mm2s_tlast = beat == btt/8-1;
            s_axis_mm2s_tvalid = 1;
            do @(posedge aclk); while (!s_axis_mm2s_tready);
            #1; s_axis_mm2s_tvalid = 0;
        end
        repeat (8) @(posedge aclk);
        #1;
        if (cmd_dispatcher_done || !bank_busy[bank] || bank_tensor_valid[bank])
            $fatal(1, "bank %0d released/valid before DDR status", bank);
        @(negedge aclk);
        s_axis_mm2s_sts_tdata = {4'h8, tag};
        s_axis_mm2s_sts_tkeep = 1;
        s_axis_mm2s_sts_tlast = 1;
        s_axis_mm2s_sts_tvalid = 1;
        do @(posedge aclk); while (!s_axis_mm2s_sts_tready);
        #1; s_axis_mm2s_sts_tvalid = 0;
        $display("DMA_LOAD bank=%0d bytes=%0d DDR status sent", bank, btt);
    endtask
    task automatic compare_bank(
        input int role, input int bank, input int ddr_addr,
        input int word_count);
        logic [127:0] expected;
        for (int i = 0; i < word_count; i++) begin
            @(negedge aclk);
            compute_role_read_valid[role] = 1;
            compute_role_read_bank[role] = 4'(bank);
            compute_role_read_addr[role] = 16'(i);
            #1;
            if (!compute_role_read_ready[role])
                $fatal(1, "read role %0d bank %0d not ready", role, bank);
            @(posedge aclk); #1; compute_role_read_valid[role] = 0;
            do @(posedge aclk); while (!compute_role_rsp_valid[role]);
            expected = {ddr[(ddr_addr/8)+2*i+1], ddr[(ddr_addr/8)+2*i]};
            if (compute_role_rsp_bank[role] !== bank ||
                compute_role_rsp_data[role] !== expected)
                $fatal(1, "bank %0d word %0d got=%h expected=%h",
                       bank, i, compute_role_rsp_data[role], expected);
        end
        $display("BANK bank=%0d words=%0d mismatches=0", bank, word_count);
    endtask
    task automatic complete_probe;
        @(negedge aclk);
        compute_done_valid[1] = 1;
        compute_done_tag[1] = 0;
        compute_done_bank_count[1] = 3;
        compute_done_bank[1][0] = 0;
        compute_done_bank[1][1] = 3;
        compute_done_bank[1][2] = 2;
        @(posedge aclk); #1; compute_done_valid[1] = 0;
    endtask
    task automatic wait_done;
        wait (cmd_dispatcher_done || cmd_dispatcher_error);
        #1;
        if (cmd_dispatcher_error || bridge_fault || subsystem_error ||
            ownership_error || router_error || bank_tensor_state_error ||
            system_recovery_required)
            $fatal(1, "DMA fabric error=%h bridge=%b tensor=%b",
                   cmd_dispatcher_error_code, bridge_fault,
                   bank_tensor_state_error);
    endtask

    initial begin
        $readmemh("ddr_input.mem", ddr);
        aresetn = 0; cmd_dispatcher_start = 0;
        compute_cmd_ready = '0; compute_cmd_ready[1] = 1;
        compute_done_valid = '0; compute_done_tag = '0;
        compute_done_bank_count = '0; compute_done_bank = '0;
        compute_done_error = '0;
        compute_role_read_valid = '0; compute_role_read_bank = '0;
        compute_role_read_addr = '0; compute_role_read_wide = '0;
        compute_role_write_valid = '0; compute_role_write_bank = '0;
        compute_role_write_addr = '0; compute_role_write_strb = '0;
        compute_role_write_data = '0;
        m_axis_mm2s_cmd_tready = 0;
        s_axis_mm2s_tdata = 0; s_axis_mm2s_tkeep = 0;
        s_axis_mm2s_tvalid = 0; s_axis_mm2s_tlast = 0;
        s_axis_mm2s_sts_tdata = 0; s_axis_mm2s_sts_tkeep = 0;
        s_axis_mm2s_sts_tvalid = 0; s_axis_mm2s_sts_tlast = 0;
        m_axis_s2mm_cmd_tready = 0; m_axis_s2mm_tready = 0;
        s_axis_s2mm_sts_tdata = 0; s_axis_s2mm_sts_tkeep = 0;
        s_axis_s2mm_sts_tvalid = 0; s_axis_s2mm_sts_tlast = 0;
        for (int i = 0; i < 16; i++) rom[i] = '0;
        rom[0] = dma_record(0, 36864, PREFILL_ADDR);
        rom[1] = dma_record(3, 18432, WEIGHT_ADDR);
        // RMSNORM only acquires legal read roles 6 and 7 in this data probe.
        // It is a testbench response stub; no RMS arithmetic is claimed.
        rom[2] = {4'd4, 4'd0, 4'd3, 4'd2, 112'd0};
        rom[3] = {4'd11, 124'd0};
        rom[4] = '0;
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        start_chunk();
        load_from_ddr(PREFILL_ADDR, 36864, 0);
        load_from_ddr(WEIGHT_ADDR, 18432, 3);
        do @(posedge aclk); while (!compute_cmd_valid[1]);
        if (compute_cmd_opcode[1] != 4'd4 ||
            compute_cmd_bank[1][0] != 0 ||
            compute_cmd_bank[1][1] != 3 ||
            compute_cmd_bank[1][2] != 2)
            $fatal(1, "probe command routed incorrectly");
        compare_bank(6, 0, PREFILL_ADDR, 2304);
        compare_bank(7, 3, WEIGHT_ADDR, 1152);
        complete_probe();
        wait_done();
        if (!bank_tensor_valid[3] || bank_busy[3])
            $fatal(1, "weight bank did not persist across END/DONE");

        @(negedge aclk);
        rom[0] = dma_record(0, 1152, DECODE_ADDR);
        rom[1] = {4'd4, 4'd0, 4'd3, 4'd2, 112'd0};
        rom[2] = {4'd11, 124'd0};
        rom[3] = '0;
        rom[4] = '0;
        start_chunk();
        load_from_ddr(DECODE_ADDR, 1152, 0);
        do @(posedge aclk); while (!compute_cmd_valid[1]);
        compare_bank(6, 0, DECODE_ADDR, 72);
        compare_bank(7, 3, WEIGHT_ADDR, 1152);
        complete_probe();
        wait_done();
        $display("PASS smollm2_dma_load_checkpoint");
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "DMA_LOAD checkpoint simulation timed out pc=%0d error=%b code=%h",
               current_pc, cmd_dispatcher_error, cmd_dispatcher_error_code);
    end
endmodule
