`timescale 1ns/1ps

module sparse_isa_dispatcher #(
  parameter integer AXI_ADDR_WIDTH=32, BTT_WIDTH=23, BANK_NUM=16,
  parameter integer BANK_NUM_WIDTH=4, TAG_WIDTH=4, BANK_ADDR_WIDTH=32,
  parameter integer CMD_ADDR_WIDTH=10, CMD_READ_LATENCY=2,
  parameter integer CMD_DATA_WIDTH=128, MAX_COMMANDS=1024,
  parameter integer OPCODE_WIDTH=4, PORT_ROLE_WIDTH=3
)(
  input logic aclk,input logic aresetn,input logic cmd_dispatcher_start,
  output logic cmd_dispatcher_busy,output logic cmd_dispatcher_done,
  output logic cmd_dispatcher_error,output logic[7:0]cmd_dispatcher_error_code,
  output logic[CMD_ADDR_WIDTH-1:0]current_pc,
  output logic cmd_enb,output logic[CMD_ADDR_WIDTH-1:0]cmd_addrb,
  input logic[CMD_DATA_WIDTH-1:0]cmd_doutb,

  output logic m_ctrl_mm2s_cmd_valid,input logic m_ctrl_mm2s_cmd_ready,
  output logic[AXI_ADDR_WIDTH-1:0]m_ctrl_mm2s_cmd_addr,
  output logic[BTT_WIDTH-1:0]m_ctrl_mm2s_cmd_btt,
  output logic[BANK_ADDR_WIDTH-1:0]m_ctrl_mm2s_cmd_offset,
  output logic[BANK_NUM_WIDTH-1:0]m_ctrl_mm2s_cmd_bank,
  output logic[TAG_WIDTH-1:0]m_ctrl_mm2s_cmd_tag,
  input logic s_ctrl_mm2s_sts_valid,output logic m_ctrl_mm2s_sts_ready,
  input logic[TAG_WIDTH-1:0]s_ctrl_mm2s_sts_tag,input logic s_ctrl_mm2s_sts_error,
  input logic[7:0]s_ctrl_mm2s_sts_error_code,

  output logic m_ctrl_s2mm_cmd_valid,input logic m_ctrl_s2mm_cmd_ready,
  output logic[AXI_ADDR_WIDTH-1:0]m_ctrl_s2mm_cmd_addr,
  output logic[BTT_WIDTH-1:0]m_ctrl_s2mm_cmd_btt,
  output logic[BANK_ADDR_WIDTH-1:0]m_ctrl_s2mm_cmd_offset,
  output logic[BANK_NUM_WIDTH-1:0]m_ctrl_s2mm_cmd_bank,
  output logic[TAG_WIDTH-1:0]m_ctrl_s2mm_cmd_tag,
  input logic s_ctrl_s2mm_sts_valid,output logic m_ctrl_s2mm_sts_ready,
  input logic[TAG_WIDTH-1:0]s_ctrl_s2mm_sts_tag,input logic s_ctrl_s2mm_sts_error,
  input logic[7:0]s_ctrl_s2mm_sts_error_code,

  output logic m_ctrl_sa_cmd_valid,input logic m_ctrl_sa_cmd_ready,
  output logic[5:0]m_ctrl_sa_m_size,output logic[10:0]m_ctrl_sa_n_size,
  output logic[11:0]m_ctrl_sa_k_size,
  output logic[3:0]m_ctrl_sa_act_bank,output logic[3:0]m_ctrl_sa_wgt_bank,
  output logic[3:0]m_ctrl_sa_out_bank,output logic[31:0]m_ctrl_sa_out_base_addr,
  input logic s_ctrl_sa_done_valid,output logic m_ctrl_sa_done_ready,
  input logic s_ctrl_sa_done_error,input logic[3:0]s_ctrl_sa_act_bank,
  input logic[3:0]s_ctrl_sa_wgt_bank,input logic[3:0]s_ctrl_sa_out_bank,

  output logic[0:15]bank_acquire_valid,output logic[0:15][2:0]bank_acquire_port,
  output logic[0:15]bank_release_valid,output logic[0:15][2:0]bank_release_port,
  input logic[0:15]bank_busy,input logic[0:15][2:0]bank_owner_port
);
  import bank_config_pkg::*;
  localparam integer REQUIRED_CMD_WIDTH=OPCODE_WIDTH+3*BANK_NUM_WIDTH+
    BANK_ADDR_WIDTH+BTT_WIDTH+AXI_ADDR_WIDTH;
  localparam integer FETCH_COUNT_WIDTH=(CMD_READ_LATENCY<2)?1:$clog2(CMD_READ_LATENCY+1);
  localparam integer REQUIRED_BANK_NUM_WIDTH=(BANK_NUM<=1)?1:$clog2(BANK_NUM);
  localparam integer REQUIRED_CMD_ADDR_WIDTH=(MAX_COMMANDS<=1)?1:$clog2(MAX_COMMANDS);
  localparam logic[FETCH_COUNT_WIDTH-1:0]FETCH_LATENCY_COUNT=FETCH_COUNT_WIDTH'(CMD_READ_LATENCY);
  localparam logic[CMD_ADDR_WIDTH-1:0]LAST_PC=CMD_ADDR_WIDTH'(MAX_COMMANDS-1);
  localparam logic PARAMETERS_LEGAL=(BANK_NUM==bank_config_pkg::BANK_NUM)&&
    (BANK_NUM_WIDTH>=REQUIRED_BANK_NUM_WIDTH)&&(TAG_WIDTH>=BANK_NUM_WIDTH)&&
    (CMD_READ_LATENCY>=1)&&(MAX_COMMANDS>=1)&&(CMD_ADDR_WIDTH>=REQUIRED_CMD_ADDR_WIDTH)&&
    (CMD_DATA_WIDTH>=REQUIRED_CMD_WIDTH)&&(PORT_ROLE_WIDTH>=3)&&(OPCODE_WIDTH>=2)&&
    (BANK_ADDR_WIDTH>=32)&&(AXI_ADDR_WIDTH<=BANK_ADDR_WIDTH);
  localparam integer OPCODE_LSB=CMD_DATA_WIDTH-OPCODE_WIDTH;
  localparam integer OPERAND0_LSB=OPCODE_LSB-BANK_NUM_WIDTH;
  localparam integer OPERAND1_LSB=OPERAND0_LSB-BANK_NUM_WIDTH;
  localparam integer OPERAND2_LSB=OPERAND1_LSB-BANK_NUM_WIDTH;
  localparam integer LOCAL_OFFSET_LSB=OPERAND2_LSB-BANK_ADDR_WIDTH;
  localparam integer BYTE_COUNT_LSB=LOCAL_OFFSET_LSB-BTT_WIDTH;
  localparam integer AXI_ADDRESS_LSB=BYTE_COUNT_LSB-AXI_ADDR_WIDTH;
  localparam logic[OPCODE_WIDTH-1:0]OP_END=0,OP_MM2S=1,OP_S2MM=2,OP_GEMM=3;
  localparam logic[7:0]ERR_NONE=0,ERR_OPCODE=1,ERR_OPERAND=2,ERR_RESPONSE=3,
    ERR_EXECUTOR=4,ERR_MISSING_END=5,ERR_PARAMETER=6;
  typedef enum logic[3:0]{IDLE,FETCH,CHECK_COMMAND,ISSUE_COMMAND,END_DRAIN,
    ERROR_DRAIN,DONE_STATE,ERROR_STATE}state_t;
  state_t state_r;
  logic[CMD_ADDR_WIDTH-1:0]pc_r;
  logic[FETCH_COUNT_WIDTH-1:0]fetch_count_r;
  logic[CMD_DATA_WIDTH-1:0]command_r;
  logic[7:0]error_code_r;
  logic[0:15]pending_mm2s_r,pending_s2mm_r;
  logic gemm_pending_r;
  logic[BANK_NUM_WIDTH-1:0]gemm_act_bank_r,gemm_wgt_bank_r,gemm_out_bank_r;

  logic[OPCODE_WIDTH-1:0]opcode_w;
  logic[BANK_NUM_WIDTH-1:0]operand0_bank_w,operand1_bank_w,operand2_bank_w;
  logic[BANK_ADDR_WIDTH-1:0]local_offset_w;
  logic[BTT_WIDTH-1:0]byte_count_w;
  logic[AXI_ADDR_WIDTH-1:0]axi_address_w;
  logic[5:0]gemm_m_w;logic[10:0]gemm_n_w;logic[11:0]gemm_k_w;
  logic opcode_known_w,command_legal_w,bank_eligible_w,request_fire_w;
  logic mm2s_match_w,s2mm_match_w,gemm_match_w,response_fault_w,executor_fault_w;
  logic mm2s_response_fire_w,s2mm_response_fire_w,sa_response_fire_w;
  logic mm2s_success_w,s2mm_success_w,mm2s_descriptor_error_w,s2mm_descriptor_error_w;
  logic mm2s_transport_fault_w,s2mm_transport_fault_w,dma_descriptor_fault_w;
  logic dma_transport_fault_w,mm2s_retire_w,s2mm_retire_w,response_accept_ready_w;
  logic[7:0]dma_fault_code_w;
  logic pending_any_w,busy_any_w;
  logic[BANK_NUM_WIDTH:0]op0_index_w,op1_index_w,op2_index_w;
  logic[TAG_WIDTH:0]mm2s_tag_index_w,s2mm_tag_index_w;
  assign opcode_w=command_r[CMD_DATA_WIDTH-1-:OPCODE_WIDTH];
  assign operand0_bank_w=command_r[OPCODE_LSB-1-:BANK_NUM_WIDTH];
  assign operand1_bank_w=command_r[OPERAND0_LSB-1-:BANK_NUM_WIDTH];
  assign operand2_bank_w=command_r[OPERAND1_LSB-1-:BANK_NUM_WIDTH];
  assign local_offset_w=command_r[OPERAND2_LSB-1-:BANK_ADDR_WIDTH];
  assign byte_count_w=command_r[LOCAL_OFFSET_LSB-1-:BTT_WIDTH];
  assign axi_address_w=command_r[BYTE_COUNT_LSB-1-:AXI_ADDR_WIDTH];
  assign gemm_m_w=local_offset_w[31:26];
  assign gemm_n_w=local_offset_w[25:15];
  assign gemm_k_w=local_offset_w[14:3];

  function automatic logic descriptor_code(input logic[7:0]code);
    descriptor_code=(code>=8'h01)&&(code<=8'h06);
  endfunction
  function automatic logic transport_code(input logic[7:0]code);
    transport_code=(code==8'h10)||(code==8'h20)||(code==8'h30)||
      (code==8'h40)||(code==8'h50);
  endfunction

  always_comb begin
    op0_index_w={1'b0,operand0_bank_w};op1_index_w={1'b0,operand1_bank_w};
    op2_index_w={1'b0,operand2_bank_w};
    opcode_known_w=(opcode_w==OP_END)||(opcode_w==OP_MM2S)||
      (opcode_w==OP_S2MM)||(opcode_w==OP_GEMM);
    command_legal_w=1'b0;bank_eligible_w=1'b0;
    case(opcode_w)
      OP_END:begin command_legal_w=1'b1;bank_eligible_w=1'b1;end
      OP_MM2S:begin
        command_legal_w=(op0_index_w<BANK_NUM)&&bank_allows_mm2s(integer'(operand0_bank_w))&&
          (byte_count_w!='0)&&!(|local_offset_w[31:23]);
        if(command_legal_w)bank_eligible_w=!bank_busy[operand0_bank_w]&&
          !pending_mm2s_r[operand0_bank_w]&&!pending_s2mm_r[operand0_bank_w];
      end
      OP_S2MM:begin
        command_legal_w=(op0_index_w<BANK_NUM)&&bank_allows_s2mm(integer'(operand0_bank_w))&&
          (byte_count_w!='0)&&!(|local_offset_w[31:23]);
        if(command_legal_w)bank_eligible_w=!bank_busy[operand0_bank_w]&&
          !pending_mm2s_r[operand0_bank_w]&&!pending_s2mm_r[operand0_bank_w];
      end
      OP_GEMM:begin
        command_legal_w=(op0_index_w<BANK_NUM)&&(op1_index_w<BANK_NUM)&&(op2_index_w<BANK_NUM)&&
          bank_allows_sa_act(integer'(operand0_bank_w))&&
          bank_allows_sa_wgt(integer'(operand1_bank_w))&&
          bank_allows_sa_out(integer'(operand2_bank_w))&&
          (operand0_bank_w!=operand1_bank_w)&&(operand0_bank_w!=operand2_bank_w)&&
          (operand1_bank_w!=operand2_bank_w)&&(gemm_m_w!='0)&&(gemm_n_w!='0)&&(gemm_k_w!='0)&&
          (axi_address_w=='0);
        if(command_legal_w)bank_eligible_w=!gemm_pending_r&&!bank_busy[operand0_bank_w]&&
          !bank_busy[operand1_bank_w]&&!bank_busy[operand2_bank_w];
      end
      default:begin command_legal_w=1'b0;bank_eligible_w=1'b0;end
    endcase
  end

  always_comb begin
    mm2s_tag_index_w={1'b0,s_ctrl_mm2s_sts_tag};
    s2mm_tag_index_w={1'b0,s_ctrl_s2mm_sts_tag};
    mm2s_match_w=1'b0;s2mm_match_w=1'b0;
    if(mm2s_tag_index_w<BANK_NUM)mm2s_match_w=pending_mm2s_r[s_ctrl_mm2s_sts_tag];
    if(s2mm_tag_index_w<BANK_NUM)s2mm_match_w=pending_s2mm_r[s_ctrl_s2mm_sts_tag];
    gemm_match_w=gemm_pending_r&&
      (s_ctrl_sa_act_bank==gemm_act_bank_r)&&(s_ctrl_sa_wgt_bank==gemm_wgt_bank_r)&&
      (s_ctrl_sa_out_bank==gemm_out_bank_r);
    mm2s_response_fire_w=s_ctrl_mm2s_sts_valid&&m_ctrl_mm2s_sts_ready;
    s2mm_response_fire_w=s_ctrl_s2mm_sts_valid&&m_ctrl_s2mm_sts_ready;
    sa_response_fire_w=s_ctrl_sa_done_valid&&m_ctrl_sa_done_ready;
    mm2s_success_w=mm2s_response_fire_w&&mm2s_match_w&&!s_ctrl_mm2s_sts_error&&
      (s_ctrl_mm2s_sts_error_code==8'h00);
    s2mm_success_w=s2mm_response_fire_w&&s2mm_match_w&&!s_ctrl_s2mm_sts_error&&
      (s_ctrl_s2mm_sts_error_code==8'h00);
    mm2s_descriptor_error_w=mm2s_response_fire_w&&mm2s_match_w&&s_ctrl_mm2s_sts_error&&
      descriptor_code(s_ctrl_mm2s_sts_error_code);
    s2mm_descriptor_error_w=s2mm_response_fire_w&&s2mm_match_w&&s_ctrl_s2mm_sts_error&&
      descriptor_code(s_ctrl_s2mm_sts_error_code);
    mm2s_retire_w=mm2s_success_w||mm2s_descriptor_error_w;
    s2mm_retire_w=s2mm_success_w||s2mm_descriptor_error_w;
    mm2s_transport_fault_w=mm2s_response_fire_w&&
      (transport_code(s_ctrl_mm2s_sts_error_code)||
       ((s_ctrl_mm2s_sts_error_code!=0)&&!descriptor_code(s_ctrl_mm2s_sts_error_code))||
       (mm2s_match_w&&!mm2s_retire_w));
    s2mm_transport_fault_w=s2mm_response_fire_w&&
      (transport_code(s_ctrl_s2mm_sts_error_code)||
       ((s_ctrl_s2mm_sts_error_code!=0)&&!descriptor_code(s_ctrl_s2mm_sts_error_code))||
       (s2mm_match_w&&!s2mm_retire_w));
    dma_descriptor_fault_w=cmd_dispatcher_busy&&
      (mm2s_descriptor_error_w||s2mm_descriptor_error_w);
    dma_transport_fault_w=cmd_dispatcher_busy&&
      (mm2s_transport_fault_w||s2mm_transport_fault_w);
    if(mm2s_transport_fault_w)
      dma_fault_code_w=(s_ctrl_mm2s_sts_error_code==0)?8'hff:s_ctrl_mm2s_sts_error_code;
    else if(s2mm_transport_fault_w)
      dma_fault_code_w=(s_ctrl_s2mm_sts_error_code==0)?8'hff:s_ctrl_s2mm_sts_error_code;
    else if(mm2s_descriptor_error_w)dma_fault_code_w=s_ctrl_mm2s_sts_error_code;
    else if(s2mm_descriptor_error_w)dma_fault_code_w=s_ctrl_s2mm_sts_error_code;
    else dma_fault_code_w=ERR_EXECUTOR;
    response_fault_w=cmd_dispatcher_busy&&
      ((mm2s_response_fire_w&&!mm2s_match_w&&!mm2s_transport_fault_w)||
       (s2mm_response_fire_w&&!s2mm_match_w&&!s2mm_transport_fault_w)||
       (sa_response_fire_w&&!gemm_match_w));
    executor_fault_w=cmd_dispatcher_busy&&
      (sa_response_fire_w&&gemm_match_w&&s_ctrl_sa_done_error);
  end

  always_comb begin
    cmd_dispatcher_busy=(state_r==FETCH)||(state_r==CHECK_COMMAND)||
      (state_r==ISSUE_COMMAND)||(state_r==END_DRAIN)||(state_r==ERROR_DRAIN);
    cmd_dispatcher_done=(state_r==DONE_STATE);cmd_dispatcher_error=(state_r==ERROR_STATE);
    cmd_dispatcher_error_code=error_code_r;current_pc=pc_r;
    cmd_enb=(state_r==FETCH)&&(fetch_count_r=='0);cmd_addrb=pc_r;
    m_ctrl_mm2s_cmd_valid=aresetn&&(state_r==ISSUE_COMMAND)&&(opcode_w==OP_MM2S);
    m_ctrl_mm2s_cmd_addr=axi_address_w;m_ctrl_mm2s_cmd_btt=byte_count_w;
    m_ctrl_mm2s_cmd_offset=local_offset_w;m_ctrl_mm2s_cmd_bank=operand0_bank_w;
    m_ctrl_mm2s_cmd_tag=TAG_WIDTH'(operand0_bank_w);
    m_ctrl_s2mm_cmd_valid=aresetn&&(state_r==ISSUE_COMMAND)&&(opcode_w==OP_S2MM);
    m_ctrl_s2mm_cmd_addr=axi_address_w;m_ctrl_s2mm_cmd_btt=byte_count_w;
    m_ctrl_s2mm_cmd_offset=local_offset_w;m_ctrl_s2mm_cmd_bank=operand0_bank_w;
    m_ctrl_s2mm_cmd_tag=TAG_WIDTH'(operand0_bank_w);
    m_ctrl_sa_cmd_valid=aresetn&&(state_r==ISSUE_COMMAND)&&(opcode_w==OP_GEMM);
    m_ctrl_sa_m_size=gemm_m_w;m_ctrl_sa_n_size=gemm_n_w;m_ctrl_sa_k_size=gemm_k_w;
    m_ctrl_sa_act_bank=operand0_bank_w;m_ctrl_sa_wgt_bank=operand1_bank_w;
    m_ctrl_sa_out_bank=operand2_bank_w;m_ctrl_sa_out_base_addr=32'd0;
    // Backpressure responses while an executor request is being offered so a
    // fault cannot retract that request before its ready-valid handshake.
    response_accept_ready_w=aresetn&&cmd_dispatcher_busy&&(state_r!=ISSUE_COMMAND);
    m_ctrl_mm2s_sts_ready=response_accept_ready_w;
    m_ctrl_s2mm_sts_ready=response_accept_ready_w;
    m_ctrl_sa_done_ready=response_accept_ready_w;
    request_fire_w=(m_ctrl_mm2s_cmd_valid&&m_ctrl_mm2s_cmd_ready)||
      (m_ctrl_s2mm_cmd_valid&&m_ctrl_s2mm_cmd_ready)||
      (m_ctrl_sa_cmd_valid&&m_ctrl_sa_cmd_ready);
    bank_acquire_valid='0;bank_acquire_port='0;bank_release_valid='0;bank_release_port='0;
    if(request_fire_w)begin
      case(opcode_w)
        OP_MM2S:begin bank_acquire_valid[operand0_bank_w]=1;bank_acquire_port[operand0_bank_w]=PORT_ROLE_WIDTH'(OWNER_MM2S);end
        OP_S2MM:begin bank_acquire_valid[operand0_bank_w]=1;bank_acquire_port[operand0_bank_w]=PORT_ROLE_WIDTH'(OWNER_S2MM);end
        OP_GEMM:begin
          bank_acquire_valid[operand0_bank_w]=1;bank_acquire_port[operand0_bank_w]=PORT_ROLE_WIDTH'(OWNER_SA_ACT);
          bank_acquire_valid[operand1_bank_w]=1;bank_acquire_port[operand1_bank_w]=PORT_ROLE_WIDTH'(OWNER_SA_WGT);
          bank_acquire_valid[operand2_bank_w]=1;bank_acquire_port[operand2_bank_w]=PORT_ROLE_WIDTH'(OWNER_SA_OUT);
        end default:begin end
      endcase
    end
    if(mm2s_retire_w)begin
      bank_release_valid[s_ctrl_mm2s_sts_tag]=1;bank_release_port[s_ctrl_mm2s_sts_tag]=PORT_ROLE_WIDTH'(OWNER_MM2S);end
    if(s2mm_retire_w)begin
      bank_release_valid[s_ctrl_s2mm_sts_tag]=1;bank_release_port[s_ctrl_s2mm_sts_tag]=PORT_ROLE_WIDTH'(OWNER_S2MM);end
    if(sa_response_fire_w&&gemm_match_w)begin
      bank_release_valid[gemm_act_bank_r]=1;bank_release_port[gemm_act_bank_r]=PORT_ROLE_WIDTH'(OWNER_SA_ACT);
      bank_release_valid[gemm_wgt_bank_r]=1;bank_release_port[gemm_wgt_bank_r]=PORT_ROLE_WIDTH'(OWNER_SA_WGT);
      bank_release_valid[gemm_out_bank_r]=1;bank_release_port[gemm_out_bank_r]=PORT_ROLE_WIDTH'(OWNER_SA_OUT);
    end
    pending_any_w=(|(pending_mm2s_r|pending_s2mm_r))||gemm_pending_r;
    busy_any_w=|bank_busy;
  end

`ifndef SYNTHESIS
  initial if(!PARAMETERS_LEGAL)$error("sparse_isa_dispatcher illegal parameters");
