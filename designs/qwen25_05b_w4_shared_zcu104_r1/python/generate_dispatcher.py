"""Fill only documented USER regions; common PC/DMA/ownership logic is reused."""
from pathlib import Path
import hashlib,json,re
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
def main():
 template=ROOT/'ip/infrastructure/cmd_dispatcher_template/history/v2/rtl/cmd_dispatcher_template.sv'
 assert hashlib.sha256(template.read_bytes()).hexdigest()=='f1d4dcb08faac1f469c857132344b6be057c82b52c6f870557dde2a45a46d8fe', 'Pinned exclusive-owner template changed'
 source=template.read_text()
 regions={
 'PORTS':'''    ,output logic [4:0] exec_cmd_valid
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
''',
 'DECLARATIONS':'''    logic [4:0] exec_active_r;
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
''',
 'DECODE':'''    always_comb begin
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
''',
 'ISSUE':'''    always_comb begin
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
''',
 'COMPLETION':'''    always_comb begin
      user_pending_any_w=|exec_active_r;user_bank_release_valid_w='0;user_bank_release_port_w='0;
      user_response_fault_w=0;user_executor_fault_w=0;exec_response_match='0;
      exec_rsp_ready='1;exec_commit_valid='0;exec_commit_error='0;exec_commit_command=exec_saved_r;
      for(integer e=0;e<5;e=e+1)begin
        if(exec_rsp_valid[e])begin
          if(!exec_active_r[e] || exec_rsp_id[e]!=exec_identity_r[e])user_response_fault_w=1;
          else begin
            exec_response_match[e]=1;exec_commit_valid[e]=1;exec_commit_error[e]=exec_rsp_error[e];
            if(exec_rsp_error[e])user_executor_fault_w=1;
            for(integer b=0;b<23;b=b+1)if(roles(exec_saved_r[e])[b]!=0)begin
              if(!bank_busy[b] || bank_owner_port[b]!=roles(exec_saved_r[e])[b])user_response_fault_w=1;
              user_bank_release_valid_w[b]=1;user_bank_release_port_w[b]=roles(exec_saved_r[e])[b];
            end
          end
        end
      end
    end
    always_ff @(posedge aclk)begin
      if(!aresetn)begin exec_active_r<='0;exec_identity_r<='0;exec_saved_r<='0;end
      else begin
        for(integer e=0;e<5;e=e+1)if(exec_response_match[e])exec_active_r[e]<=0;
        if(user_request_fire_w)begin
          exec_active_r[selected_executor]<=1;exec_identity_r[selected_executor]<=pc_r;exec_saved_r[selected_executor]<=command_r;
        end
      end
    end
'''
 }
 # Store function results in local arrays; part-select of a function return is not portable SV.
 regions['DECLARATIONS']+='    logic [22:0][4:0] saved_roles[0:4];\n'
 regions['COMPLETION']=regions['COMPLETION'].replace('roles(exec_saved_r[e])[b]','saved_roles[e][b]')
 regions['COMPLETION']=regions['COMPLETION'].replace("exec_saved_r<='0;end", "exec_saved_r<='0;for(integer e=0;e<5;e=e+1)saved_roles[e]<='0;end")
 regions['COMPLETION']=regions['COMPLETION'].replace('exec_saved_r[selected_executor]<=command_r;', 'exec_saved_r[selected_executor]<=command_r;saved_roles[selected_executor]<=selected_roles;')
 for name,text in regions.items():
  text=text.replace('always_comb begin','always @* begin')
  pattern=r'(    // USER_'+name+r'_BEGIN\n).*?(    // USER_'+name+r'_END)'
  source,n=re.subn(pattern,lambda m:m[1]+text+m[2],source,flags=re.S)
  assert n==1,name
 source=source.replace('module cmd_dispatcher_template #(','module qwen_dispatcher #(',1)
 (BASE/'rtl/qwen_dispatcher.sv').write_text(source)
 (BASE/'dispatcher_binding.json').write_text(json.dumps({'template_path':str(template.relative_to(ROOT)),'template_sha256':hashlib.sha256(template.read_bytes()).hexdigest(),'extension_regions':list(regions),'required_instantiation_parameters':{'BANK_NUM':23,'BANK_NUM_WIDTH':5,'TAG_WIDTH':5,'PORT_ROLE_WIDTH':5,'CMD_DATA_WIDTH':256,'CMD_READ_LATENCY':2,'MAX_COMMANDS':1024},'status':'generated_not_verified','scope':'Common PC/ownership/DMA logic unchanged; compute route and completion extension. Descriptor controller and DMA wrapper validation still required.'},indent=2)+'\n')
if __name__=='__main__':main()
