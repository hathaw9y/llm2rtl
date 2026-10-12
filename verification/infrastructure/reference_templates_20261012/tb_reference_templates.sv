`timescale 1ns/1ps
module tb_reference_templates;
    import reference_test_config_pkg::*;
    parameter int READ_LATENCY = 2;
    parameter bit ACK_FAILURE_CASE = 1'b0;
    logic aclk=0, aresetn=0, start=0;
    always #5 aclk=~aclk;
    logic idle, done, error;
    logic [7:0] error_code;
    logic cmd_en;
    logic [2:0] cmd_addr;
    logic [127:0] cmd_data;
    logic [127:0] program_words [0:7];
    logic [127:0] memory_pipe [0:READ_LATENCY-1];
    logic [1:0] issue_allow, core_done_allow, drain_allow, core_error, unclean_fault;
    logic bad_response;
    int checks=0, accepted [0:1], released=0, responses=0;
    logic [127:0] expected [0:1][0:3];
    logic [1:0] stalled_r;
    logic [1:0][127:0] stalled_word_r;
    logic [1:0] core_done_release_seen;
    reference_test_fabric #(.CMD_ADDR_WIDTH(3), .MAX_COMMANDS(8), .CMD_READ_LATENCY(READ_LATENCY)) dut (
        .aclk(aclk), .aresetn(aresetn), .start_i(start), .idle_o(idle), .done_o(done),
        .error_o(error), .error_code_o(error_code), .cmd_bram_enb(cmd_en),
        .cmd_bram_addrb(cmd_addr), .cmd_bram_doutb(cmd_data),
        .fixture_issue_allow(issue_allow), .fixture_core_done_allow(core_done_allow),
        .fixture_drain_allow(drain_allow), .fixture_core_error(core_error),
        .fixture_unclean_fault(unclean_fault), .fixture_bad_response(bad_response)
    );
    function automatic logic [127:0] pack_word(input int op, s0, s1, s2, s3, dst,
        input logic [PAYLOAD_WIDTH-1:0] payload);
        // Independent source-backed MSB-first pack; does not call DUT functions.
        pack_word = {4'(op), BANK_NUM_WIDTH'(s0), BANK_NUM_WIDTH'(s1), BANK_NUM_WIDTH'(s2),
            BANK_NUM_WIDTH'(s3), BANK_NUM_WIDTH'(dst), payload};
    endfunction
    task automatic check(input logic condition, input string message);
        checks++;
        if (condition !== 1'b1) $fatal(1, "CHECK %0d: %s", checks, message);
    endtask
    task automatic ticks(input int count);
        repeat(count) begin @(posedge aclk); #1; end
    endtask
    task automatic wait_count(input int e, input int target);
        int timeout_count;
        timeout_count=0;
        while (accepted[e] < target && timeout_count < 300) begin ticks(1); timeout_count++; end
        check(accepted[e] == target, "expected engine acceptance before timeout");
    endtask
    task automatic wait_error;
        int timeout_count;
        timeout_count=0;
        while (!error && timeout_count<300) begin ticks(1); timeout_count++; end
        check(error && !done, "expected error and no successful completion");
    endtask
    task automatic reset_all;
        @(negedge aclk); aresetn=0; start=0; issue_allow='0;
        core_done_allow='0; drain_allow='0; core_error='0; unclean_fault='0; bad_response=0;
        ticks(3);
        check(dut.wr_busy == '0 && dut.rd_busy == '0 && dut.engine_valid == '0, "coherent reset clears ownership and requests");
        @(negedge aclk); aresetn=1;
        ticks(1);
    endtask
    // Configured synchronous BRAM latency, including nondefault three-cycle test.
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            for(int p=0;p<READ_LATENCY;p++) memory_pipe[p] <= '0;
        end else begin
            if(cmd_en) memory_pipe[0] <= program_words[cmd_addr];
            for(int p=1;p<READ_LATENCY;p++) memory_pipe[p] <= memory_pipe[p-1];
        end
    end
    assign cmd_data=memory_pipe[READ_LATENCY-1];
    always @(posedge aclk) begin
        if (!aresetn) begin
            accepted[0]=0; accepted[1]=0; released=0; responses=0;
            stalled_r='0; stalled_word_r='0; core_done_release_seen='0;
        end else begin
            for(int e=0;e<2;e++) begin
                if(stalled_r[e]) begin
                    check(dut.engine_valid[e], "offered request is not retracted during stall");
                    check({dut.engine_opcode[e],dut.engine_src[e][0],dut.engine_src[e][1],dut.engine_src[e][2],
                        dut.engine_src[e][3],dut.engine_dst[e],dut.engine_payload[e]} == stalled_word_r[e], "all header and opaque payload fields stable during stall");
                end
                stalled_r[e]=dut.engine_valid[e] && !dut.engine_ready[e];
                stalled_word_r[e]={dut.engine_opcode[e],dut.engine_src[e][0],dut.engine_src[e][1],dut.engine_src[e][2],
                    dut.engine_src[e][3],dut.engine_dst[e],dut.engine_payload[e]};
                if(dut.engine_valid[e] && dut.engine_ready[e]) begin
                    check(stalled_word_r[e] == expected[e][accepted[e]], "header SRC0..3/DST and opaque payload forwarded exactly");
                    check(dut.rd_busy[dut.engine_src[e][0]] && dut.wr_busy[dut.engine_dst[e]], "actual native ownership established before issue");
                    check(dut.rd_owner[dut.engine_src[e][0]] == ROLE_WIDTH'(2) &&
                        dut.wr_owner[dut.engine_dst[e]] == ROLE_WIDTH'(1), "directional role identity matches issue");
                    accepted[e]++;
                end
                if(dut.response_valid[e] && dut.response_ready[e] && !bad_response) begin
                    check(dut.response_command[e] == expected[e][accepted[e]-1], "engine latches full context rather than live input");
                    if(dut.response_clean[e] && !core_error[e]) begin
                        check(drain_allow[e], "response waits for final drain");
                        check(core_done_release_seen[e], "core done released after held start drops before response");
                        check(!dut.observed_core_start[e] && !dut.observed_core_done[e], "every response observes released core start and cleared done");
                    end
                    responses++;
                end
            end
            if(dut.g_engines[0].u_engine.state_r == 3'd2 && !dut.g_engines[0].u_engine.core_done_w)
                core_done_release_seen[0]=1;
            if(dut.g_engines[1].u_engine.state_r == 3'd2 && !dut.g_engines[1].u_engine.core_done_w)
                core_done_release_seen[1]=1;
            if(|dut.wr_release || |dut.rd_release) begin
                check(dut.wr_release == dut.wr_released && dut.rd_release == dut.rd_released, "release acceptance is real native ownership acknowledgement");
                released++;
            end
            if(done) check(dut.wr_busy=='0 && dut.rd_busy=='0 && dut.u_controller.pending_r=='0, "END waits for all engine and bank ownership drain");
        end
    end
    // Standalone unbound executor is fail-closed and holds rejection under stall.
    logic unbound_valid=0, unbound_ready, unbound_resp_valid, unbound_resp_ready=0;
    logic [127:0] unbound_resp_command;
    logic unbound_resp_error, unbound_resp_clean;
    logic [3:0][BANK_NUM_WIDTH-1:0] unbound_src;
    assign unbound_src='{BANK_NUM_WIDTH'(3),BANK_NUM_WIDTH'(2),BANK_NUM_WIDTH'(1),BANK_NUM_WIDTH'(0)};
    reference_unbound_executor unbound_executor (
        .aclk(aclk), .aresetn(aresetn), .s_ctrl_cmd_valid(unbound_valid), .s_ctrl_cmd_ready(unbound_ready),
        .s_ctrl_cmd_opcode(4'd1), .s_ctrl_cmd_src_bank(unbound_src), .s_ctrl_cmd_dst_bank(BANK_NUM_WIDTH'(1)),
        .s_ctrl_cmd_payload(PAYLOAD_WIDTH'(32'h12345678)), .m_ctrl_resp_valid(unbound_resp_valid),
        .m_ctrl_resp_ready(unbound_resp_ready), .m_ctrl_resp_command(unbound_resp_command),
        .m_ctrl_resp_error(unbound_resp_error), .m_ctrl_resp_clean(unbound_resp_clean), .m_ctrl_resp_error_code()
    );
    logic unbound_controller_start=0, unbound_controller_error;
    logic [7:0] unbound_controller_error_code;
    logic [1:0] unbound_controller_command_valid;
    reference_unbound_controller #(.ENGINE_NUM(2), .CMD_ADDR_WIDTH(3), .MAX_COMMANDS(8)) unbound_controller (
        .aclk(aclk), .aresetn(aresetn), .start_i(unbound_controller_start), .idle_o(), .done_o(),
        .error_o(unbound_controller_error), .error_code_o(unbound_controller_error_code),
        .current_pc(), .cmd_bram_enb(), .cmd_bram_addrb(), .cmd_bram_doutb(pack_word(1,0,1,2,3,1,'1)),
        .m_engine_cmd_valid(unbound_controller_command_valid), .m_engine_cmd_ready(2'b11),
        .m_engine_cmd_opcode(), .m_engine_cmd_src_bank(), .m_engine_cmd_dst_bank(), .m_engine_cmd_payload(),
        .s_engine_resp_valid(2'b00), .s_engine_resp_ready(), .s_engine_resp_command('0),
        .s_engine_resp_error('0), .s_engine_resp_clean('0),
        .bank_wr_acquire_valid(), .bank_rd_acquire_valid(), .bank_wr_acquire_port(), .bank_rd_acquire_port(),
        .bank_wr_release_valid(), .bank_rd_release_valid(), .bank_wr_release_port(), .bank_rd_release_port(),
        .bank_wr_busy('0), .bank_rd_busy('0), .bank_wr_owner_port('0), .bank_rd_owner_port('0),
        .bank_wr_acquire_accepted('0), .bank_rd_acquire_accepted('0),
        .bank_wr_release_accepted('0), .bank_rd_release_accepted('0), .bank_subsystem_error(1'b0)
    );
    initial begin
        for(int i=0;i<8;i++) program_words[i]='0;
        expected[0][0]=pack_word(1,0,5,6,7,1,PAYLOAD_WIDTH'(109'h123456789abcdef01234567));
        expected[0][1]=pack_word(1,0,3,2,1,1,PAYLOAD_WIDTH'(109'h456789abcdeffedcba9876));
        expected[1][0]=pack_word(2,2,7,5,6,3,PAYLOAD_WIDTH'(109'hf9876543210abcd1234567));
        reset_all();
        if(ACK_FAILURE_CASE) begin
            program_words[0]=expected[1][0];
            @(negedge aclk); start=1; issue_allow='1;
            wait_error(); ticks(12);
            check(dut.u_controller.state_r==4'd9 && error_code==8'h03 && dut.bank_error &&
                accepted[0]==0 && accepted[1]==0 && dut.wr_busy=='0 && dut.rd_busy=='0,
                "ineligible native capability denies acquire acknowledgement and blocks issue");
            $display("PASS reference templates context/ownership/stall/core-rearm/drain/END/error/reset checks=%0d", checks);
            $finish;
        end
        program_words[0]=expected[0][0]; program_words[1]=expected[1][0];
        program_words[2]=expected[0][1]; program_words[3]='0;
        @(negedge aclk); start=1;
        while(!dut.engine_valid[0]) ticks(1);
        ticks(8); check(accepted[0]==0 && dut.rd_busy[0] && dut.wr_busy[1], "acquired ownership retained during request stall");
        @(negedge aclk); issue_allow[0]=1;
        wait_count(0,1);
        while(!dut.engine_valid[1]) ticks(1);
        ticks(9);
        @(negedge aclk); issue_allow[1]=1;
        wait_count(1,1);
        check(dut.u_controller.pending_r==2'b11 && dut.rd_busy==4'b0101 && dut.wr_busy==4'b1010, "disjoint engines overlap with real split ownership");
        ticks(12); check(accepted[0]==1, "conflicting bank and same-engine command cannot issue early");
        @(negedge aclk); core_done_allow[1]=1;
        ticks(10); check(!dut.response_valid[1] && dut.wr_busy[3], "held core done and release do not bypass final drain");
        @(negedge aclk); drain_allow[1]=1;
        ticks(10); check(!dut.wr_busy[3] && !dut.rd_busy[2] && accepted[0]==1, "nonconflicting completion releases only its accepted bank roles");
        @(negedge aclk); core_done_allow[0]=1;
        ticks(10); check(!dut.response_valid[0] && dut.wr_busy[1], "first engine waits for final drain too");
        @(negedge aclk); drain_allow[0]=1;
        wait_count(0,2);
        begin int t; t=0; while(!done && t<300) begin ticks(1);t++;end end
        check(done && !error && responses==3 && released==3, "END completes after all three responses and accepted releases");
        ticks(4); check(done && accepted[0]==2, "done held and start does not retrigger");
        @(negedge aclk); start=0; ticks(2); check(idle && !done, "completion release rearms controller");

        reset_all(); program_words[0]=pack_word(15,0,1,2,3,1,'1);
        @(negedge aclk); start=1; wait_error(); ticks(8);
        check(error_code==8'h01 && dut.u_controller.state_r==4'd9 && accepted[0]==0 && accepted[1]==0 && dut.wr_busy=='0 && dut.rd_busy=='0, "unsupported opcode fails closed before acquire and reaches terminal failure");

        reset_all(); program_words[0]=expected[0][0]; program_words[1]='0;
        @(negedge aclk); issue_allow=2'b01; start=1; core_error[0]=1; core_done_allow[0]=1;
        wait_count(0,1); ticks(12);
        check(!error && dut.wr_busy[1], "clean core error still waits for drain before reporting");
        @(negedge aclk); drain_allow[0]=1; wait_error(); ticks(12);
        check(error_code==8'h04 && dut.u_controller.state_r==4'd9 && dut.wr_busy=='0 && dut.rd_busy=='0 && released==1, "clean error releases only after actual drain and acceptance and terminates");

        reset_all(); program_words[0]=expected[0][0]; program_words[1]='0;
        @(negedge aclk); issue_allow=2'b01; start=1;
        wait_count(0,1); @(negedge aclk); unclean_fault[0]=1;
        wait_error(); ticks(15);
        check(error_code==8'h03 && dut.wr_busy[1] && dut.rd_busy[0] && released==0,
            "unclean executor fault keeps ownership until coherent reset");

        reset_all(); program_words[0]=expected[0][0]; program_words[1]=expected[1][0]; program_words[2]='0;
        @(negedge aclk); issue_allow=2'b01; start=1; wait_count(0,1);
        while(!dut.engine_valid[1]) ticks(1);
        @(negedge aclk); bad_response=1; wait_error(); ticks(8);
        check(error_code==8'h03 && dut.wr_busy[1] && dut.rd_busy[0] && released==0,
            "unmatched completion cannot release banks or report success");
        check(dut.engine_valid[1] && accepted[1]==0, "hard fault preserves another engine's stalled valid and context");
        @(negedge aclk); issue_allow[1]=1; wait_count(1,1); ticks(5);
        check(dut.u_controller.state_r==4'd9 && dut.wr_busy==4'b1010 && dut.rd_busy==4'b0101,
            "after offered request accepted hard fault retains every reservation until reset");

        reset_all(); program_words[0]=expected[0][0];
        @(negedge aclk); start=1; while(!dut.engine_valid[0]) ticks(1);
        ticks(3); reset_all(); check(idle && accepted[0]==0 && !error, "reset while stalled restores reusable coherent state");

        @(negedge aclk); unbound_valid=1; ticks(1);
        @(negedge aclk); unbound_valid=0;
        ticks(5); check(unbound_resp_valid && unbound_resp_error && unbound_resp_clean &&
            !unbound_executor.core_start_w, "unbound executor rejects and never fakes core success");
        check(unbound_resp_command == pack_word(1,0,1,2,3,1,PAYLOAD_WIDTH'(32'h12345678)), "unbound rejection preserves full original command context");
        @(negedge aclk); unbound_resp_ready=1; ticks(2); check(unbound_ready && !unbound_resp_valid, "rejected request response released before reuse");
        @(negedge aclk); unbound_controller_start=1; ticks(15);
        check(unbound_controller_error && unbound_controller_error_code==8'h01 && unbound_controller_command_valid=='0,
            "unbound controller supports no operation beyond END");
        $display("PASS reference templates context/ownership/stall/core-rearm/drain/END/error/reset checks=%0d", checks);
        $finish;
    end
    initial begin #200000; $fatal(1,"testbench timeout"); end
endmodule
