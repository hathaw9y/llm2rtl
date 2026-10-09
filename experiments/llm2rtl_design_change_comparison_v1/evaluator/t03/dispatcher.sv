`timescale 1ns/1ps

module t03_dispatcher;
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

    bit baseline;
function automatic bit selected(input int count);
 bit pub;begin pub=(count==1||count==2||count==8||count==16||count==31||count==32);selected=$test$plusargs("public")?pub:$test$plusargs("hidden")?!pub:1;end
endfunction int expected_raw, expected_start, expected_tiles, seen_compute, seen_dma, seen_write_issue;
    logic [127:0] expected_record;
    always @(posedge aclk) begin
        if(cmd_enb) cmd_doutb <= rom[cmd_addrb];
        if(!aresetn) begin compute_done_valid <= 0; s_ctrl_mm2s_sts_valid <= 0; end
        else begin
            compute_done_valid <= 0; s_ctrl_mm2s_sts_valid <= 0;
            if(wr_issue_valid) seen_write_issue++;
            if(compute_cmd_valid[6:1]) $fatal(1,"unexpected compute channel");
            if(m_ctrl_mm2s_cmd_valid && m_ctrl_mm2s_cmd_ready) begin
                if(m_ctrl_mm2s_cmd_bank!=3 || m_ctrl_mm2s_cmd_addr != 32'h100000+seen_dma*6144 || m_ctrl_mm2s_cmd_btt!=6144)
                    $fatal(1,"macro DMA mismatch");
                seen_dma=seen_dma+1; s_ctrl_mm2s_sts_valid<=1; s_ctrl_mm2s_sts_tag<=m_ctrl_mm2s_cmd_tag;
            end
            if(compute_cmd_valid[0] && compute_cmd_ready[0]) begin
                expected_record={4'd3,4'd2,4'd3,4'd4,49'd0,16'(seen_compute*192),16'(expected_tiles*192),6'(expected_start),6'(expected_raw),11'd16,8'd192};
                if({compute_cmd_opcode[0],compute_cmd_bank[0][0],compute_cmd_bank[0][1],compute_cmd_bank[0][2],compute_cmd_payload[0]}!==expected_record)
                    $fatal(1,"expanded command mismatch");
                seen_compute=seen_compute+1; compute_done_valid[0]<=1; compute_done_tag[0]<=2;
                compute_done_bank_count[0]<=3; compute_done_bank[0]<=compute_cmd_bank[0];
            end
        end
    end
    task automatic run_case(input int raw,input int start,input bit macro_cmd,input bit invalid,input bit keep_state=0);
        int cycles;
        begin
            @(negedge aclk); if(!keep_state) aresetn=0; cmd_dispatcher_start=0;
            seen_compute=0; seen_dma=0; seen_write_issue=0; expected_raw=raw; expected_start=start; expected_tiles=macro_cmd?2:1;
            bank_tensor_valid='1; bank_tensor_state_error=0;
            if(macro_cmd) rom[0]={4'd12,4'd2,4'd3,4'd4,32'h100000,16'd384,11'd16,6'(start),6'(raw),8'd192,33'd0};
            else rom[0]={4'd3,4'd2,4'd3,4'd4,49'd0,16'd0,16'd192,6'(start),6'(raw),11'd16,8'd192};
            rom[1]='0;
            repeat(4) @(negedge aclk); aresetn=1; cmd_dispatcher_start=1;
            @(negedge aclk); cmd_dispatcher_start=0; cycles=0;
            while(!cmd_dispatcher_done && !cmd_dispatcher_error && cycles<3000) begin @(negedge aclk); cycles++; end
            if(cycles==3000) $fatal(1,"dispatcher timeout");
            if(invalid) begin
                if(!cmd_dispatcher_error || seen_compute || seen_dma || seen_write_issue) $fatal(1,"invalid accepted or issued writes");
            end else if(cmd_dispatcher_error || seen_compute!=expected_tiles || seen_dma!=(macro_cmd?2:0)) $fatal(1,"completion mismatch");
        end
    endtask
    initial begin
        baseline=$test$plusargs("baseline");
        for(int count=1;count<=32;count++) if(selected(count)) begin
            run_case(baseline?count:count-1,0,0,0);
            run_case(baseline?count:count-1,32-count,1,0);
            // Reuse bank ownership and dispatcher state across consecutive END chunks.
            run_case(baseline?count:count-1,32-count,1,0,1);
            run_case(baseline?count:count-1,33-count,0,1);
            run_case(baseline?count:count-1,33-count,1,1);
        end
        for(int raw=baseline?33:32;raw<64;raw++) begin run_case(raw,0,0,1); run_case(raw,0,1,1); end
        if(baseline) begin run_case(0,0,0,1); run_case(0,0,1,1); end
        $display("T03_DISPATCHER_PASS"); $finish;
    end
endmodule
