`timescale 1ns/1ps

module bank_subsystem (
    input  logic aclk,
    input  logic aresetn,
    input  logic [0:15] bank_acquire_valid,
    input  logic [0:15][2:0] bank_acquire_port,
    input  logic [0:15] bank_release_valid,
    input  logic [0:15][2:0] bank_release_port,
    output logic [0:15] bank_busy,
    output logic [0:15][2:0] bank_owner_port,

    input  logic mm2s_write_valid,
    output logic mm2s_write_ready,
    input  logic [3:0] mm2s_write_bank,
    input  logic [31:0] mm2s_write_addr,
    input  logic [15:0] mm2s_write_strb,
    input  logic [127:0] mm2s_write_data,
    input  logic s2mm_read_valid,
    output logic s2mm_read_ready,
    input  logic [31:0] s2mm_read_addr,
    output logic s2mm_rsp_valid,
    output logic [1023:0] s2mm_rsp_data,
    input  logic sa_act_read_valid,
    output logic sa_act_read_ready,
    input  logic [31:0] sa_act_read_addr,
    output logic sa_act_rsp_valid,
    output logic [255:0] sa_act_rsp_data,
    input  logic sa_wgt_read_valid,
    output logic sa_wgt_read_ready,
    input  logic [31:0] sa_wgt_read_addr,
    output logic sa_wgt_rsp_valid,
    output logic [127:0] sa_wgt_rsp_data,
    input  logic sa_out_read_valid,
    output logic sa_out_read_ready,
    input  logic [31:0] sa_out_read_addr,
    output logic sa_out_rsp_valid,
    output logic [1023:0] sa_out_rsp_data,
    input  logic sa_out_write_valid,
    output logic sa_out_write_ready,
    input  logic [31:0] sa_out_write_addr,
    input  logic [127:0] sa_out_write_strb,
    input  logic [1023:0] sa_out_write_data,

    output logic bank_subsystem_error,
    output logic [2:0] bank_subsystem_error_code,
    output logic ownership_error,
    output logic [2:0] ownership_error_code,
    output logic router_error,
    output logic [2:0] router_error_code
);
  import bank_config_pkg::*;

  localparam logic [2:0] SUBSYS_ERR_NONE       = 3'd0;
  localparam logic [2:0] SUBSYS_ERR_CAPABILITY = 3'd1;
  localparam logic [2:0] SUBSYS_ERR_OWNERSHIP  = 3'd2;
  localparam logic [2:0] SUBSYS_ERR_ROUTER     = 3'd3;

  logic [0:15] acquire_valid_gated_w, release_valid_gated_w;
  logic acquire_capability_error_w, release_capability_error_w;
  logic [2:0] router_error_owner_w;
  logic [3:0] router_error_bank_w;
  integer capability_idx;

  logic bank0_ena_w; logic [15:0] bank0_wea_w; logic [31:0] bank0_addra_w;
  logic [127:0] bank0_dina_w, bank0_doutb_w;
  logic bank1_ena_w; logic [15:0] bank1_wea_w; logic [31:0] bank1_addra_w;
  logic [127:0] bank1_dina_w; logic bank1_enb_w; logic [31:0] bank1_addrb_w;
  logic [255:0] bank1_doutb_w;
  logic bank2_ena_w; logic [15:0] bank2_wea_w; logic [31:0] bank2_addra_w;
  logic [127:0] bank2_dina_w; logic bank2_enb_w; logic [31:0] bank2_addrb_w;
  logic [127:0] bank2_doutb_w;
  logic bank3_ena_w; logic [127:0] bank3_wea_w; logic [31:0] bank3_addra_w;
  logic [1023:0] bank3_dina_w; logic bank3_enb_w; logic [31:0] bank3_addrb_w;
  logic [1023:0] bank3_doutb_w;

  function automatic logic supported_pair(input integer bank_id,
                                           input logic [2:0] owner);
    begin
      case (owner)
        OWNER_MM2S:  supported_pair = bank_allows_mm2s(bank_id);
        OWNER_S2MM:  supported_pair = bank_allows_s2mm(bank_id);
        OWNER_SA_ACT:supported_pair = bank_allows_sa_act(bank_id);
        OWNER_SA_WGT:supported_pair = bank_allows_sa_wgt(bank_id);
        OWNER_SA_OUT:supported_pair = bank_allows_sa_out(bank_id);
        default:     supported_pair = 1'b0;
      endcase
    end
  endfunction

  always_comb begin
    acquire_capability_error_w = 1'b0;
    release_capability_error_w = 1'b0;
    for (capability_idx = 0; capability_idx < 16; capability_idx = capability_idx + 1) begin
      if (bank_acquire_valid[capability_idx] &&
          (!bank_active(capability_idx) ||
           !supported_pair(capability_idx, bank_acquire_port[capability_idx])))
        acquire_capability_error_w = 1'b1;
      if (bank_release_valid[capability_idx] &&
          (!bank_active(capability_idx) ||
           !supported_pair(capability_idx, bank_release_port[capability_idx])))
        release_capability_error_w = 1'b1;
    end
    acquire_valid_gated_w = acquire_capability_error_w ? '0 : bank_acquire_valid;
    release_valid_gated_w = release_capability_error_w ? '0 : bank_release_valid;
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      bank_subsystem_error <= 1'b0;
      bank_subsystem_error_code <= SUBSYS_ERR_NONE;
    end else if (!bank_subsystem_error) begin
      if (acquire_capability_error_w || release_capability_error_w) begin
        bank_subsystem_error <= 1'b1;
        bank_subsystem_error_code <= SUBSYS_ERR_CAPABILITY;
      end else if (ownership_error) begin
        bank_subsystem_error <= 1'b1;
        bank_subsystem_error_code <= SUBSYS_ERR_OWNERSHIP;
      end else if (router_error) begin
        bank_subsystem_error <= 1'b1;
        bank_subsystem_error_code <= SUBSYS_ERR_ROUTER;
      end
    end
  end

  bank_ownership_table #(.BANK_NUM(16), .PORT_ROLE_WIDTH(3)) u_ownership (
      .aclk(aclk), .aresetn(aresetn),
      .acquire_valid(acquire_valid_gated_w), .acquire_port(bank_acquire_port),
      .release_valid(release_valid_gated_w), .release_port(bank_release_port),
      .bank_busy(bank_busy), .bank_owner_port(bank_owner_port),
      .ownership_error(ownership_error), .ownership_error_code(ownership_error_code));

  bank_sparse_router u_router (
      .aclk(aclk), .aresetn(aresetn), .bank_busy(bank_busy),
      .bank_owner_port(bank_owner_port),
      .mm2s_write_valid(mm2s_write_valid), .mm2s_write_ready(mm2s_write_ready),
      .mm2s_write_bank(mm2s_write_bank), .mm2s_write_addr(mm2s_write_addr),
      .mm2s_write_strb(mm2s_write_strb), .mm2s_write_data(mm2s_write_data),
      .s2mm_read_valid(s2mm_read_valid), .s2mm_read_ready(s2mm_read_ready),
      .s2mm_read_addr(s2mm_read_addr), .s2mm_rsp_valid(s2mm_rsp_valid),
      .s2mm_rsp_data(s2mm_rsp_data), .sa_act_read_valid(sa_act_read_valid),
      .sa_act_read_ready(sa_act_read_ready), .sa_act_read_addr(sa_act_read_addr),
      .sa_act_rsp_valid(sa_act_rsp_valid), .sa_act_rsp_data(sa_act_rsp_data),
      .sa_wgt_read_valid(sa_wgt_read_valid), .sa_wgt_read_ready(sa_wgt_read_ready),
      .sa_wgt_read_addr(sa_wgt_read_addr), .sa_wgt_rsp_valid(sa_wgt_rsp_valid),
      .sa_wgt_rsp_data(sa_wgt_rsp_data), .sa_out_read_valid(sa_out_read_valid),
      .sa_out_read_ready(sa_out_read_ready), .sa_out_read_addr(sa_out_read_addr),
      .sa_out_rsp_valid(sa_out_rsp_valid), .sa_out_rsp_data(sa_out_rsp_data),
      .sa_out_write_valid(sa_out_write_valid), .sa_out_write_ready(sa_out_write_ready),
      .sa_out_write_addr(sa_out_write_addr), .sa_out_write_strb(sa_out_write_strb),
      .sa_out_write_data(sa_out_write_data),
      .bank0_ena(bank0_ena_w), .bank0_wea(bank0_wea_w),
      .bank0_addra(bank0_addra_w), .bank0_dina(bank0_dina_w),
      .bank1_ena(bank1_ena_w), .bank1_wea(bank1_wea_w),
      .bank1_addra(bank1_addra_w), .bank1_dina(bank1_dina_w),
      .bank1_enb(bank1_enb_w), .bank1_addrb(bank1_addrb_w), .bank1_doutb(bank1_doutb_w),
      .bank2_ena(bank2_ena_w), .bank2_wea(bank2_wea_w),
      .bank2_addra(bank2_addra_w), .bank2_dina(bank2_dina_w),
      .bank2_enb(bank2_enb_w), .bank2_addrb(bank2_addrb_w), .bank2_doutb(bank2_doutb_w),
      .bank3_ena(bank3_ena_w), .bank3_wea(bank3_wea_w),
      .bank3_addra(bank3_addra_w), .bank3_dina(bank3_dina_w),
      .bank3_enb(bank3_enb_w), .bank3_addrb(bank3_addrb_w), .bank3_doutb(bank3_doutb_w),
      .router_error(router_error), .router_error_code(router_error_code),
      .router_error_owner(router_error_owner_w), .router_error_bank(router_error_bank_w));

  (* DONT_TOUCH = "yes" *) bram_bank #(.WRITE_DATA_WIDTH(128), .WRITE_DEPTH(2048),
      .READ_DATA_WIDTH(128), .BYTE_WRITE_WIDTH(8), .READ_LATENCY(3), .ADDR_WIDTH(32))
      u_bank0 (.aclk(aclk), .aresetn(aresetn), .ena(bank0_ena_w), .wea(bank0_wea_w),
      .addra(bank0_addra_w), .dina(bank0_dina_w), .enb(1'b0), .addrb(32'd0),
      .doutb(bank0_doutb_w));

  bram_bank #(.WRITE_DATA_WIDTH(128), .WRITE_DEPTH(4096),
      .READ_DATA_WIDTH(256), .BYTE_WRITE_WIDTH(8), .READ_LATENCY(3), .ADDR_WIDTH(32))
      u_bank1 (.aclk(aclk), .aresetn(aresetn), .ena(bank1_ena_w), .wea(bank1_wea_w),
      .addra(bank1_addra_w), .dina(bank1_dina_w), .enb(bank1_enb_w),
      .addrb(bank1_addrb_w), .doutb(bank1_doutb_w));

  uram_bank #(.DATA_WIDTH(128), .DEPTH(65536), .READ_LATENCY(3), .ADDR_WIDTH(32))
      u_bank2 (.aclk(aclk), .aresetn(aresetn), .ena(bank2_ena_w), .wea(bank2_wea_w),
      .addra(bank2_addra_w), .dina(bank2_dina_w), .enb(bank2_enb_w),
      .addrb(bank2_addrb_w), .doutb(bank2_doutb_w));

  bram_bank #(.WRITE_DATA_WIDTH(1024), .WRITE_DEPTH(1024),
      .READ_DATA_WIDTH(1024), .BYTE_WRITE_WIDTH(8), .READ_LATENCY(3), .ADDR_WIDTH(32))
      u_bank3 (.aclk(aclk), .aresetn(aresetn), .ena(bank3_ena_w), .wea(bank3_wea_w),
      .addra(bank3_addra_w), .dina(bank3_dina_w), .enb(bank3_enb_w),
      .addrb(bank3_addrb_w), .doutb(bank3_doutb_w));

endmodule
