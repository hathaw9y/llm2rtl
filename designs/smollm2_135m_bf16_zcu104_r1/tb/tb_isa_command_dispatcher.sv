`timescale 1ns/1ps

module tb_isa_command_dispatcher;
    localparam int BANK_NUM = 13;
    logic aclk = 0;
    always #5 aclk = ~aclk;
    logic aresetn = 0;
    logic cmd_dispatcher_start = 0;
    logic cmd_dispatcher_busy, cmd_dispatcher_done, cmd_dispatcher_error;
    logic [7:0] cmd_dispatcher_error_code;
    logic [9:0] current_pc;
    logic cmd_enb;
    logic [9:0] cmd_addrb;
    logic [127:0] cmd_doutb;
    logic [127:0] rom [0:31];

    logic m_ctrl_mm2s_cmd_valid, m_ctrl_mm2s_cmd_ready = 1;
    logic [31:0] m_ctrl_mm2s_cmd_addr, m_ctrl_mm2s_cmd_offset;
    logic [22:0] m_ctrl_mm2s_cmd_btt;
    logic [3:0] m_ctrl_mm2s_cmd_bank, m_ctrl_mm2s_cmd_tag;
    logic s_ctrl_mm2s_sts_valid = 0, m_ctrl_mm2s_sts_ready;
    logic [3:0] s_ctrl_mm2s_sts_tag = 0;
    logic s_ctrl_mm2s_sts_error = 0;
    logic m_ctrl_s2mm_cmd_valid, m_ctrl_s2mm_cmd_ready = 1;
    logic [31:0] m_ctrl_s2mm_cmd_addr, m_ctrl_s2mm_cmd_offset;
    logic [22:0] m_ctrl_s2mm_cmd_btt;
    logic [3:0] m_ctrl_s2mm_cmd_bank, m_ctrl_s2mm_cmd_tag;
    logic s_ctrl_s2mm_sts_valid = 0, m_ctrl_s2mm_sts_ready;
    logic [3:0] s_ctrl_s2mm_sts_tag = 0;
    logic s_ctrl_s2mm_sts_error = 0;

    logic [0:BANK_NUM-1] bank_acquire_valid, bank_release_valid, bank_busy;
    logic [0:BANK_NUM-1][4:0] bank_acquire_port, bank_release_port, bank_owner_port;
    logic ownership_error;
    logic [2:0] ownership_error_code;
    logic [BANK_NUM-1:0] bank_tensor_valid, wr_issue_valid, wr_complete_valid;
    logic [BANK_NUM-1:0][1:0] wr_issue_kind;
    logic [BANK_NUM-1:0][15:0] wr_issue_index, wr_issue_count, wr_issue_total;
    logic [BANK_NUM-1:0] wr_complete_error, write_pending;
    logic [BANK_NUM-1:0][15:0] tensor_progress;
    logic bank_tensor_state_error;
    logic [6:0] compute_cmd_valid, compute_cmd_ready = '1;
    logic [6:0][3:0] compute_cmd_opcode;
    logic [6:0][2:0][3:0] compute_cmd_bank;
    logic [6:0][111:0] compute_cmd_payload;
    logic [6:0] compute_done_valid = '0, compute_done_ready;
    logic [6:0][3:0] compute_done_tag = '0;
    logic [6:0][1:0] compute_done_bank_count = '0;
    logic [6:0][2:0][3:0] compute_done_bank = '0;
    logic [6:0] compute_done_error = '0;
    logic [18:0] profile_events;
    int profile_fence_store_cycles = 0;
    int mm2s_count = 0, gemm_count = 0, store_count = 0, fence_hold = 0;
    int compute_delay [0:6];
    int compute_count [0:6];
    int store_delay = 0;
    logic [6:0][3:0] compute_tag_r;
    logic [6:0][1:0] compute_bank_count_r;
    logic [6:0][2:0][3:0] compute_bank_r;
    logic [3:0] store_tag_r = 0;
    bit completed;
    int gemm_backpressure_cycles = 0;
    bit corrupt_mm2s = 0;
    bit fail_compute = 0;
    bit corrupt_compute_bank = 0;
    bit macro_check = 0;
    int mismatched_compute_responses = 0;
    int correction_delay = 0;
    logic [3:0] correction_tag = 0;

    isa_command_dispatcher #(.BANK_NUM(BANK_NUM), .PORT_ROLE_WIDTH(5)) dut (.*);
    bank_ownership_table #(.BANK_NUM(BANK_NUM), .PORT_ROLE_WIDTH(5)) owners (
        .aclk, .aresetn, .acquire_valid(bank_acquire_valid),
        .acquire_port(bank_acquire_port), .release_valid(bank_release_valid),
        .release_port(bank_release_port), .bank_busy, .bank_owner_port,
        .ownership_error, .ownership_error_code
    );
    bank_tensor_state_tracker #(.BANK_NUM(BANK_NUM)) tracker (
        .aclk, .aresetn, .wr_issue_valid, .wr_issue_kind, .wr_issue_index,
        .wr_issue_count, .wr_issue_total, .wr_complete_valid,
        .wr_complete_error, .tensor_valid(bank_tensor_valid),
        .tensor_progress, .write_pending, .state_error(bank_tensor_state_error)
    );

    function automatic logic [127:0] dma_record(
        input logic [3:0] op, input logic [3:0] bank,
        input logic [31:0] offset, input logic [22:0] btt,
        input logic [31:0] addr, input logic [24:0] aux);
        dma_record = {op, bank, 8'd0, offset, btt, addr, aux};
    endfunction

    function automatic logic [127:0] gemm_record(input logic [15:0] n_start);
        gemm_record = {4'd3, 4'd2, 4'd3, 4'd12, 49'd0,
                       n_start, 16'd384, 6'd0, 6'd1, 11'd576, 8'd192};
    endfunction

    function automatic logic [127:0] gemm_tiles_record(
        input logic [31:0] weight_base);
        gemm_tiles_record = {4'd12, 4'd2, 4'd3, 4'd4,
            weight_base, 16'd576, 11'd576, 6'd0, 6'd1, 8'd192, 33'd0};
    endfunction

    function automatic logic [111:0] one_tile_payload();
        one_tile_payload = {49'd0, 16'd0, 16'd192,
                            6'd0, 6'd1, 11'd576, 8'd192};
    endfunction

    function automatic logic [127:0] compute_record(
        input logic [3:0] op, input logic [3:0] bank0,
        input logic [3:0] bank1, input logic [3:0] bank2,
        input logic [111:0] payload);
        compute_record = {op, bank0, bank1, bank2, payload};
    endfunction

    always_ff @(posedge aclk) begin
        if (cmd_enb) cmd_doutb <= rom[cmd_addrb];
        if (!aresetn) begin
            s_ctrl_mm2s_sts_valid <= 0;
            s_ctrl_s2mm_sts_valid <= 0;
            compute_done_valid <= '0;
            compute_done_error <= '0;
            mismatched_compute_responses <= 0;
            mm2s_count <= 0;
            gemm_count <= 0;
            store_count <= 0;
            fence_hold <= 0;
            profile_fence_store_cycles <= 0;
            store_delay <= 0;
            correction_delay <= 0;
            for (int channel = 0; channel < 7; channel++) begin
                compute_delay[channel] <= 0;
                compute_count[channel] <= 0;
            end
        end else begin
            s_ctrl_mm2s_sts_valid <= 0;
            s_ctrl_s2mm_sts_valid <= 0;
            compute_done_valid <= '0;
            compute_done_error <= '0;
            if (m_ctrl_mm2s_cmd_valid && m_ctrl_mm2s_cmd_ready) begin
                if (macro_check && mm2s_count >= 2 && mm2s_count <= 4 &&
                    (m_ctrl_mm2s_cmd_bank != 4'd3 ||
                     m_ctrl_mm2s_cmd_addr !=
                         (32'h100000 + 32'(mm2s_count - 2)*32'd221184) ||
                     m_ctrl_mm2s_cmd_btt != 23'd221184))
                    $fatal(1, "macro DMA tile address/count mismatch");
                mm2s_count <= mm2s_count + 1;
                s_ctrl_mm2s_sts_valid <= 1;
                s_ctrl_mm2s_sts_tag <= corrupt_mm2s ?
                    (m_ctrl_mm2s_cmd_tag ^ 4'd1) : m_ctrl_mm2s_cmd_tag;
                if (corrupt_mm2s) begin
                    correction_delay <= 3;
                    correction_tag <= m_ctrl_mm2s_cmd_tag;
                end
            end else if (correction_delay > 0) begin
                correction_delay <= correction_delay - 1;
                if (correction_delay == 1) begin
                    s_ctrl_mm2s_sts_valid <= 1;
                    s_ctrl_mm2s_sts_tag <= correction_tag;
                end
            end
            for (int channel = 0; channel < 7; channel++) begin
                if (compute_cmd_valid[channel] && compute_cmd_ready[channel]) begin
                    if (macro_check && channel == 0 &&
                        (compute_cmd_opcode[0] != 4'd3 ||
                         compute_cmd_payload[0][62:47] !=
                            16'(gemm_count * 192) ||
                         compute_cmd_payload[0][46:31] != 16'd576 ||
                         compute_cmd_payload[0][18:8] != 11'd576))
                        $fatal(1, "macro GEMM tile payload mismatch");
                    compute_count[channel] <= compute_count[channel] + 1;
                    if (channel == 0) gemm_count <= gemm_count + 1;
                    compute_tag_r[channel] <= compute_cmd_bank[channel][0];
                    compute_bank_r[channel] <= compute_cmd_bank[channel];
                    compute_bank_count_r[channel] <=
                        (compute_cmd_opcode[channel] == 4'd7) ? 2'd1 :
                        (compute_cmd_opcode[channel] == 4'd5) ? 2'd2 : 2'd3;
                    compute_delay[channel] <= 2;
                end else if (compute_delay[channel] > 0) begin
                    compute_delay[channel] <= compute_delay[channel] - 1;
                    if (compute_delay[channel] == 1) begin
                        compute_done_valid[channel] <= 1;
                        compute_done_tag[channel] <= compute_tag_r[channel];
                        compute_done_bank_count[channel] <= compute_bank_count_r[channel];
                        compute_done_bank[channel] <= compute_bank_r[channel];
                        if (corrupt_compute_bank)
                            compute_done_bank[channel][1] <=
                                compute_bank_r[channel][1] ^ 4'd1;
                        compute_done_error[channel] <= fail_compute;
                    end
                end
            end
            if (m_ctrl_s2mm_cmd_valid && m_ctrl_s2mm_cmd_ready) begin
                store_count <= store_count + 1;
                store_tag_r <= m_ctrl_s2mm_cmd_tag;
                store_delay <= 8;
                if (!bank_tensor_valid[m_ctrl_s2mm_cmd_bank])
                    $fatal(1, "store before complete tensor");
            end else if (store_delay > 0) begin
                store_delay <= store_delay - 1;
                if (store_delay == 1) begin
                    s_ctrl_s2mm_sts_valid <= 1;
                    s_ctrl_s2mm_sts_tag <= store_tag_r;
                end
            end
            if (current_pc == 10 && store_delay > 0 && cmd_dispatcher_busy)
                fence_hold <= fence_hold + 1;
            if (profile_events[0] !== cmd_dispatcher_busy)
                $fatal(1, "profile busy observation mismatch");
            if (profile_events[15]) begin
                if (!profile_events[10] || !profile_events[2])
                    $fatal(1, "profile FENCE STORE reason mismatch");
                profile_fence_store_cycles <= profile_fence_store_cycles + 1;
            end
            if (ownership_error || bank_tensor_state_error)
                $fatal(1, "ownership or tensor-state error");
            if (dut.user_response_fault_w)
                mismatched_compute_responses <= mismatched_compute_responses + 1;
        end
    end

    initial begin
        rom[0] = dma_record(1, 0, 0, 1152, 32'h1000, (2 << 6) | 0);
        rom[1] = dma_record(1, 0, 1152, 1152, 32'h2000, (2 << 6) | 1);
        rom[2] = dma_record(1, 3, 0, 2304, 32'h3000, 0);
        rom[3] = compute_record(4, 0, 3, 2, 2);
        rom[4] = dma_record(1, 3, 0, 2304, 32'h3100, 0);
        rom[5] = gemm_record(0);
        rom[6] = dma_record(1, 3, 0, 2304, 32'h3200, 0);
        rom[7] = gemm_record(192);
        rom[8] = 128'hB0000000000000000000000000000000;
        rom[9] = dma_record(2, 12, 0, 768, 32'h4000, 0);
        rom[10] = 128'hB0000000000000000000000000000000;
        rom[11] = 128'd0;
        compute_cmd_ready[0] = 0;
        repeat (3) @(posedge aclk);
        @(negedge aclk); aresetn = 1;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        completed = 0;
        for (int cycle = 0; cycle < 250; cycle++) begin
            @(negedge aclk);
            if (compute_cmd_valid[0] && !compute_cmd_ready[0]) begin
                if (compute_cmd_opcode[0] != 4'd3 ||
                    compute_cmd_bank[0][0] != 2 ||
                    compute_cmd_bank[0][1] != 3 ||
                    compute_cmd_bank[0][2] != 12 ||
                    compute_cmd_payload[0] != rom[5][111:0])
                    $fatal(1, "GEMM request changed under backpressure");
                gemm_backpressure_cycles++;
                if (gemm_backpressure_cycles == 3) compute_cmd_ready[0] = 1;
            end
            if (gemm_count == 1 && compute_delay[0] > 0 && bank_tensor_valid[12])
                $fatal(1, "first GEMM tile marked complete");
            if (cmd_dispatcher_error)
                $fatal(1, "dispatcher error %0d at PC %0d", cmd_dispatcher_error_code, current_pc);
            if (cmd_dispatcher_done) begin
                if (mm2s_count != 5 || gemm_count != 2 || store_count != 1 ||
                    gemm_backpressure_cycles != 3)
                    $fatal(1, "wrong request counts: %0d %0d %0d", mm2s_count, gemm_count, store_count);
                if (profile_fence_store_cycles == 0)
                    $fatal(1, "FENCE STORE stall was not measured");
                if (fence_hold < 2 || !bank_tensor_valid[0] ||
                    !bank_tensor_valid[2] || !bank_tensor_valid[3] ||
                    !bank_tensor_valid[12])
                    $fatal(1, "FENCE or tensor state not retained");
                completed = 1;
                break;
            end
        end
        if (!completed) $fatal(1, "first chunk timeout at PC %0d", current_pc);

        // PS replaces the single command BRAM after DONE; no reset clears B12.
        rom[0] = dma_record(2, 12, 0, 768, 32'h5000, 0);
        rom[1] = 128'hB0000000000000000000000000000000;
        rom[2] = 128'd0;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        completed = 0;
        for (int cycle = 0; cycle < 100; cycle++) begin
            @(negedge aclk);
            if (cmd_dispatcher_error)
                $fatal(1, "second chunk error %0d", cmd_dispatcher_error_code);
            if (cmd_dispatcher_done) begin
                if (store_count != 2 || !bank_tensor_valid[12])
                    $fatal(1, "bank state lost across chunks");
                completed = 1;
                break;
            end
        end
        if (!completed) $fatal(1, "second chunk timeout");

        // A fresh reset invalidates banks: an S2MM from B12 must fail before issue.
        @(negedge aclk); aresetn = 0;
        rom[0] = dma_record(2, 12, 0, 768, 32'h6000, 0);
        rom[1] = 128'd0;
        repeat (2) @(negedge aclk);
        aresetn = 1;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        completed = 0;
        for (int cycle = 0; cycle < 50; cycle++) begin
            @(negedge aclk);
            if (m_ctrl_s2mm_cmd_valid || store_count != 0)
                $fatal(1, "invalid DMA_STORE issued");
            if (cmd_dispatcher_error) begin
                if (cmd_dispatcher_error_code != 8'h04)
                    $fatal(1, "wrong error code %0d", cmd_dispatcher_error_code);
                completed = 1;
                break;
            end
        end
        if (!completed) $fatal(1, "invalid-store error timeout");

        // Exercise every compute route with the agreed model bank allocation.
        @(negedge aclk); aresetn = 0;
        rom[0] = dma_record(1, 0, 0, 64, 32'h7000, 0);
        rom[1] = dma_record(1, 3, 0, 64, 32'h7040, 0);
        rom[2] = compute_record(4, 0, 3, 2, 1);
        rom[3] = dma_record(1, 3, 0, 64, 32'h7080, 0);
        rom[4] = compute_record(3, 2, 3, 4, one_tile_payload());
        rom[5] = compute_record(3, 2, 3, 5, one_tile_payload());
        rom[6] = compute_record(3, 2, 3, 6, one_tile_payload());
        rom[7] = dma_record(1, 7, 0, 64, 32'h70c0, 0);
        rom[8] = compute_record(5, 4, 7, 0, 1);
        rom[9] = compute_record(5, 5, 7, 0, 1);
        rom[10] = dma_record(2, 5, 0, 64, 32'h7100, 0);
        rom[11] = 128'hB0000000000000000000000000000000;
        rom[12] = dma_record(2, 6, 0, 64, 32'h7140, 0);
        rom[13] = 128'hB0000000000000000000000000000000;
        rom[14] = dma_record(1, 8, 0, 64, 32'h7180, 0);
        rom[15] = dma_record(1, 9, 0, 64, 32'h71c0, 0);
        rom[16] = compute_record(6, 4, 8, 10, 112'd2049);
        rom[17] = compute_record(7, 10, 0, 0, 112'd2049);
        rom[18] = compute_record(8, 10, 9, 11, 112'd2049);
        rom[19] = compute_record(3, 11, 3, 1, one_tile_payload());
        rom[20] = compute_record(9, 0, 1, 5, 32);
        rom[21] = compute_record(4, 5, 3, 2, 1);
        rom[22] = compute_record(3, 2, 3, 8, one_tile_payload());
        rom[23] = compute_record(3, 2, 3, 9, one_tile_payload());
        rom[24] = compute_record(10, 8, 9, 10, 1);
        rom[25] = compute_record(3, 10, 3, 1, one_tile_payload());
        rom[26] = compute_record(9, 5, 1, 0, 32);
        rom[27] = 128'd0;
        repeat (2) @(negedge aclk);
        aresetn = 1;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        completed = 0;
        for (int cycle = 0; cycle < 500; cycle++) begin
            @(negedge aclk);
            if (cmd_dispatcher_error)
                $fatal(1, "compute-route error %0d PC %0d",
                       cmd_dispatcher_error_code, current_pc);
            if (cmd_dispatcher_done) begin
                if (mm2s_count != 6 || store_count != 2 ||
                    compute_count[0] != 7 || compute_count[1] != 2 ||
                    compute_count[2] != 2 ||
                    compute_count[3] != 1 || compute_count[4] != 1 ||
                    compute_count[5] != 1 || compute_count[6] != 3 ||
                    !bank_tensor_valid[2] || !bank_tensor_valid[4] ||
                    !bank_tensor_valid[0] || !bank_tensor_valid[5] ||
                    !bank_tensor_valid[10] ||
                    !bank_tensor_valid[11])
                    $fatal(1, "compute routing or state mismatch");
                completed = 1;
                break;
            end
        end
        if (!completed) $fatal(1, "compute-route timeout at PC %0d", current_pc);

        // A completion naming a different source bank must not release any bank.
        @(negedge aclk); aresetn = 0;
        corrupt_compute_bank = 1;
        rom[0] = dma_record(1, 0, 0, 64, 32'h8800, 0);
        rom[1] = dma_record(1, 3, 0, 64, 32'h8840, 0);
        rom[2] = compute_record(4, 0, 3, 2, 1);
        rom[3] = 128'd0;
        repeat (2) @(negedge aclk);
        aresetn = 1;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        repeat (30) @(negedge aclk);
        if (mismatched_compute_responses != 1 || !bank_busy[0] ||
            !bank_busy[2] || !bank_busy[3] || bank_tensor_valid[2] ||
            cmd_dispatcher_done || cmd_dispatcher_error_code != 8'h03)
            $fatal(1, "wrong compute bank released ownership or completed output");
        corrupt_compute_bank = 0;

        // A wrong status tag must not release B0. A later matching status drains it.
        @(negedge aclk); aresetn = 0;
        corrupt_mm2s = 1;
        rom[0] = dma_record(1, 0, 0, 64, 32'h9000, 0);
        rom[1] = 128'd0;
        repeat (2) @(negedge aclk);
        aresetn = 1;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        completed = 0;
        for (int cycle = 0; cycle < 70; cycle++) begin
            @(negedge aclk);
            if (correction_delay == 2 && !bank_busy[0])
                $fatal(1, "wrong tag released bank");
            if (cmd_dispatcher_error) begin
                if (cmd_dispatcher_error_code != 8'h03 || bank_busy[0])
                    $fatal(1, "mismatch response did not drain correctly");
                completed = 1;
                break;
            end
        end
        if (!completed) $fatal(1, "mismatch response timeout");

        // A matched failed compute response releases all roles and invalidates B4.
        @(negedge aclk); aresetn = 0;
        corrupt_mm2s = 0;
        fail_compute = 1;
        rom[0] = dma_record(1, 0, 0, 64, 32'hA000, 0);
        rom[1] = dma_record(1, 3, 0, 64, 32'hA040, 0);
        rom[2] = compute_record(4, 0, 3, 2, 1);
        rom[3] = gemm_record(0);
        rom[4] = 128'd0;
        repeat (2) @(negedge aclk);
        aresetn = 1;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        completed = 0;
        for (int cycle = 0; cycle < 100; cycle++) begin
            @(negedge aclk);
            if (cmd_dispatcher_error) begin
                if (cmd_dispatcher_error_code != 8'h04 ||
                    bank_tensor_valid[12] || bank_busy != '0)
                    $fatal(1, "failed compute did not invalidate and release");
                completed = 1;
                break;
            end
        end
        if (!completed) $fatal(1, "failed-compute response timeout");

        // Model-illegal DMA and compute bank pairs must stop before acceptance.
        @(negedge aclk); aresetn = 0;
        fail_compute = 0;
        rom[0] = dma_record(1, 6, 0, 64, 32'hB000, 0);
        rom[1] = 128'd0;
        repeat (2) @(negedge aclk);
        aresetn = 1;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        completed = 0;
        for (int cycle = 0; cycle < 50; cycle++) begin
            @(negedge aclk);
            if (m_ctrl_mm2s_cmd_valid || mm2s_count != 0)
                $fatal(1, "illegal DMA bank pair issued");
            if (cmd_dispatcher_error) begin
                if (cmd_dispatcher_error_code != 8'h04)
                    $fatal(1, "wrong illegal DMA error");
                completed = 1;
                break;
            end
        end
        if (!completed) $fatal(1, "illegal DMA pair timeout");

        @(negedge aclk); aresetn = 0;
        rom[0] = compute_record(3, 0, 3, 12, one_tile_payload());
        rom[1] = 128'd0;
        repeat (2) @(negedge aclk);
        aresetn = 1;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        completed = 0;
        for (int cycle = 0; cycle < 50; cycle++) begin
            @(negedge aclk);
            if (compute_cmd_valid[0] || gemm_count != 0)
                $fatal(1, "illegal GEMM bank pair issued");
            if (cmd_dispatcher_error) begin
                if (cmd_dispatcher_error_code != 8'h02)
                    $fatal(1, "wrong illegal GEMM error");
                completed = 1;
                break;
            end
        end
        if (!completed) $fatal(1, "illegal GEMM pair timeout");

        // One GEMM_TILES descriptor must expand into three ordinary DMA/GEMM
        // pairs, retaining the existing completion and bank ownership rules.
        @(negedge aclk); aresetn = 0;
        rom[0] = dma_record(1, 0, 0, 64, 32'hC000, 0);
        rom[1] = dma_record(1, 3, 0, 64, 32'hC040, 0);
        rom[2] = compute_record(4, 0, 3, 2, 1);
        rom[3] = gemm_tiles_record(32'h100000);
        rom[4] = 128'd0;
        repeat (2) @(negedge aclk);
        aresetn = 1;
        macro_check = 1;
        @(negedge aclk); cmd_dispatcher_start = 1;
        @(negedge aclk); cmd_dispatcher_start = 0;
        completed = 0;
        for (int cycle = 0; cycle < 500; cycle++) begin
            @(negedge aclk);
            if (cmd_dispatcher_error)
                $fatal(1, "GEMM_TILES error %0d at PC %0d",
                       cmd_dispatcher_error_code, current_pc);
            if (cmd_dispatcher_done) begin
                if (mm2s_count != 5 || gemm_count != 3 ||
                    !bank_tensor_valid[4] || bank_busy != '0)
                    $fatal(1, "GEMM_TILES count/state mismatch");
                completed = 1;
                break;
            end
        end
        if (!completed) $fatal(1, "GEMM_TILES completion timeout");
        macro_check = 0;
        $display("PASS isa_command_dispatcher integration");
        $finish;
    end
endmodule