`endif
  always_ff @(posedge aclk)begin
    if(!aresetn)begin state_r<=IDLE;pc_r<='0;fetch_count_r<='0;command_r<='0;
      error_code_r<=ERR_NONE;pending_mm2s_r<='0;pending_s2mm_r<='0;gemm_pending_r<=0;
      gemm_act_bank_r<='0;gemm_wgt_bank_r<='0;gemm_out_bank_r<='0;end
    else begin
      if(mm2s_retire_w)pending_mm2s_r[s_ctrl_mm2s_sts_tag]<=0;
      if(s2mm_retire_w)pending_s2mm_r[s_ctrl_s2mm_sts_tag]<=0;
      if(sa_response_fire_w&&gemm_match_w)gemm_pending_r<=0;
      if((response_fault_w||dma_transport_fault_w||dma_descriptor_fault_w||executor_fault_w)&&
         (state_r!=ERROR_DRAIN))begin
        if(response_fault_w)error_code_r<=ERR_RESPONSE;
        else if(dma_transport_fault_w||dma_descriptor_fault_w)error_code_r<=dma_fault_code_w;
        else error_code_r<=ERR_EXECUTOR;
        state_r<=ERROR_DRAIN;end
      else case(state_r)
        IDLE:if(cmd_dispatcher_start)begin pc_r<='0;fetch_count_r<='0;error_code_r<=ERR_NONE;
          if(PARAMETERS_LEGAL)state_r<=FETCH;else begin error_code_r<=ERR_PARAMETER;state_r<=ERROR_STATE;end end
        FETCH:if(fetch_count_r<FETCH_LATENCY_COUNT)fetch_count_r<=fetch_count_r+1'b1;
          else begin command_r<=cmd_doutb;fetch_count_r<='0;state_r<=CHECK_COMMAND;end
        CHECK_COMMAND:if(!opcode_known_w)begin error_code_r<=ERR_OPCODE;state_r<=ERROR_DRAIN;end
          else if(!command_legal_w)begin error_code_r<=ERR_OPERAND;state_r<=ERROR_DRAIN;end
          else if(opcode_w==OP_END)state_r<=END_DRAIN;
          else if(bank_eligible_w)state_r<=ISSUE_COMMAND;
        ISSUE_COMMAND:if(request_fire_w)begin
          if(opcode_w==OP_MM2S)pending_mm2s_r[operand0_bank_w]<=1;
          else if(opcode_w==OP_S2MM)pending_s2mm_r[operand0_bank_w]<=1;
          else if(opcode_w==OP_GEMM)begin gemm_pending_r<=1;gemm_act_bank_r<=operand0_bank_w;
            gemm_wgt_bank_r<=operand1_bank_w;gemm_out_bank_r<=operand2_bank_w;end
          if(pc_r==LAST_PC)begin error_code_r<=ERR_MISSING_END;state_r<=ERROR_DRAIN;end
          else begin pc_r<=pc_r+1'b1;fetch_count_r<='0;state_r<=FETCH;end end
        END_DRAIN:if(!pending_any_w&&!busy_any_w)state_r<=DONE_STATE;
        ERROR_DRAIN:if(!pending_any_w&&!busy_any_w)state_r<=ERROR_STATE;
        DONE_STATE,ERROR_STATE:if(cmd_dispatcher_start)begin pc_r<='0;fetch_count_r<='0;
          error_code_r<=ERR_NONE;if(PARAMETERS_LEGAL)state_r<=FETCH;
          else begin error_code_r<=ERR_PARAMETER;state_r<=ERROR_STATE;end end
        default:begin error_code_r<=ERR_OPCODE;state_r<=ERROR_DRAIN;end
      endcase
    end
  end
endmodule
