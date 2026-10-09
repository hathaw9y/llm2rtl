`timescale 1ns/1ps
module attention_tensor_controller #(
  parameter int CMD_ADDR_WIDTH=10,
  parameter int MAX_COMMANDS=1024,
  parameter int CMD_READ_LATENCY=1
)(
  input logic aclk, aresetn,
  input logic cmd_dispatcher_start,
  output logic cmd_dispatcher_busy, cmd_dispatcher_done, cmd_dispatcher_error,
  output logic [7:0] cmd_dispatcher_error_code,
  output logic [CMD_ADDR_WIDTH-1:0] cmd_dispatcher_current_pc,
  output logic cmd_enb,
  output logic [CMD_ADDR_WIDTH-1:0] cmd_addrb,
  input logic [127:0] cmd_doutb,
  output logic m_ctrl_mm2s_cmd_valid,
  input logic m_ctrl_mm2s_cmd_ready,
  output logic [31:0] m_ctrl_mm2s_cmd_addr,
  output logic [22:0] m_ctrl_mm2s_cmd_btt, m_ctrl_mm2s_cmd_offset,
  output logic [4:0] m_ctrl_mm2s_cmd_bank,
  output logic m_ctrl_s2mm_cmd_valid,
  input logic m_ctrl_s2mm_cmd_ready,
  output logic [31:0] m_ctrl_s2mm_cmd_addr,
  output logic [22:0] m_ctrl_s2mm_cmd_btt, m_ctrl_s2mm_cmd_offset,
  output logic [4:0] m_ctrl_s2mm_cmd_bank,
  input logic s_ctrl_mm2s_sts_valid,
  output logic m_ctrl_mm2s_sts_ready,
  input logic [4:0] s_ctrl_mm2s_sts_bank,
  input logic s_ctrl_mm2s_sts_error, s_ctrl_mm2s_faulted,
  input logic s_ctrl_s2mm_sts_valid,
  output logic m_ctrl_s2mm_sts_ready,
  input logic [4:0] s_ctrl_s2mm_sts_bank,
  input logic s_ctrl_s2mm_sts_error, s_ctrl_s2mm_faulted,
  output logic compute_cmd_valid,
  input logic compute_cmd_ready,
  output logic [15:0] compute_cmd_id,
  output logic [7:0] compute_cmd_opcode,
  output logic [4:0] compute_cmd_src0, compute_cmd_src1, compute_cmd_dst,
  output logic [255:0] compute_cmd_src0_desc, compute_cmd_src1_desc, compute_cmd_dst_desc,
  input logic compute_resp_valid,
  output logic compute_resp_ready,
  input logic [15:0] compute_resp_id,
  input logic compute_resp_error,
  input logic [7:0] compute_resp_error_code,
  output logic desc_lookup_valid,
  output logic [4:0] desc_dst_bank, desc_src0_bank, desc_src1_bank,
  input logic desc_resp_valid,
  input logic [255:0] desc_dst, desc_src0, desc_src1,
  output logic [18:0] bank_acquire_valid, bank_release_valid,
  output logic [18:0][2:0] bank_acquire_port, bank_release_port,
  input logic [18:0] bank_busy,
  input logic [18:0][2:0] bank_owner_port,
  input logic [18:0] bank_acquire_accepted, bank_release_accepted,
  input logic bank_error,
  output logic [18:0] bank_valid
);
  import attention_tensor_pkg::*;
  typedef enum logic [3:0] {IDLE,FETCH,FETCH_WAIT,VERIFY,DESC_REQ,DESC_WAIT,
    FINAL_VERIFY,FREE_WAIT,ISSUE,WAIT_COMPLETE,RELEASE,NEXT_PC,DONE,ERROR_STATE} state_t;
  state_t state_r;
  localparam logic [7:0] ERR_OPCODE=8'd1, ERR_OPERAND=8'd2, ERR_DESCRIPTOR=8'd3,
    ERR_UNINITIALIZED=8'd4, ERR_RESPONSE=8'd5, ERR_ENGINE=8'd6, ERR_BANK=8'd7,
    ERR_ACK=8'd8, ERR_MISSING_END=8'd9, ERR_PARAMETERS=8'd10;
  localparam bit PARAMETERS_LEGAL=CMD_ADDR_WIDTH>=1 && CMD_ADDR_WIDTH<=16 &&
    MAX_COMMANDS>=1 && MAX_COMMANDS<=2**CMD_ADDR_WIDTH && CMD_READ_LATENCY>=1;
  logic [127:0] instruction_r;
  logic [7:0] opcode_w, dst_w, src0_w, src1_w;
  logic [31:0] descriptor_w;
  logic [63:0] immediate_w;
  tensor_desc_t dst_desc_r, src0_desc_r, src1_desc_r;
  logic [CMD_ADDR_WIDTH-1:0] pc_r;
  integer read_wait_r;
  logic [15:0] command_id_r;
  logic [18:0] mask_r;
  logic [18:0][2:0] roles_r;
  logic [7:0] error_code_r;
  logic halted_r, completed_error_r;
  logic active_w, binary_w, cmd_fire_w, completion_w, bad_response_w;
  logic completion_error_w;
  logic [7:0] completion_code_w;
  logic [2:0] response_count_w;
  logic basic_legal_w, descriptor_legal_w, initialized_w, owners_match_w;
  logic [18:0] decoded_mask_w;
  logic [18:0][2:0] decoded_roles_w;
  assign opcode_w=instruction_r[127:120]; assign dst_w=instruction_r[119:112];
  assign src0_w=instruction_r[111:104]; assign src1_w=instruction_r[103:96];
  assign descriptor_w=instruction_r[95:64]; assign immediate_w=instruction_r[63:0];
  assign active_w=state_r!=IDLE && state_r!=DONE && state_r!=ERROR_STATE;
  assign binary_w=opcode_w>=OP_PROJECT && opcode_w<=OP_PV;
  assign cmd_dispatcher_busy=active_w;
  assign cmd_dispatcher_done=state_r==DONE;
  assign cmd_dispatcher_error=error_code_r!=0;
  assign cmd_dispatcher_error_code=error_code_r;
  assign cmd_dispatcher_current_pc=pc_r;
  assign cmd_enb=aresetn && state_r==FETCH;
  assign cmd_addrb=pc_r;
  assign desc_lookup_valid=aresetn && state_r==DESC_REQ;
  assign desc_dst_bank=dst_w[4:0]; assign desc_src0_bank=src0_w[4:0]; assign desc_src1_bank=src1_w[4:0];
  assign compute_cmd_id=command_id_r;
  assign compute_cmd_opcode=opcode_w;
  assign compute_cmd_src0=src0_w[4:0]; assign compute_cmd_src1=src1_w[4:0]; assign compute_cmd_dst=dst_w[4:0];
  assign compute_cmd_src0_desc=src0_desc_r; assign compute_cmd_src1_desc=src1_desc_r; assign compute_cmd_dst_desc=dst_desc_r;
  assign m_ctrl_mm2s_cmd_addr=immediate_w[31:0]; assign m_ctrl_s2mm_cmd_addr=immediate_w[31:0];
  assign m_ctrl_mm2s_cmd_offset='0; assign m_ctrl_s2mm_cmd_offset='0;
  assign m_ctrl_mm2s_cmd_btt=dst_desc_r.capacity_bytes[22:0];
  assign m_ctrl_s2mm_cmd_btt=src0_desc_r.capacity_bytes[22:0];
  assign m_ctrl_mm2s_cmd_bank=dst_w[4:0]; assign m_ctrl_s2mm_cmd_bank=src0_w[4:0];
  assign m_ctrl_mm2s_cmd_valid=aresetn && state_r==ISSUE && opcode_w==OP_MM2S;
  assign m_ctrl_s2mm_cmd_valid=aresetn && state_r==ISSUE && opcode_w==OP_S2MM;
  assign compute_cmd_valid=aresetn && state_r==ISSUE && opcode_w>=OP_QUANTIZE;
  assign cmd_fire_w=(m_ctrl_mm2s_cmd_valid && m_ctrl_mm2s_cmd_ready) ||
    (m_ctrl_s2mm_cmd_valid && m_ctrl_s2mm_cmd_ready) || (compute_cmd_valid && compute_cmd_ready);
  // Status bank identity is five bits independent of the DataMover vendor tag.
  assign m_ctrl_mm2s_sts_ready=aresetn && active_w && !halted_r;
  assign m_ctrl_s2mm_sts_ready=m_ctrl_mm2s_sts_ready;
  assign compute_resp_ready=m_ctrl_mm2s_sts_ready;
  always_comb begin
    decoded_mask_w='0; decoded_roles_w='0;
    basic_legal_w=1'b0;
    if(opcode_w==OP_MM2S) begin
      basic_legal_w=dst_w<8'd19 && src0_w==0 && src1_w==0 && descriptor_w=={24'd0,dst_w} && immediate_w[63:32]==0 && immediate_w[3:0]==0;
      if(dst_w<8'd19) begin decoded_mask_w[dst_w[4:0]]=1'b1; decoded_roles_w[dst_w[4:0]]=OWNER_MM2S; end
    end else if(opcode_w==OP_S2MM) begin
      basic_legal_w=src0_w<8'd19 && dst_w==0 && src1_w==0 && descriptor_w=={24'd0,src0_w} && immediate_w[63:32]==0 && immediate_w[3:0]==0;
      if(src0_w<8'd19) begin decoded_mask_w[src0_w[4:0]]=1'b1; decoded_roles_w[src0_w[4:0]]=OWNER_S2MM; end
    end else if(opcode_w>=OP_QUANTIZE && opcode_w<=OP_PV) begin
      basic_legal_w=dst_w<8'd19 && src0_w<8'd19 && src1_w<8'd19 && dst_w!=src0_w &&
        descriptor_w=={24'd0,dst_w} && immediate_w==0 &&
        ((opcode_w==OP_QUANTIZE && src1_w==0) || (binary_w && dst_w!=src1_w && src0_w!=src1_w));
      if(dst_w<8'd19) begin decoded_mask_w[dst_w[4:0]]=1; decoded_roles_w[dst_w[4:0]]=OWNER_DST; end
      if(src0_w<8'd19) begin decoded_mask_w[src0_w[4:0]]=1; decoded_roles_w[src0_w[4:0]]=OWNER_SRC0; end
      if(binary_w && src1_w<8'd19) begin decoded_mask_w[src1_w[4:0]]=1; decoded_roles_w[src1_w[4:0]]=OWNER_SRC1; end
    end
    descriptor_legal_w=1'b0;
    initialized_w=1'b1;
    if(opcode_w==OP_MM2S) descriptor_legal_w=dst_desc_r.valid && dst_desc_r.capacity_bytes!=0 && dst_desc_r.capacity_bytes[31:23]==0 &&
      ({1'b0,immediate_w[31:0]}+{1'b0,dst_desc_r.capacity_bytes}<=33'h100000000);
    else if(opcode_w==OP_S2MM) begin
      descriptor_legal_w=src0_desc_r.valid && src0_desc_r.capacity_bytes!=0 && src0_desc_r.capacity_bytes[31:23]==0 &&
        ({1'b0,immediate_w[31:0]}+{1'b0,src0_desc_r.capacity_bytes}<=33'h100000000);
      initialized_w=src0_w<8'd19 && bank_valid[src0_w[4:0]];
    end else begin
      descriptor_legal_w=attention_tensor_config_pkg::compute_legal(opcode_w,dst_w,src0_w,src1_w) &&
        dst_desc_r.valid && src0_desc_r.valid && (!binary_w || src1_desc_r.valid);
      initialized_w=src0_w<8'd19 && bank_valid[src0_w[4:0]];
      if(binary_w) initialized_w=initialized_w && src1_w<8'd19 && bank_valid[src1_w[4:0]];
    end
    owners_match_w=1'b1;
    for(int b=0;b<19;b++) if(mask_r[b] && (!bank_busy[b] || bank_owner_port[b]!=roles_r[b])) owners_match_w=1'b0;
    response_count_w={2'd0,s_ctrl_mm2s_sts_valid && m_ctrl_mm2s_sts_ready}+
      {2'd0,s_ctrl_s2mm_sts_valid && m_ctrl_s2mm_sts_ready}+{2'd0,compute_resp_valid && compute_resp_ready};
    completion_w=response_count_w!=0;
    bad_response_w=completion_w && (response_count_w!=1 || !(state_r==WAIT_COMPLETE || cmd_fire_w));
    completion_error_w=1'b0; completion_code_w=ERR_ENGINE;
    if(s_ctrl_mm2s_sts_valid && m_ctrl_mm2s_sts_ready) begin
      bad_response_w=bad_response_w || opcode_w!=OP_MM2S || s_ctrl_mm2s_sts_bank!=dst_w[4:0] || s_ctrl_mm2s_sts_bank>=5'd19;
      completion_error_w=s_ctrl_mm2s_sts_error;
    end
    if(s_ctrl_s2mm_sts_valid && m_ctrl_s2mm_sts_ready) begin
      bad_response_w=bad_response_w || opcode_w!=OP_S2MM || s_ctrl_s2mm_sts_bank!=src0_w[4:0] || s_ctrl_s2mm_sts_bank>=5'd19;
      completion_error_w=s_ctrl_s2mm_sts_error;
    end
    if(compute_resp_valid && compute_resp_ready) begin
      bad_response_w=bad_response_w || opcode_w<OP_QUANTIZE || compute_resp_id!=command_id_r;
      completion_error_w=compute_resp_error;
      if(compute_resp_error_code!=0) completion_code_w=compute_resp_error_code;
    end
    bank_acquire_valid='0; bank_acquire_port=roles_r;
    bank_release_valid='0; bank_release_port=roles_r;
    if(cmd_fire_w) bank_acquire_valid=mask_r;
    // Release is an intent. The bank wrapper atomically suppresses acceptance
    // for immediate bank faults; the sequential fault branch forbids commit.
    // Every status is unsolicited in RELEASE. All status-ready signals are
    // high here, so raw valid OR directly blocks release without decoding ID.
    // Ownership legality is enforced atomically by the bank wrapper; the FF
    // acknowledgement check below retains the saved reservation on mismatch.
    if(aresetn && state_r==RELEASE && !halted_r &&
       !s_ctrl_mm2s_sts_valid && !s_ctrl_s2mm_sts_valid && !compute_resp_valid &&
       !s_ctrl_mm2s_faulted && !s_ctrl_s2mm_faulted) bank_release_valid=mask_r;
  end
  always_ff @(posedge aclk) begin
    if(!aresetn) begin
      state_r<=IDLE; pc_r<='0; instruction_r<='0; read_wait_r<=0;
      dst_desc_r<='0; src0_desc_r<='0; src1_desc_r<='0;
      command_id_r<='0; mask_r<='0; roles_r<='0; bank_valid<='0;
      error_code_r<='0; halted_r<=0; completed_error_r<=0;
    end else begin
      // Fault priority is explicit before evaluating acknowledgement branches.
      // An already presented stalled command remains presented until accepted;
      // on that edge invalidate its write destination and retain reservations.
      if(active_w && (bank_error || s_ctrl_mm2s_faulted || s_ctrl_s2mm_faulted || bad_response_w)) begin
        if(error_code_r==0) error_code_r<=bank_error ? ERR_BANK : ERR_RESPONSE;
        halted_r<=1;
        if(state_r==ISSUE && cmd_fire_w && opcode_w!=OP_S2MM) bank_valid[dst_w[4:0]]<=0;
        if(state_r!=ISSUE || cmd_fire_w) state_r<=ERROR_STATE;
      end else begin
      case(state_r)
        IDLE,DONE: if(cmd_dispatcher_start) begin
          pc_r<='0; error_code_r<='0; halted_r<=0; completed_error_r<=0;
          if(PARAMETERS_LEGAL && bank_busy==0) state_r<=FETCH;
          else begin state_r<=ERROR_STATE; error_code_r<=PARAMETERS_LEGAL ? ERR_BANK : ERR_PARAMETERS; end
        end
        FETCH: begin read_wait_r<=CMD_READ_LATENCY; state_r<=FETCH_WAIT; end
        FETCH_WAIT: if(read_wait_r<=1) begin instruction_r<=cmd_doutb; state_r<=VERIFY; end else read_wait_r<=read_wait_r-1;
        VERIFY: begin
          if(opcode_w==OP_END) begin
            if(instruction_r[119:0]!=0) begin error_code_r<=ERR_OPERAND; state_r<=ERROR_STATE; end
            else if(bank_busy!=0) begin error_code_r<=ERR_BANK; state_r<=ERROR_STATE; end
            else state_r<=DONE;
          end else if(opcode_w>OP_PV) begin error_code_r<=ERR_OPCODE; state_r<=ERROR_STATE; end
          else if(!basic_legal_w) begin error_code_r<=ERR_OPERAND; state_r<=ERROR_STATE; end
          else state_r<=DESC_REQ;
        end
        DESC_REQ: state_r<=DESC_WAIT;
        DESC_WAIT: if(desc_resp_valid) begin dst_desc_r<=desc_dst; src0_desc_r<=desc_src0; src1_desc_r<=desc_src1; state_r<=FINAL_VERIFY; end
        FINAL_VERIFY: begin
          if(!descriptor_legal_w) begin error_code_r<=ERR_DESCRIPTOR; state_r<=ERROR_STATE; end
          else if(!initialized_w) begin error_code_r<=ERR_UNINITIALIZED; state_r<=ERROR_STATE; end
          else begin mask_r<=decoded_mask_w; roles_r<=decoded_roles_w; state_r<=FREE_WAIT; end
        end
        FREE_WAIT: if((bank_busy & mask_r)==0) state_r<=ISSUE;
        ISSUE: if(cmd_fire_w) begin
          if(opcode_w!=OP_S2MM) bank_valid[dst_w[4:0]]<=0;
          if(bank_acquire_accepted!=mask_r) begin
            if(error_code_r==0) error_code_r<=ERR_ACK;
            halted_r<=1; state_r<=ERROR_STATE;
          end else if(halted_r) state_r<=ERROR_STATE;
          else if(completion_w && !bad_response_w) begin
            completed_error_r<=completion_error_w;
            if(completion_error_w && error_code_r==0) error_code_r<=completion_code_w;
            state_r<=RELEASE;
          end else state_r<=WAIT_COMPLETE;
        end
        WAIT_COMPLETE: if(completion_w && !bad_response_w) begin
          completed_error_r<=completion_error_w;
          if(completion_error_w && error_code_r==0) error_code_r<=completion_code_w;
          state_r<=RELEASE;
        end
        RELEASE: begin
          if(!owners_match_w || bank_release_accepted!=mask_r) begin
            if(error_code_r==0) error_code_r<=ERR_ACK;
            halted_r<=1; state_r<=ERROR_STATE;
          end else begin
            if(!completed_error_r && opcode_w!=OP_S2MM) bank_valid[dst_w[4:0]]<=1;
            command_id_r<=command_id_r+16'd1;
            state_r<=completed_error_r ? ERROR_STATE : NEXT_PC;
          end
        end
        NEXT_PC: if({1'b0,pc_r}==(CMD_ADDR_WIDTH+1)'(MAX_COMMANDS-1)) begin
          error_code_r<=ERR_MISSING_END; state_r<=ERROR_STATE;
        end else begin pc_r<=pc_r+1'b1; state_r<=FETCH; end
        ERROR_STATE: state_r<=ERROR_STATE;
        default: begin state_r<=ERROR_STATE; halted_r<=1; if(error_code_r==0) error_code_r<=ERR_BANK; end
      endcase
      end
    end
  end
`ifndef SYNTHESIS
  initial if(!PARAMETERS_LEGAL) $fatal(1,"Illegal attention controller parameters");
`endif
endmodule
