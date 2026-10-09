`timescale 1ns/1ps

module qwen_dispatcher #(
    parameter integer AXI_ADDR_WIDTH    = 32,
    parameter integer BTT_WIDTH         = 23,
    parameter integer BANK_NUM          = 16,
    parameter integer BANK_NUM_WIDTH    = 4,
    parameter integer TAG_WIDTH         = 4,
    parameter integer BANK_ADDR_WIDTH   = 32,
    parameter integer CMD_ADDR_WIDTH    = 10,
    parameter integer CMD_READ_LATENCY  = 2,
    parameter integer CMD_DATA_WIDTH    = 128,
    parameter integer MAX_COMMANDS      = 1024,
    parameter integer OPCODE_WIDTH      = 4,
    parameter integer PORT_ROLE_WIDTH   = 3
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic cmd_dispatcher_start,
    output logic cmd_dispatcher_busy,
    output logic cmd_dispatcher_done,
    output logic cmd_dispatcher_error,
    output logic [7:0] cmd_dispatcher_error_code,
    output logic [CMD_ADDR_WIDTH-1:0] current_pc,

    output logic cmd_enb,
    output logic [CMD_ADDR_WIDTH-1:0] cmd_addrb,
    input  logic [CMD_DATA_WIDTH-1:0] cmd_doutb,

    output logic m_ctrl_mm2s_cmd_valid,
    input  logic m_ctrl_mm2s_cmd_ready,
    output logic [AXI_ADDR_WIDTH-1:0] m_ctrl_mm2s_cmd_addr,
    output logic [BTT_WIDTH-1:0] m_ctrl_mm2s_cmd_btt,
    output logic [BANK_ADDR_WIDTH-1:0] m_ctrl_mm2s_cmd_offset,
    output logic [BANK_NUM_WIDTH-1:0] m_ctrl_mm2s_cmd_bank,
    output logic [TAG_WIDTH-1:0] m_ctrl_mm2s_cmd_tag,
    input  logic s_ctrl_mm2s_sts_valid,
    output logic m_ctrl_mm2s_sts_ready,
    input  logic [TAG_WIDTH-1:0] s_ctrl_mm2s_sts_tag,
    input  logic s_ctrl_mm2s_sts_error,

    output logic m_ctrl_s2mm_cmd_valid,
    input  logic m_ctrl_s2mm_cmd_ready,
    output logic [AXI_ADDR_WIDTH-1:0] m_ctrl_s2mm_cmd_addr,
    output logic [BTT_WIDTH-1:0] m_ctrl_s2mm_cmd_btt,
    output logic [BANK_ADDR_WIDTH-1:0] m_ctrl_s2mm_cmd_offset,
    output logic [BANK_NUM_WIDTH-1:0] m_ctrl_s2mm_cmd_bank,
    output logic [TAG_WIDTH-1:0] m_ctrl_s2mm_cmd_tag,
    input  logic s_ctrl_s2mm_sts_valid,
    output logic m_ctrl_s2mm_sts_ready,
    input  logic [TAG_WIDTH-1:0] s_ctrl_s2mm_sts_tag,
    input  logic s_ctrl_s2mm_sts_error,

    /* verilator lint_off LITENDIAN */
    output logic [0:BANK_NUM-1] bank_acquire_valid,
    output logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_acquire_port,
    output logic [0:BANK_NUM-1] bank_release_valid,
    output logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_release_port,
    input  logic [0:BANK_NUM-1] bank_busy,
    input  logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_owner_port
    /* verilator lint_on LITENDIAN */

    // USER_PORTS_BEGIN
    ,output logic [4:0] exec_cmd_valid
    ,input logic [4:0] exec_cmd_ready
    ,output logic [255:0] exec_command
    ,output logic [9:0] exec_cmd_id
    ,input logic [4:0] exec_rsp_valid
    ,output logic [4:0] exec_rsp_ready
    ,input logic [4:0][9:0] exec_rsp_id
    ,input logic [4:0] exec_rsp_error
    ,input logic descriptor_command_legal
    ,input logic descriptor_bank_eligible
    ,output logic [4:0] exec_commit_valid,exec_commit_error
    ,output logic [4:0][255:0] exec_commit_command
    // USER_PORTS_END
);

    // USER_PARAMETERS_BEGIN
    // Add design-specific executor parameters here.
    // USER_PARAMETERS_END

    localparam integer REQUIRED_CMD_WIDTH = OPCODE_WIDTH +
                                            (3 * BANK_NUM_WIDTH) +
                                            BANK_ADDR_WIDTH + BTT_WIDTH +
                                            AXI_ADDR_WIDTH;
    localparam integer FETCH_COUNT_WIDTH =
        (CMD_READ_LATENCY < 2) ? 1 : $clog2(CMD_READ_LATENCY + 1);
    localparam integer REQUIRED_BANK_NUM_WIDTH =
        (BANK_NUM <= 1) ? 1 : $clog2(BANK_NUM);
    localparam integer REQUIRED_CMD_ADDR_WIDTH =
        (MAX_COMMANDS <= 1) ? 1 : $clog2(MAX_COMMANDS);
    localparam logic [FETCH_COUNT_WIDTH-1:0] FETCH_LATENCY_COUNT =
        FETCH_COUNT_WIDTH'(CMD_READ_LATENCY);
    localparam logic [CMD_ADDR_WIDTH-1:0] LAST_PC =
        CMD_ADDR_WIDTH'(MAX_COMMANDS - 1);
    localparam logic [BANK_NUM_WIDTH:0] BANK_NUM_LIMIT =
        (BANK_NUM_WIDTH + 1)'(BANK_NUM);
    localparam logic [TAG_WIDTH:0] TAG_BANK_NUM_LIMIT =
        (TAG_WIDTH + 1)'(BANK_NUM);
    localparam logic PARAMETERS_LEGAL =
        (BANK_NUM >= 1) &&
        (BANK_NUM_WIDTH >= REQUIRED_BANK_NUM_WIDTH) &&
        (TAG_WIDTH >= BANK_NUM_WIDTH) &&
        (CMD_READ_LATENCY >= 1) &&
        (MAX_COMMANDS >= 1) &&
        (CMD_ADDR_WIDTH >= REQUIRED_CMD_ADDR_WIDTH) &&
        (CMD_DATA_WIDTH >= REQUIRED_CMD_WIDTH) &&
        (PORT_ROLE_WIDTH >= 3) &&
        (OPCODE_WIDTH >= 2);

    localparam integer OPCODE_LSB = CMD_DATA_WIDTH - OPCODE_WIDTH;
    localparam integer OPERAND0_LSB = OPCODE_LSB - BANK_NUM_WIDTH;
    localparam integer OPERAND1_LSB = OPERAND0_LSB - BANK_NUM_WIDTH;
    localparam integer OPERAND2_LSB = OPERAND1_LSB - BANK_NUM_WIDTH;
    localparam integer LOCAL_OFFSET_LSB = OPERAND2_LSB - BANK_ADDR_WIDTH;
    localparam integer BYTE_COUNT_LSB = LOCAL_OFFSET_LSB - BTT_WIDTH;
    localparam integer AXI_ADDRESS_LSB = BYTE_COUNT_LSB - AXI_ADDR_WIDTH;

    localparam logic [OPCODE_WIDTH-1:0] OP_END  = 0;
    localparam logic [OPCODE_WIDTH-1:0] OP_MM2S = 1;
    localparam logic [OPCODE_WIDTH-1:0] OP_S2MM = 2;
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_MM2S_ARBITER = 1;
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_S2MM_ARBITER = 2;

    // USER_OPCODES_BEGIN
    // Add design-specific opcode constants here. Values 0, 1 and 2 are reserved.
    // USER_OPCODES_END

    localparam logic [7:0] ERR_NONE        = 8'h00;
    localparam logic [7:0] ERR_OPCODE      = 8'h01;
    localparam logic [7:0] ERR_OPERAND     = 8'h02;
    localparam logic [7:0] ERR_RESPONSE    = 8'h03;
    localparam logic [7:0] ERR_EXECUTOR    = 8'h04;
    localparam logic [7:0] ERR_MISSING_END = 8'h05;
    localparam logic [7:0] ERR_PARAMETER   = 8'h06;

    typedef enum logic [3:0] {
        IDLE,
        FETCH,
        CHECK_COMMAND,
        ISSUE_COMMAND,
        END_DRAIN,
        ERROR_DRAIN,
        DONE_STATE,
        ERROR_STATE
    } state_t;

    state_t state_r;
    logic [CMD_ADDR_WIDTH-1:0] pc_r;
    logic [FETCH_COUNT_WIDTH-1:0] fetch_count_r;
    /* verilator lint_off UNUSED */
    logic [CMD_DATA_WIDTH-1:0] command_r;
    /* verilator lint_on UNUSED */
    logic [7:0] error_code_r;

    /* verilator lint_off LITENDIAN */
    logic [0:BANK_NUM-1] pending_mm2s_r;
    logic [0:BANK_NUM-1] pending_s2mm_r;
    /* verilator lint_on LITENDIAN */

    logic [OPCODE_WIDTH-1:0] opcode_w;
    logic [BANK_NUM_WIDTH-1:0] operand0_bank_w;
    /* verilator lint_off UNUSED */
    logic [BANK_NUM_WIDTH-1:0] operand1_bank_w;
    logic [BANK_NUM_WIDTH-1:0] operand2_bank_w;
    /* verilator lint_on UNUSED */
    logic [BANK_ADDR_WIDTH-1:0] local_offset_w;
    logic [BTT_WIDTH-1:0] byte_count_w;
    logic [AXI_ADDR_WIDTH-1:0] axi_address_w;
    logic [TAG_WIDTH-1:0] operand0_tag_w;

    logic fixed_opcode_w;
    logic opcode_known_w;
    logic fixed_command_legal_w;
    logic fixed_bank_eligible_w;
    logic command_legal_w;
    logic bank_in_range_w;
    logic bank_eligible_w;
    logic fixed_request_fire_w;
    logic request_fire_w;
    logic fixed_pending_any_w;
    logic pending_any_w;
    logic busy_any_w;
    logic mm2s_response_match_w;
    logic s2mm_response_match_w;
    logic fixed_response_fault_w;
    logic fixed_executor_fault_w;
    logic response_fault_w;
    logic executor_fault_w;
    /* verilator lint_off LITENDIAN */
    logic [0:BANK_NUM-1] fixed_bank_acquire_valid_w;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] fixed_bank_acquire_port_w;
    logic [0:BANK_NUM-1] fixed_bank_release_valid_w;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] fixed_bank_release_port_w;
    logic [0:BANK_NUM-1] user_bank_acquire_valid_w;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] user_bank_acquire_port_w;
    logic [0:BANK_NUM-1] user_bank_release_valid_w;
    logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] user_bank_release_port_w;
    /* verilator lint_on LITENDIAN */
    logic user_opcode_known_w;
    logic user_command_legal_w;
    logic user_bank_eligible_w;
    logic user_request_valid_w;
    logic user_request_ready_w;
    logic user_request_fire_w;
    logic user_pending_any_w;
    logic user_response_fault_w;
    logic user_executor_fault_w;
    logic [BANK_NUM_WIDTH:0] operand0_index_w;
    logic [TAG_WIDTH:0] mm2s_tag_index_w;
    logic [TAG_WIDTH:0] s2mm_tag_index_w;

    // USER_DECLARATIONS_BEGIN
    logic [4:0] exec_active_r;
    logic [4:0][9:0] exec_identity_r;
    logic [4:0][255:0] exec_saved_r;
    logic [22:0] selected_banks;
    logic [22:0][4:0] selected_roles;
    logic [4:0] exec_response_match;
    integer selected_executor;
    function automatic logic [22:0][4:0] roles(input logic [255:0] record);
      logic [22:0][4:0] r;
      logic [4:0] a,b,c,s;logic [3:0] op,mode;
      r='0;a=record[247+:5];b=record[242+:5];c=record[237+:5];s=record[133+:5];
      op=record[252+:4];mode=record[146+:4];
      if(a<23 && c<23)case(op)
        3:begin r[a]=3;if(b<23)r[b]=4;r[c]=5;if(mode==0 && s<23)r[s]=6;end
        4:begin r[a]=7;if(b<23)r[b]=8;r[c]=9;end
        5:begin r[a]=10;if(b<23)r[b]=11;r[c]=12;end
        6:begin r[a]=13;r[c]=14;end
        7:begin r[a]=15;if(mode<4 && b<23)r[b]=16;r[c]=17;end
        default:r='0;
      endcase
      return r;
    endfunction
    logic [22:0][4:0] saved_roles[0:4];
    // USER_DECLARATIONS_END

    assign opcode_w = command_r[CMD_DATA_WIDTH-1 -: OPCODE_WIDTH];
    assign operand0_bank_w = command_r[OPCODE_LSB-1 -: BANK_NUM_WIDTH];
    assign operand1_bank_w = command_r[OPERAND0_LSB-1 -: BANK_NUM_WIDTH];
    assign operand2_bank_w = command_r[OPERAND1_LSB-1 -: BANK_NUM_WIDTH];
    assign local_offset_w = command_r[OPERAND2_LSB-1 -: BANK_ADDR_WIDTH];
    assign byte_count_w = command_r[LOCAL_OFFSET_LSB-1 -: BTT_WIDTH];
    assign axi_address_w = command_r[BYTE_COUNT_LSB-1 -: AXI_ADDR_WIDTH];

    always_comb begin
        operand0_tag_w = TAG_WIDTH'(operand0_bank_w);
        operand0_index_w = {1'b0, operand0_bank_w};

        fixed_opcode_w = (opcode_w == OP_END) ||
                         (opcode_w == OP_MM2S) ||
                         (opcode_w == OP_S2MM);
        bank_in_range_w = (operand0_index_w < BANK_NUM_LIMIT);
        fixed_command_legal_w = 1'b0;
        fixed_bank_eligible_w = 1'b0;

        case (opcode_w)
            OP_END: begin
                fixed_command_legal_w = 1'b1;
                fixed_bank_eligible_w = 1'b1;
            end
            OP_MM2S, OP_S2MM: begin
                fixed_command_legal_w = bank_in_range_w && (byte_count_w != '0);
                if (bank_in_range_w) begin
                    fixed_bank_eligible_w = !bank_busy[operand0_bank_w] &&
                                      !pending_mm2s_r[operand0_bank_w] &&
                                      !pending_s2mm_r[operand0_bank_w];
                end
            end
            default: begin
                fixed_command_legal_w = 1'b0;
                fixed_bank_eligible_w = 1'b0;
            end
        endcase
    end

    // USER_DECODE_BEGIN
    always @* begin
      user_opcode_known_w=opcode_w>=3 && opcode_w<=7;
      selected_executor=int'(opcode_w)-3;
      selected_roles=roles(command_r);selected_banks='0;
      for(integer b=0;b<23;b=b+1)selected_banks[b]=selected_roles[b]!=0;
      user_command_legal_w=user_opcode_known_w && descriptor_command_legal &&
        command_r[18:0]==0 && local_offset_w==0 && byte_count_w==0 && axi_address_w==0 &&
        operand0_bank_w<23 && operand2_bank_w<23 && operand0_bank_w!=operand2_bank_w;
      if(opcode_w==3 || opcode_w==4 || opcode_w==5 || (opcode_w==7 && command_r[146+:4]<4))
        user_command_legal_w=user_command_legal_w && operand1_bank_w<23 && operand1_bank_w!=operand0_bank_w && operand1_bank_w!=operand2_bank_w;
      if(opcode_w==3 && command_r[146+:4]==0)
        user_command_legal_w=user_command_legal_w && command_r[133+:5]<23 && command_r[133+:5]!=operand0_bank_w && command_r[133+:5]!=operand1_bank_w && command_r[133+:5]!=operand2_bank_w;
      user_bank_eligible_w=user_opcode_known_w && descriptor_bank_eligible;
      if(user_opcode_known_w)user_bank_eligible_w=user_bank_eligible_w && !exec_active_r[selected_executor];
      for(integer b=0;b<23;b=b+1)if(selected_banks[b] && bank_busy[b])user_bank_eligible_w=0;
    end
    // USER_DECODE_END

    always_comb begin
        opcode_known_w = fixed_opcode_w || user_opcode_known_w;
        command_legal_w = fixed_opcode_w ? fixed_command_legal_w :
                                             user_command_legal_w;
        bank_eligible_w = fixed_opcode_w ? fixed_bank_eligible_w :
                                            user_bank_eligible_w;
    end

    always_comb begin
        mm2s_tag_index_w = {1'b0, s_ctrl_mm2s_sts_tag};
        s2mm_tag_index_w = {1'b0, s_ctrl_s2mm_sts_tag};
        mm2s_response_match_w = 1'b0;
        if (mm2s_tag_index_w < TAG_BANK_NUM_LIMIT) begin
            mm2s_response_match_w = pending_mm2s_r[s_ctrl_mm2s_sts_tag];
        end

        s2mm_response_match_w = 1'b0;
        if (s2mm_tag_index_w < TAG_BANK_NUM_LIMIT) begin
            s2mm_response_match_w = pending_s2mm_r[s_ctrl_s2mm_sts_tag];
        end

        fixed_response_fault_w = cmd_dispatcher_busy &&
            ((s_ctrl_mm2s_sts_valid && !mm2s_response_match_w) ||
             (s_ctrl_s2mm_sts_valid && !s2mm_response_match_w));
        fixed_executor_fault_w = cmd_dispatcher_busy &&
            ((s_ctrl_mm2s_sts_valid && mm2s_response_match_w &&
              s_ctrl_mm2s_sts_error) ||
             (s_ctrl_s2mm_sts_valid && s2mm_response_match_w &&
              s_ctrl_s2mm_sts_error));
    end

    always_comb begin
        cmd_dispatcher_busy = (state_r == FETCH) ||
                              (state_r == CHECK_COMMAND) ||
                              (state_r == ISSUE_COMMAND) ||
                              (state_r == END_DRAIN) ||
                              (state_r == ERROR_DRAIN);
        cmd_dispatcher_done = (state_r == DONE_STATE);
        cmd_dispatcher_error = (state_r == ERROR_STATE);
        cmd_dispatcher_error_code = error_code_r;
        current_pc = pc_r;

        cmd_enb = (state_r == FETCH) && (fetch_count_r == '0);
        cmd_addrb = pc_r;

        m_ctrl_mm2s_cmd_valid = aresetn &&
                                (state_r == ISSUE_COMMAND) &&
                                (opcode_w == OP_MM2S) &&
                                !response_fault_w && !executor_fault_w;
        m_ctrl_mm2s_cmd_addr = axi_address_w;
        m_ctrl_mm2s_cmd_btt = byte_count_w;
        m_ctrl_mm2s_cmd_offset = local_offset_w;
        m_ctrl_mm2s_cmd_bank = operand0_bank_w;
        m_ctrl_mm2s_cmd_tag = operand0_tag_w;

        m_ctrl_s2mm_cmd_valid = aresetn &&
                                (state_r == ISSUE_COMMAND) &&
                                (opcode_w == OP_S2MM) &&
                                !response_fault_w && !executor_fault_w;
        m_ctrl_s2mm_cmd_addr = axi_address_w;
        m_ctrl_s2mm_cmd_btt = byte_count_w;
        m_ctrl_s2mm_cmd_offset = local_offset_w;
        m_ctrl_s2mm_cmd_bank = operand0_bank_w;
        m_ctrl_s2mm_cmd_tag = operand0_tag_w;

        m_ctrl_mm2s_sts_ready = aresetn;
        m_ctrl_s2mm_sts_ready = aresetn;

        fixed_request_fire_w =
            (m_ctrl_mm2s_cmd_valid && m_ctrl_mm2s_cmd_ready) ||
            (m_ctrl_s2mm_cmd_valid && m_ctrl_s2mm_cmd_ready);

        fixed_bank_acquire_valid_w = '0;
        fixed_bank_acquire_port_w = '0;
        fixed_bank_release_valid_w = '0;
        fixed_bank_release_port_w = '0;
        if (fixed_request_fire_w) begin
            fixed_bank_acquire_valid_w[operand0_bank_w] = 1'b1;
            fixed_bank_acquire_port_w[operand0_bank_w] =
                (opcode_w == OP_MM2S) ? PORT_MM2S_ARBITER : PORT_S2MM_ARBITER;
        end
        if (aresetn && s_ctrl_mm2s_sts_valid && mm2s_response_match_w) begin
            fixed_bank_release_valid_w[s_ctrl_mm2s_sts_tag] = 1'b1;
            fixed_bank_release_port_w[s_ctrl_mm2s_sts_tag] = PORT_MM2S_ARBITER;
        end
        if (aresetn && s_ctrl_s2mm_sts_valid && s2mm_response_match_w) begin
            fixed_bank_release_valid_w[s_ctrl_s2mm_sts_tag] = 1'b1;
            fixed_bank_release_port_w[s_ctrl_s2mm_sts_tag] = PORT_S2MM_ARBITER;
        end

        fixed_pending_any_w = |(pending_mm2s_r | pending_s2mm_r);
        busy_any_w = |bank_busy;
    end

    // USER_ISSUE_BEGIN
    always @* begin
      exec_command=command_r;exec_cmd_id=pc_r;exec_cmd_valid='0;
      user_request_valid_w=state_r==ISSUE_COMMAND && user_opcode_known_w && user_command_legal_w && user_bank_eligible_w;
      user_request_ready_w=0;
      if(user_opcode_known_w)begin
        exec_cmd_valid[selected_executor]=user_request_valid_w;
        user_request_ready_w=exec_cmd_ready[selected_executor];
      end
      user_request_fire_w=user_request_valid_w && user_request_ready_w;
      user_bank_acquire_valid_w='0;user_bank_acquire_port_w='0;
      if(user_request_fire_w)for(integer b=0;b<23;b=b+1)if(selected_banks[b])begin
        user_bank_acquire_valid_w[b]=1;user_bank_acquire_port_w[b]=selected_roles[b];
      end
    end
    // USER_ISSUE_END

    // USER_COMPLETION_BEGIN
    always @* begin
      user_pending_any_w=|exec_active_r;user_bank_release_valid_w='0;user_bank_release_port_w='0;
      user_response_fault_w=0;user_executor_fault_w=0;exec_response_match='0;
      exec_rsp_ready='1;exec_commit_valid='0;exec_commit_error='0;exec_commit_command=exec_saved_r;
      for(integer e=0;e<5;e=e+1)begin
        if(exec_rsp_valid[e])begin
          if(!exec_active_r[e] || exec_rsp_id[e]!=exec_identity_r[e])user_response_fault_w=1;
          else begin
            exec_response_match[e]=1;exec_commit_valid[e]=1;exec_commit_error[e]=exec_rsp_error[e];
            if(exec_rsp_error[e])user_executor_fault_w=1;
            for(integer b=0;b<23;b=b+1)if(saved_roles[e][b]!=0)begin
              if(!bank_busy[b] || bank_owner_port[b]!=saved_roles[e][b])user_response_fault_w=1;
              user_bank_release_valid_w[b]=1;user_bank_release_port_w[b]=saved_roles[e][b];
            end
          end
        end
      end
    end
    always_ff @(posedge aclk)begin
      if(!aresetn)begin exec_active_r<='0;exec_identity_r<='0;exec_saved_r<='0;for(integer e=0;e<5;e=e+1)saved_roles[e]<='0;end
      else begin
        for(integer e=0;e<5;e=e+1)if(exec_response_match[e])exec_active_r[e]<=0;
        if(user_request_fire_w)begin
          exec_active_r[selected_executor]<=1;exec_identity_r[selected_executor]<=pc_r;exec_saved_r[selected_executor]<=command_r;saved_roles[selected_executor]<=selected_roles;
        end
      end
    end
    // USER_COMPLETION_END

    always_comb begin
        request_fire_w = fixed_request_fire_w ||
                         (user_request_valid_w && user_request_ready_w &&
                          user_request_fire_w);
        bank_acquire_valid = fixed_bank_acquire_valid_w | user_bank_acquire_valid_w;
        bank_acquire_port = fixed_bank_acquire_port_w | user_bank_acquire_port_w;
        bank_release_valid = fixed_bank_release_valid_w | user_bank_release_valid_w;
        bank_release_port = fixed_bank_release_port_w | user_bank_release_port_w;
        pending_any_w = fixed_pending_any_w || user_pending_any_w;
        response_fault_w = fixed_response_fault_w || user_response_fault_w ||
            (cmd_dispatcher_busy && user_request_fire_w &&
             !(user_request_valid_w && user_request_ready_w));
        executor_fault_w = fixed_executor_fault_w || user_executor_fault_w;
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_r <= IDLE;
            pc_r <= '0;
            fetch_count_r <= '0;
            command_r <= '0;
            error_code_r <= ERR_NONE;
            pending_mm2s_r <= '0;
            pending_s2mm_r <= '0;
        end else begin
            if (s_ctrl_mm2s_sts_valid && mm2s_response_match_w) begin
                pending_mm2s_r[s_ctrl_mm2s_sts_tag] <= 1'b0;
            end
            if (s_ctrl_s2mm_sts_valid && s2mm_response_match_w) begin
                pending_s2mm_r[s_ctrl_s2mm_sts_tag] <= 1'b0;
            end

            if ((response_fault_w || executor_fault_w) &&
                (state_r != ERROR_DRAIN)) begin
                error_code_r <= response_fault_w ? ERR_RESPONSE : ERR_EXECUTOR;
                state_r <= ERROR_DRAIN;
            end else begin
                case (state_r)
                    IDLE: begin
                        if (cmd_dispatcher_start) begin
                            pc_r <= '0;
                            fetch_count_r <= '0;
                            error_code_r <= ERR_NONE;
                            if (PARAMETERS_LEGAL) begin
                                state_r <= FETCH;
                            end else begin
                                error_code_r <= ERR_PARAMETER;
                                state_r <= ERROR_STATE;
                            end
                        end
                    end
                    FETCH: begin
                        if (fetch_count_r < FETCH_LATENCY_COUNT) begin
                            fetch_count_r <= fetch_count_r + 1'b1;
                        end else begin
                            command_r <= cmd_doutb;
                            fetch_count_r <= '0;
                            state_r <= CHECK_COMMAND;
                        end
                    end
                    CHECK_COMMAND: begin
                        if (!opcode_known_w) begin
                            error_code_r <= ERR_OPCODE;
                            state_r <= ERROR_DRAIN;
                        end else if (!command_legal_w) begin
                            error_code_r <= ERR_OPERAND;
                            state_r <= ERROR_DRAIN;
                        end else if (opcode_w == OP_END) begin
                            state_r <= END_DRAIN;
                        end else if (bank_eligible_w) begin
                            state_r <= ISSUE_COMMAND;
                        end
                    end
                    ISSUE_COMMAND: begin
                        if (request_fire_w) begin
                            if (opcode_w == OP_MM2S) begin
                                pending_mm2s_r[operand0_bank_w] <= 1'b1;
                            end else if (opcode_w == OP_S2MM) begin
                                pending_s2mm_r[operand0_bank_w] <= 1'b1;
                            end
                            if (pc_r == LAST_PC) begin
                                error_code_r <= ERR_MISSING_END;
                                state_r <= ERROR_DRAIN;
                            end else begin
                                pc_r <= pc_r + 1'b1;
                                fetch_count_r <= '0;
                                state_r <= FETCH;
                            end
                        end
                    end
                    END_DRAIN: begin
                        if (!pending_any_w && !busy_any_w) begin
                            state_r <= DONE_STATE;
                        end
                    end
                    ERROR_DRAIN: begin
                        if (!pending_any_w && !busy_any_w) begin
                            state_r <= ERROR_STATE;
                        end
                    end
                    DONE_STATE, ERROR_STATE: begin
                        if (cmd_dispatcher_start) begin
                            pc_r <= '0;
                            fetch_count_r <= '0;
                            error_code_r <= ERR_NONE;
                            if (PARAMETERS_LEGAL) begin
                                state_r <= FETCH;
                            end else begin
                                error_code_r <= ERR_PARAMETER;
                                state_r <= ERROR_STATE;
                            end
                        end
                    end
                    default: begin
                        error_code_r <= ERR_OPCODE;
                        state_r <= ERROR_DRAIN;
                    end
                endcase
            end
        end
    end

endmodule
