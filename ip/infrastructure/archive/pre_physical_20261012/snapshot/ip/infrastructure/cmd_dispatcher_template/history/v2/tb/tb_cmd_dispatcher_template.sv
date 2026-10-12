`timescale 1ns/1ps

module tb_cmd_dispatcher_template;
    localparam integer AXI_ADDR_WIDTH = 32;
    localparam integer BTT_WIDTH = 23;
    localparam integer BANK_NUM = 16;
    localparam integer BANK_NUM_WIDTH = 4;
    localparam integer TAG_WIDTH = 4;
    localparam integer BANK_ADDR_WIDTH = 32;
    localparam integer CMD_ADDR_WIDTH = 10;
    localparam integer CMD_READ_LATENCY = 2;
    localparam integer CMD_DATA_WIDTH = 128;
    localparam integer MAX_COMMANDS = 1024;
    localparam integer OPCODE_WIDTH = 4;
    localparam integer PORT_ROLE_WIDTH = 3;

    localparam integer OPCODE_LSB = CMD_DATA_WIDTH - OPCODE_WIDTH;
    localparam integer OPERAND0_LSB = OPCODE_LSB - BANK_NUM_WIDTH;
    localparam integer OPERAND1_LSB = OPERAND0_LSB - BANK_NUM_WIDTH;
    localparam integer OPERAND2_LSB = OPERAND1_LSB - BANK_NUM_WIDTH;
    localparam integer LOCAL_OFFSET_LSB = OPERAND2_LSB - BANK_ADDR_WIDTH;
    localparam integer BYTE_COUNT_LSB = LOCAL_OFFSET_LSB - BTT_WIDTH;
    localparam integer AXI_ADDRESS_LSB = BYTE_COUNT_LSB - AXI_ADDR_WIDTH;

    localparam logic [OPCODE_WIDTH-1:0] OP_END = 0;
    localparam logic [OPCODE_WIDTH-1:0] OP_MM2S = 1;
    localparam logic [OPCODE_WIDTH-1:0] OP_S2MM = 2;

    logic aclk = 1'b0;
    logic aresetn = 1'b0;
    logic cmd_dispatcher_start = 1'b0;
    logic cmd_dispatcher_busy;
    logic cmd_dispatcher_done;
    logic cmd_dispatcher_error;
    logic [7:0] cmd_dispatcher_error_code;
    logic [CMD_ADDR_WIDTH-1:0] current_pc;

    logic cmd_enb;
    logic [CMD_ADDR_WIDTH-1:0] cmd_addrb;
    logic [CMD_DATA_WIDTH-1:0] cmd_doutb;

    logic m_ctrl_mm2s_cmd_valid;
    logic m_ctrl_mm2s_cmd_ready = 1'b0;
    logic [AXI_ADDR_WIDTH-1:0] m_ctrl_mm2s_cmd_addr;
    logic [BTT_WIDTH-1:0] m_ctrl_mm2s_cmd_btt;
    logic [BANK_ADDR_WIDTH-1:0] m_ctrl_mm2s_cmd_offset;
    logic [BANK_NUM_WIDTH-1:0] m_ctrl_mm2s_cmd_bank;
    logic [TAG_WIDTH-1:0] m_ctrl_mm2s_cmd_tag;
    logic s_ctrl_mm2s_sts_valid = 1'b0;
    logic m_ctrl_mm2s_sts_ready;
    logic [TAG_WIDTH-1:0] s_ctrl_mm2s_sts_tag = '0;
    logic s_ctrl_mm2s_sts_error = 1'b0;

    logic m_ctrl_s2mm_cmd_valid;
    logic m_ctrl_s2mm_cmd_ready = 1'b0;
    logic [AXI_ADDR_WIDTH-1:0] m_ctrl_s2mm_cmd_addr;
    logic [BTT_WIDTH-1:0] m_ctrl_s2mm_cmd_btt;
    logic [BANK_ADDR_WIDTH-1:0] m_ctrl_s2mm_cmd_offset;
    logic [BANK_NUM_WIDTH-1:0] m_ctrl_s2mm_cmd_bank;
    logic [TAG_WIDTH-1:0] m_ctrl_s2mm_cmd_tag;
    logic s_ctrl_s2mm_sts_valid = 1'b0;
    logic m_ctrl_s2mm_sts_ready;
    logic [TAG_WIDTH-1:0] s_ctrl_s2mm_sts_tag = '0;
    logic s_ctrl_s2mm_sts_error = 1'b0;

    logic [0:BANK_NUM-1] bank_acquire_valid;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_acquire_port;
    logic [0:BANK_NUM-1] bank_release_valid;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_release_port;
    logic [0:BANK_NUM-1] bank_busy;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_owner_port;
    logic [0:BANK_NUM-1] bank_owned_r;
    logic [0:BANK_NUM-1] bank_hold_r;

    logic [CMD_DATA_WIDTH-1:0] command_mem [0:MAX_COMMANDS-1];
    logic [CMD_DATA_WIDTH-1:0] bram_pipe_r [0:CMD_READ_LATENCY-1];
    integer fetch_count = 0;
    integer failures = 0;
    integer model_idx;
    integer pipe_idx;
    integer i;

    cmd_dispatcher_template dut (.*);

    always #2.5 aclk = ~aclk;
    assign bank_busy = bank_owned_r | bank_hold_r;
    assign cmd_doutb = bram_pipe_r[CMD_READ_LATENCY-1];

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            bank_owned_r <= '0;
            bank_owner_port <= '0;
            fetch_count <= 0;
            for (pipe_idx = 0; pipe_idx < CMD_READ_LATENCY; pipe_idx = pipe_idx + 1) begin
                bram_pipe_r[pipe_idx] <= '0;
            end
        end else begin
            if (cmd_enb) begin
                bram_pipe_r[0] <= command_mem[cmd_addrb];
                fetch_count <= fetch_count + 1;
            end
            for (pipe_idx = 1; pipe_idx < CMD_READ_LATENCY; pipe_idx = pipe_idx + 1) begin
                bram_pipe_r[pipe_idx] <= bram_pipe_r[pipe_idx-1];
            end
            for (model_idx = 0; model_idx < BANK_NUM; model_idx = model_idx + 1) begin
                if (bank_release_valid[model_idx]) begin
                    bank_owned_r[model_idx] <= 1'b0;
                    bank_owner_port[model_idx] <= '0;
                end else if (bank_acquire_valid[model_idx]) begin
                    bank_owned_r[model_idx] <= 1'b1;
                    bank_owner_port[model_idx] <= bank_acquire_port[model_idx];
                end
            end
        end
    end

    function automatic logic [CMD_DATA_WIDTH-1:0] make_command(
        input logic [OPCODE_WIDTH-1:0] opcode,
        input logic [BANK_NUM_WIDTH-1:0] operand0,
        input logic [BANK_NUM_WIDTH-1:0] operand1,
        input logic [BANK_NUM_WIDTH-1:0] operand2,
        input logic [BANK_ADDR_WIDTH-1:0] local_offset,
        input logic [BTT_WIDTH-1:0] byte_count,
        input logic [AXI_ADDR_WIDTH-1:0] axi_address,
        input logic [AXI_ADDRESS_LSB-1:0] reserved);
        logic [CMD_DATA_WIDTH-1:0] value;
        begin
            value = '0;
            value[CMD_DATA_WIDTH-1 -: OPCODE_WIDTH] = opcode;
            value[OPCODE_LSB-1 -: BANK_NUM_WIDTH] = operand0;
            value[OPERAND0_LSB-1 -: BANK_NUM_WIDTH] = operand1;
            value[OPERAND1_LSB-1 -: BANK_NUM_WIDTH] = operand2;
            value[OPERAND2_LSB-1 -: BANK_ADDR_WIDTH] = local_offset;
            value[LOCAL_OFFSET_LSB-1 -: BTT_WIDTH] = byte_count;
            value[BYTE_COUNT_LSB-1 -: AXI_ADDR_WIDTH] = axi_address;
            value[AXI_ADDRESS_LSB-1:0] = reserved;
            make_command = value;
        end
    endfunction

    task automatic clear_commands;
        integer j;
        begin
            for (j = 0; j < MAX_COMMANDS; j = j + 1) begin
                command_mem[j] = '0;
            end
        end
    endtask

    task automatic reset_dut;
        begin
            @(negedge aclk);
            aresetn = 1'b0;
            cmd_dispatcher_start = 1'b0;
            m_ctrl_mm2s_cmd_ready = 1'b0;
            m_ctrl_s2mm_cmd_ready = 1'b0;
            s_ctrl_mm2s_sts_valid = 1'b0;
            s_ctrl_mm2s_sts_error = 1'b0;
            s_ctrl_s2mm_sts_valid = 1'b0;
            s_ctrl_s2mm_sts_error = 1'b0;
            bank_hold_r = '0;
            repeat (2) @(posedge aclk);
            @(negedge aclk);
            aresetn = 1'b1;
            @(posedge aclk);
            if (cmd_dispatcher_busy || cmd_dispatcher_done || cmd_dispatcher_error ||
                (bank_acquire_valid != '0) || (bank_acquire_port != '0) ||
                (bank_release_valid != '0) || (bank_release_port != '0) ||
                (dut.pending_mm2s_r != '0) || (dut.pending_s2mm_r != '0)) begin
                $error("reset did not clear dispatcher state");
                failures = failures + 1;
            end
            if (!m_ctrl_mm2s_sts_ready || !m_ctrl_s2mm_sts_ready) begin
                $error("status ready must be asserted out of reset");
                failures = failures + 1;
            end
        end
    endtask

    task automatic launch;
        begin
            @(negedge aclk);
            cmd_dispatcher_start = 1'b1;
            @(negedge aclk);
            cmd_dispatcher_start = 1'b0;
        end
    endtask

    task automatic wait_state(input logic [3:0] expected_state);
        integer timeout_count;
        begin
            timeout_count = 0;
            while ((dut.state_r !== expected_state) && (timeout_count < 300)) begin
                @(posedge aclk);
                timeout_count = timeout_count + 1;
            end
            if (dut.state_r !== expected_state) begin
                $error("state timeout expected=%0d actual=%0d", expected_state, dut.state_r);
                failures = failures + 1;
            end
        end
    endtask

    task automatic accept_mm2s(
        input logic [CMD_DATA_WIDTH-1:0] command,
        input integer stall_cycles);
        integer timeout_count;
        integer stall_idx;
        logic [BANK_NUM_WIDTH-1:0] bank;
        begin
            bank = command[OPCODE_LSB-1 -: BANK_NUM_WIDTH];
            m_ctrl_mm2s_cmd_ready = 1'b0;
            timeout_count = 0;
            while (!m_ctrl_mm2s_cmd_valid && (timeout_count < 300)) begin
                @(posedge aclk);
                timeout_count = timeout_count + 1;
            end
            if (!m_ctrl_mm2s_cmd_valid ||
                (m_ctrl_mm2s_cmd_addr !== command[BYTE_COUNT_LSB-1 -: AXI_ADDR_WIDTH]) ||
                (m_ctrl_mm2s_cmd_btt !== command[LOCAL_OFFSET_LSB-1 -: BTT_WIDTH]) ||
                (m_ctrl_mm2s_cmd_offset !== command[OPERAND2_LSB-1 -: BANK_ADDR_WIDTH]) ||
                (m_ctrl_mm2s_cmd_bank !== bank) ||
                (m_ctrl_mm2s_cmd_tag !== bank)) begin
                $error("MM2S typed payload mismatch");
                failures = failures + 1;
            end
            for (stall_idx = 0; stall_idx < stall_cycles; stall_idx = stall_idx + 1) begin
                @(posedge aclk);
                if (!m_ctrl_mm2s_cmd_valid ||
                    (m_ctrl_mm2s_cmd_addr !== command[BYTE_COUNT_LSB-1 -: AXI_ADDR_WIDTH]) ||
                    (m_ctrl_mm2s_cmd_btt !== command[LOCAL_OFFSET_LSB-1 -: BTT_WIDTH]) ||
                    (m_ctrl_mm2s_cmd_offset !== command[OPERAND2_LSB-1 -: BANK_ADDR_WIDTH]) ||
                    (m_ctrl_mm2s_cmd_bank !== bank) ||
                    (m_ctrl_mm2s_cmd_tag !== bank)) begin
                    $error("MM2S valid or payload changed under backpressure");
                    failures = failures + 1;
                end
            end
            @(negedge aclk);
            m_ctrl_mm2s_cmd_ready = 1'b1;
            @(posedge aclk);
            if (!bank_acquire_valid[bank] || (bank_acquire_port[bank] !== 1)) begin
                $error("MM2S acquire missing bank=%0d", bank);
                failures = failures + 1;
            end
            @(negedge aclk);
            m_ctrl_mm2s_cmd_ready = 1'b0;
        end
    endtask

    task automatic accept_s2mm(
        input logic [CMD_DATA_WIDTH-1:0] command,
        input integer stall_cycles);
        integer timeout_count;
        integer stall_idx;
        logic [BANK_NUM_WIDTH-1:0] bank;
        begin
            bank = command[OPCODE_LSB-1 -: BANK_NUM_WIDTH];
            m_ctrl_s2mm_cmd_ready = 1'b0;
            timeout_count = 0;
            while (!m_ctrl_s2mm_cmd_valid && (timeout_count < 300)) begin
                @(posedge aclk);
                timeout_count = timeout_count + 1;
            end
            if (!m_ctrl_s2mm_cmd_valid ||
                (m_ctrl_s2mm_cmd_addr !== command[BYTE_COUNT_LSB-1 -: AXI_ADDR_WIDTH]) ||
                (m_ctrl_s2mm_cmd_btt !== command[LOCAL_OFFSET_LSB-1 -: BTT_WIDTH]) ||
                (m_ctrl_s2mm_cmd_offset !== command[OPERAND2_LSB-1 -: BANK_ADDR_WIDTH]) ||
                (m_ctrl_s2mm_cmd_bank !== bank) ||
                (m_ctrl_s2mm_cmd_tag !== bank)) begin
                $error("S2MM typed payload mismatch");
                failures = failures + 1;
            end
            for (stall_idx = 0; stall_idx < stall_cycles; stall_idx = stall_idx + 1) begin
                @(posedge aclk);
                if (!m_ctrl_s2mm_cmd_valid ||
                    (m_ctrl_s2mm_cmd_addr !== command[BYTE_COUNT_LSB-1 -: AXI_ADDR_WIDTH]) ||
                    (m_ctrl_s2mm_cmd_btt !== command[LOCAL_OFFSET_LSB-1 -: BTT_WIDTH]) ||
                    (m_ctrl_s2mm_cmd_offset !== command[OPERAND2_LSB-1 -: BANK_ADDR_WIDTH]) ||
                    (m_ctrl_s2mm_cmd_bank !== bank) ||
                    (m_ctrl_s2mm_cmd_tag !== bank)) begin
                    $error("S2MM valid or payload changed under backpressure");
                    failures = failures + 1;
                end
            end
            @(negedge aclk);
            m_ctrl_s2mm_cmd_ready = 1'b1;
            @(posedge aclk);
            if (!bank_acquire_valid[bank] || (bank_acquire_port[bank] !== 2)) begin
                $error("S2MM acquire missing bank=%0d", bank);
                failures = failures + 1;
            end
            @(negedge aclk);
            m_ctrl_s2mm_cmd_ready = 1'b0;
        end
    endtask

    task automatic complete_mm2s(
        input logic [TAG_WIDTH-1:0] tag,
        input logic status_error,
        input logic expect_release);
        begin
            @(negedge aclk);
            s_ctrl_mm2s_sts_tag = tag;
            s_ctrl_mm2s_sts_error = status_error;
            s_ctrl_mm2s_sts_valid = 1'b1;
            @(posedge aclk);
            if (!m_ctrl_mm2s_sts_ready ||
                (bank_release_valid[tag] !== expect_release) ||
                (expect_release && (bank_release_port[tag] !== 1))) begin
                $error("MM2S release mismatch tag=%0d", tag);
                failures = failures + 1;
            end
            @(negedge aclk);
            s_ctrl_mm2s_sts_valid = 1'b0;
            s_ctrl_mm2s_sts_error = 1'b0;
        end
    endtask

    task automatic complete_s2mm(
        input logic [TAG_WIDTH-1:0] tag,
        input logic status_error,
        input logic expect_release);
        begin
            @(negedge aclk);
            s_ctrl_s2mm_sts_tag = tag;
            s_ctrl_s2mm_sts_error = status_error;
            s_ctrl_s2mm_sts_valid = 1'b1;
            @(posedge aclk);
            if (!m_ctrl_s2mm_sts_ready ||
                (bank_release_valid[tag] !== expect_release) ||
                (expect_release && (bank_release_port[tag] !== 2))) begin
                $error("S2MM release mismatch tag=%0d", tag);
                failures = failures + 1;
            end
            @(negedge aclk);
            s_ctrl_s2mm_sts_valid = 1'b0;
            s_ctrl_s2mm_sts_error = 1'b0;
        end
    endtask

    task automatic expect_done;
        integer timeout_count;
        begin
            timeout_count = 0;
            while (!cmd_dispatcher_done && (timeout_count < 500)) begin
                @(posedge aclk);
                timeout_count = timeout_count + 1;
            end
            if (!cmd_dispatcher_done) begin
                $error("DONE timeout");
                failures = failures + 1;
            end
        end
    endtask

    task automatic expect_error(input logic [7:0] expected_code);
        integer timeout_count;
        begin
            timeout_count = 0;
            while (!cmd_dispatcher_error && (timeout_count < 500)) begin
                @(posedge aclk);
                timeout_count = timeout_count + 1;
            end
            if (!cmd_dispatcher_error ||
                (cmd_dispatcher_error_code !== expected_code)) begin
                $error("ERROR mismatch expected=%02x actual=%02x",
                       expected_code, cmd_dispatcher_error_code);
                failures = failures + 1;
            end
        end
    endtask

    initial begin : verification
        logic [CMD_DATA_WIDTH-1:0] c0;
        logic [CMD_DATA_WIDTH-1:0] c1;
        integer fetch_before;

        bank_hold_r = '0;
        clear_commands();
        reset_dut();

        $display("CASE marker_and_parameter_contract");
        if ((dut.USER_MARKER_COUNT != 14) || !dut.PARAMETERS_LEGAL ||
            (dut.AXI_ADDRESS_LSB != 25)) begin
            $error("marker sentinel, parameter legality, or derived field layout failed");
            failures = failures + 1;
        end

        $display("CASE bank0_and_two_distinct_mm2s_outstanding");
        c0 = make_command(OP_MM2S, 0, 4'ha, 4'hb, 32'h01020304,
                          23'h12345, 32'h80001000, 25'h1555555);
        c1 = make_command(OP_MM2S, 1, 4'hc, 4'hd, 32'h11121314,
                          23'h23456, 32'h80002000, 25'h0aaaaaa);
        command_mem[0] = c0;
        command_mem[1] = c1;
        command_mem[2] = '0;
        launch();
        accept_mm2s(c0, 3);
        if (cmd_addrb !== 1) begin
            $error("command BRAM address did not advance independently of data bank zero");
            failures = failures + 1;
        end
        accept_mm2s(c1, 2);
        wait_state(4);
        if (!bank_busy[0] || !bank_busy[1]) begin
            $error("distinct MM2S commands were not concurrently outstanding");
            failures = failures + 1;
        end
        complete_mm2s(0, 1'b0, 1'b1);
        complete_mm2s(1, 1'b0, 1'b1);
        expect_done();

        $display("CASE bank0_reuse");
        command_mem[0] = c0;
        command_mem[1] = '0;
        launch();
        accept_mm2s(c0, 0);
        complete_mm2s(0, 1'b0, 1'b1);
        expect_done();

        $display("CASE mixed_mm2s_s2mm_outstanding_and_backpressure");
        reset_dut();
        c0 = make_command(OP_MM2S, 2, 4'h1, 4'h2, 32'h22220000,
                          23'h34567, 32'h90002000, 25'h1234567);
        c1 = make_command(OP_S2MM, 3, 4'h3, 4'h4, 32'h33330000,
                          23'h45678, 32'ha0003000, 25'h0765432);
        command_mem[0] = c0;
        command_mem[1] = c1;
        command_mem[2] = '0;
        launch();
        accept_mm2s(c0, 5);
        accept_s2mm(c1, 5);
        wait_state(4);
        if (!dut.pending_mm2s_r[2] || !dut.pending_s2mm_r[3]) begin
            $error("mixed executor pending identities missing");
            failures = failures + 1;
        end
        @(negedge aclk);
        s_ctrl_mm2s_sts_tag = 2;
        s_ctrl_mm2s_sts_valid = 1'b1;
        s_ctrl_s2mm_sts_tag = 3;
        s_ctrl_s2mm_sts_valid = 1'b1;
        @(posedge aclk);
        if (!bank_release_valid[2] || (bank_release_port[2] != 1) ||
            !bank_release_valid[3] || (bank_release_port[3] != 2)) begin
            $error("simultaneous independent releases missing");
            failures = failures + 1;
        end
        @(negedge aclk);
        s_ctrl_mm2s_sts_valid = 1'b0;
        s_ctrl_s2mm_sts_valid = 1'b0;
        expect_done();

        $display("CASE same_bank_stall_no_lookahead_and_release_during_stall");
        reset_dut();
        c0 = make_command(OP_MM2S, 4, 0, 0, 32'h40, 23'd64, 32'h1000, '0);
        c1 = make_command(OP_S2MM, 4, 0, 0, 32'h80, 23'd64, 32'h2000, '0);
        command_mem[0] = c0;
        command_mem[1] = c1;
        command_mem[2] = '0;
        launch();
        accept_mm2s(c0, 0);
        wait_state(2);
        fetch_before = fetch_count;
        repeat (8) @(posedge aclk);
        if (m_ctrl_s2mm_cmd_valid || (current_pc !== 1) ||
            (fetch_count !== fetch_before)) begin
            $error("same-bank stall looked ahead or issued early");
            failures = failures + 1;
        end
        complete_mm2s(4, 1'b0, 1'b1);
        accept_s2mm(c1, 0);
        wait_state(4);
        complete_s2mm(4, 1'b0, 1'b1);
        expect_done();

        $display("CASE completion_during_later_fetch");
        reset_dut();
        c0 = make_command(OP_MM2S, 5, 0, 0, 32'h50, 23'd64, 32'h5000, '0);
        c1 = make_command(OP_MM2S, 6, 0, 0, 32'h60, 23'd64, 32'h6000, '0);
        command_mem[0] = c0;
        command_mem[1] = c1;
        command_mem[2] = '0;
        launch();
        accept_mm2s(c0, 0);
        wait_state(1);
        complete_mm2s(5, 1'b0, 1'b1);
        accept_mm2s(c1, 0);
        wait_state(4);
        complete_mm2s(6, 1'b0, 1'b1);
        expect_done();

        $display("CASE spurious_wrong_type_and_mismatched_status_no_release");
        reset_dut();
        c0 = make_command(OP_MM2S, 7, 0, 0, 0, 23'd64, 32'h7000, '0);
        command_mem[0] = c0;
        command_mem[1] = '0;
        launch();
        accept_mm2s(c0, 0);
        wait_state(4);
        complete_s2mm(7, 1'b0, 1'b0);
        if (!bank_busy[7]) begin
            $error("wrong-type status released MM2S bank");
            failures = failures + 1;
        end
        complete_mm2s(14, 1'b0, 1'b0);
        if (!bank_busy[7]) begin
            $error("mismatched status released pending bank");
            failures = failures + 1;
        end
        complete_mm2s(7, 1'b0, 1'b1);
        expect_error(8'h03);

        $display("CASE executor_error_releases_then_drains");
        reset_dut();
        c0 = make_command(OP_S2MM, 8, 0, 0, 0, 23'd64, 32'h8000, '0);
        command_mem[0] = c0;
        command_mem[1] = '0;
        launch();
        accept_s2mm(c0, 0);
        wait_state(4);
        complete_s2mm(8, 1'b1, 1'b1);
        expect_error(8'h04);

        $display("CASE end_waits_external_busy");
        reset_dut();
        c0 = make_command(OP_MM2S, 9, 0, 0, 0, 23'd64, 32'h9000, '0);
        command_mem[0] = c0;
        command_mem[1] = '0;
        launch();
        accept_mm2s(c0, 0);
        bank_hold_r[9] = 1'b1;
        wait_state(4);
        complete_mm2s(9, 1'b0, 1'b1);
        repeat (6) @(posedge aclk);
        if (cmd_dispatcher_done) begin
            $error("END ignored external bank busy");
            failures = failures + 1;
        end
        @(negedge aclk);
        bank_hold_r[9] = 1'b0;
        expect_done();

        $display("CASE illegal_opcode_and_zero_byte_count");
        reset_dut();
        command_mem[0] = make_command(4'd3, 0, 0, 0, 0, 23'd64, 0, '0);
        launch();
        expect_error(8'h01);
        reset_dut();
        command_mem[0] = make_command(OP_MM2S, 0, 0, 0, 0, '0, 0, '0);
        launch();
        expect_error(8'h02);

        $display("CASE reset_recovery_fetch_issue_and_drain");
        reset_dut();
        command_mem[0] = make_command(OP_MM2S, 10, 0, 0, 0, 23'd64, 0, '0);
        command_mem[1] = '0;
        launch();
        wait_state(1);
        reset_dut();
        launch();
        wait_state(3);
        reset_dut();
        launch();
        accept_mm2s(command_mem[0], 0);
        wait_state(4);
        reset_dut();
        if ((bank_busy != '0) || (bank_acquire_valid != '0) ||
            (bank_release_valid != '0)) begin
            $error("reset recovery left ownership or pulses");
            failures = failures + 1;
        end

        $display("CASE missing_end_at_max_commands");
        reset_dut();
        for (i = 0; i < MAX_COMMANDS; i = i + 1) begin
            command_mem[i] = make_command(OP_MM2S, i % BANK_NUM, 0, 0,
                                          i, 23'd64, 32'hb0000000 + i, i);
        end
        launch();
        for (i = 0; i < MAX_COMMANDS; i = i + 1) begin
            c0 = make_command(OP_MM2S, i % BANK_NUM, 0, 0,
                              i, 23'd64, 32'hb0000000 + i, i);
            accept_mm2s(c0, 0);
            complete_mm2s(i % BANK_NUM, 1'b0, 1'b1);
        end
        expect_error(8'h05);
        if (current_pc !== (MAX_COMMANDS-1)) begin
            $error("missing-END terminal PC mismatch");
            failures = failures + 1;
        end

        if (failures == 0) begin
            $display("PASS: cmd_dispatcher_template fixed infrastructure verification");
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d cmd_dispatcher_template checks failed", failures);
        end
    end

    initial begin
        #10000000;
        $fatal(1, "FAIL: global timeout");
    end

endmodule
