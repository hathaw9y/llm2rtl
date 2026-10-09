`timescale 1ns/1ps
module bank_sparse_router (
  input logic aclk,input logic aresetn,
  input logic [0:15] bank_busy,input logic [0:15][2:0] bank_owner_port,
  input logic mm2s_write_valid,output logic mm2s_write_ready,input logic[3:0]mm2s_write_bank,
  input logic[31:0]mm2s_write_addr,input logic[15:0]mm2s_write_strb,input logic[127:0]mm2s_write_data,
  input logic s2mm_read_valid,output logic s2mm_read_ready,input logic[31:0]s2mm_read_addr,
  output logic s2mm_rsp_valid,output logic[1023:0]s2mm_rsp_data,
  input logic sa_act_read_valid,output logic sa_act_read_ready,input logic[31:0]sa_act_read_addr,
  output logic sa_act_rsp_valid,output logic[255:0]sa_act_rsp_data,
  input logic sa_wgt_read_valid,output logic sa_wgt_read_ready,input logic[31:0]sa_wgt_read_addr,
  output logic sa_wgt_rsp_valid,output logic[127:0]sa_wgt_rsp_data,
  input logic sa_out_read_valid,output logic sa_out_read_ready,input logic[31:0]sa_out_read_addr,
  output logic sa_out_rsp_valid,output logic[1023:0]sa_out_rsp_data,
  input logic sa_out_write_valid,output logic sa_out_write_ready,input logic[31:0]sa_out_write_addr,
  input logic[127:0]sa_out_write_strb,input logic[1023:0]sa_out_write_data,
  output logic bank0_ena,output logic[15:0]bank0_wea,output logic[31:0]bank0_addra,output logic[127:0]bank0_dina,
  output logic bank1_ena,output logic[15:0]bank1_wea,output logic[31:0]bank1_addra,output logic[127:0]bank1_dina,
  output logic bank1_enb,output logic[31:0]bank1_addrb,input logic[255:0]bank1_doutb,
  output logic bank2_ena,output logic[15:0]bank2_wea,output logic[31:0]bank2_addra,output logic[127:0]bank2_dina,
  output logic bank2_enb,output logic[31:0]bank2_addrb,input logic[127:0]bank2_doutb,
  output logic bank3_ena,output logic[127:0]bank3_wea,output logic[31:0]bank3_addra,output logic[1023:0]bank3_dina,
  output logic bank3_enb,output logic[31:0]bank3_addrb,input logic[1023:0]bank3_doutb,
  output logic router_error,output logic[2:0]router_error_code,
  output logic[2:0]router_error_owner,output logic[3:0]router_error_bank
);
  import bank_config_pkg::*;
  localparam logic[2:0] ERR_NONE=0,ERR_INACTIVE_OR_RANGE=1,ERR_ROLE_UNSUPPORTED=2;
  localparam logic[2:0] ERR_BANK_NOT_BUSY=3,ERR_OWNER_MISMATCH=4,ERR_COLLISION=5;
  logic mm2s_range_w,mm2s_capable_w,mm2s_auth_w;
  logic s2mm_auth_w,act_auth_w,wgt_auth_w,out_auth_w,bank3_read_collision_w;
  logic fault_valid_w;logic[2:0]fault_code_w,fault_owner_w;logic[3:0]fault_bank_w;
  logic[BANK_READ_LATENCY-1:0]s2mm_pipe_r,act_pipe_r,wgt_pipe_r,out_pipe_r;

  always_comb begin
    mm2s_range_w=({1'b0,mm2s_write_bank}<5'd16);
    mm2s_capable_w=mm2s_range_w&&bank_active(integer'(mm2s_write_bank))&&bank_allows_mm2s(integer'(mm2s_write_bank));
    mm2s_auth_w=1'b0;if(mm2s_capable_w)mm2s_auth_w=bank_busy[mm2s_write_bank]&&(bank_owner_port[mm2s_write_bank]==OWNER_MM2S);
    s2mm_auth_w=bank_busy[3]&&(bank_owner_port[3]==OWNER_S2MM);
    act_auth_w=bank_busy[1]&&(bank_owner_port[1]==OWNER_SA_ACT);
    wgt_auth_w=bank_busy[2]&&(bank_owner_port[2]==OWNER_SA_WGT);
    out_auth_w=bank_busy[3]&&(bank_owner_port[3]==OWNER_SA_OUT);
    bank3_read_collision_w=s2mm_read_valid&&sa_out_read_valid;
    mm2s_write_ready=mm2s_auth_w;
    s2mm_read_ready=s2mm_auth_w&&!bank3_read_collision_w;
    sa_act_read_ready=act_auth_w;sa_wgt_read_ready=wgt_auth_w;
    sa_out_read_ready=out_auth_w&&!bank3_read_collision_w;sa_out_write_ready=out_auth_w;
    bank0_ena=0;bank0_wea=mm2s_write_strb;bank0_addra=mm2s_write_addr;bank0_dina=mm2s_write_data;
    bank1_ena=0;bank1_wea=mm2s_write_strb;bank1_addra=mm2s_write_addr;bank1_dina=mm2s_write_data;
    bank1_enb=0;bank1_addrb=sa_act_read_addr;
    bank2_ena=0;bank2_wea=mm2s_write_strb;bank2_addra=mm2s_write_addr;bank2_dina=mm2s_write_data;
    bank2_enb=0;bank2_addrb=sa_wgt_read_addr;
    bank3_ena=0;bank3_wea=sa_out_write_strb;bank3_addra=sa_out_write_addr;bank3_dina=sa_out_write_data;
    bank3_enb=0;bank3_addrb=s2mm_read_addr;
    if(mm2s_write_valid&&mm2s_write_ready)case(mm2s_write_bank)
      0:bank0_ena=1;
      1:bank1_ena=1;
      2:bank2_ena=1;
      default:begin end
    endcase
    if(sa_act_read_valid&&sa_act_read_ready)bank1_enb=1;
    if(sa_wgt_read_valid&&sa_wgt_read_ready)bank2_enb=1;
    if(s2mm_read_valid&&s2mm_read_ready)bank3_enb=1;
    if(sa_out_read_valid&&sa_out_read_ready)begin bank3_enb=1;bank3_addrb=sa_out_read_addr;end
    if(sa_out_write_valid&&sa_out_write_ready)bank3_ena=1;

    fault_valid_w=0;fault_code_w=ERR_NONE;fault_owner_w=0;fault_bank_w=0;
    if(mm2s_write_valid&&!mm2s_write_ready)begin fault_valid_w=1;fault_owner_w=OWNER_MM2S;fault_bank_w=mm2s_write_bank;
      if(!mm2s_range_w||!bank_active(integer'(mm2s_write_bank)))fault_code_w=ERR_INACTIVE_OR_RANGE;
      else if(!bank_allows_mm2s(integer'(mm2s_write_bank)))fault_code_w=ERR_ROLE_UNSUPPORTED;
      else if(!bank_busy[mm2s_write_bank])fault_code_w=ERR_BANK_NOT_BUSY;else fault_code_w=ERR_OWNER_MISMATCH;end
    if(!fault_valid_w&&s2mm_read_valid&&!s2mm_read_ready)begin fault_valid_w=1;fault_owner_w=OWNER_S2MM;fault_bank_w=3;
      if(bank3_read_collision_w)fault_code_w=ERR_COLLISION;else if(!bank_busy[3])fault_code_w=ERR_BANK_NOT_BUSY;else fault_code_w=ERR_OWNER_MISMATCH;end
    if(!fault_valid_w&&sa_act_read_valid&&!sa_act_read_ready)begin fault_valid_w=1;fault_owner_w=OWNER_SA_ACT;fault_bank_w=1;
      if(!bank_busy[1])fault_code_w=ERR_BANK_NOT_BUSY;else fault_code_w=ERR_OWNER_MISMATCH;end
    if(!fault_valid_w&&sa_wgt_read_valid&&!sa_wgt_read_ready)begin fault_valid_w=1;fault_owner_w=OWNER_SA_WGT;fault_bank_w=2;
      if(!bank_busy[2])fault_code_w=ERR_BANK_NOT_BUSY;else fault_code_w=ERR_OWNER_MISMATCH;end
    if(!fault_valid_w&&sa_out_read_valid&&!sa_out_read_ready)begin fault_valid_w=1;fault_owner_w=OWNER_SA_OUT;fault_bank_w=3;
      if(bank3_read_collision_w)fault_code_w=ERR_COLLISION;else if(!bank_busy[3])fault_code_w=ERR_BANK_NOT_BUSY;else fault_code_w=ERR_OWNER_MISMATCH;end
    if(!fault_valid_w&&sa_out_write_valid&&!sa_out_write_ready)begin fault_valid_w=1;fault_owner_w=OWNER_SA_OUT;fault_bank_w=3;
      if(!bank_busy[3])fault_code_w=ERR_BANK_NOT_BUSY;else fault_code_w=ERR_OWNER_MISMATCH;end
  end
  assign s2mm_rsp_valid=s2mm_pipe_r[BANK_READ_LATENCY-1];assign s2mm_rsp_data=bank3_doutb;
  assign sa_act_rsp_valid=act_pipe_r[BANK_READ_LATENCY-1];assign sa_act_rsp_data=bank1_doutb;
  assign sa_wgt_rsp_valid=wgt_pipe_r[BANK_READ_LATENCY-1];assign sa_wgt_rsp_data=bank2_doutb;
  assign sa_out_rsp_valid=out_pipe_r[BANK_READ_LATENCY-1];assign sa_out_rsp_data=bank3_doutb;
  always_ff @(posedge aclk)begin
    if(!aresetn)begin s2mm_pipe_r<='0;act_pipe_r<='0;wgt_pipe_r<='0;out_pipe_r<='0;
      router_error<=0;router_error_code<=0;router_error_owner<=0;router_error_bank<=0;end
    else begin
      s2mm_pipe_r<={s2mm_pipe_r[BANK_READ_LATENCY-2:0],s2mm_read_valid&&s2mm_read_ready};
      act_pipe_r<={act_pipe_r[BANK_READ_LATENCY-2:0],sa_act_read_valid&&sa_act_read_ready};
      wgt_pipe_r<={wgt_pipe_r[BANK_READ_LATENCY-2:0],sa_wgt_read_valid&&sa_wgt_read_ready};
      out_pipe_r<={out_pipe_r[BANK_READ_LATENCY-2:0],sa_out_read_valid&&sa_out_read_ready};
      if(!router_error&&fault_valid_w)begin router_error<=1;router_error_code<=fault_code_w;router_error_owner<=fault_owner_w;router_error_bank<=fault_bank_w;end
    end
  end
endmodule
