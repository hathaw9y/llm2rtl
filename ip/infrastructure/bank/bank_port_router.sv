`timescale 1ns / 1ps

module bank_port_router #(
    parameter integer BANK_NUM = 16,
    parameter integer BANK_NUM_WIDTH = 4,
    parameter integer PORT_ROLE_WIDTH = 3,
    parameter integer ADDR_WIDTH = 32,
    parameter integer WRITE_DATA_WIDTH = 128,
    parameter integer READ_DATA_WIDTH = 128,
    parameter integer BYTE_WRITE_WIDTH = 8,
    parameter integer READ_LATENCY = 3,
    parameter logic [PORT_ROLE_WIDTH-1:0] OWNER_MM2S_ARBITER = 1,
    parameter logic [PORT_ROLE_WIDTH-1:0] OWNER_S2MM_ARBITER = 2,
    parameter logic [PORT_ROLE_WIDTH-1:0] OWNER_GEMM_ACT = 3,
    parameter logic [PORT_ROLE_WIDTH-1:0] OWNER_GEMM_WGT = 4,
    parameter logic [PORT_ROLE_WIDTH-1:0] OWNER_GEMM_PSUM = 5
) (
    input logic aclk,
    input logic aresetn,

    input logic [0:BANK_NUM-1] bank_busy,
    input logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_owner_port,

    input logic mm2s_write_valid,
    output logic mm2s_write_ready,
    input logic [BANK_NUM_WIDTH-1:0] mm2s_write_bank,
    input logic [ADDR_WIDTH-1:0] mm2s_write_addr,
    input logic [(WRITE_DATA_WIDTH/BYTE_WRITE_WIDTH)-1:0] mm2s_write_strb,
    input logic [WRITE_DATA_WIDTH-1:0] mm2s_write_data,

    input logic s2mm_read_valid,
    output logic s2mm_read_ready,
    input logic [BANK_NUM_WIDTH-1:0] s2mm_read_bank,
    input logic [ADDR_WIDTH-1:0] s2mm_read_addr,
    output logic s2mm_rsp_valid,
    output logic [BANK_NUM_WIDTH-1:0] s2mm_rsp_bank,
    output logic [READ_DATA_WIDTH-1:0] s2mm_rsp_data,

    input logic gemm_act_read_valid,
    output logic gemm_act_read_ready,
    input logic [BANK_NUM_WIDTH-1:0] gemm_act_read_bank,
    input logic [ADDR_WIDTH-1:0] gemm_act_read_addr,
    output logic gemm_act_rsp_valid,
    output logic [BANK_NUM_WIDTH-1:0] gemm_act_rsp_bank,
    output logic [READ_DATA_WIDTH-1:0] gemm_act_rsp_data,

    input logic gemm_wgt_read_valid,
    output logic gemm_wgt_read_ready,
    input logic [BANK_NUM_WIDTH-1:0] gemm_wgt_read_bank,
    input logic [ADDR_WIDTH-1:0] gemm_wgt_read_addr,
    output logic gemm_wgt_rsp_valid,
    output logic [BANK_NUM_WIDTH-1:0] gemm_wgt_rsp_bank,
    output logic [READ_DATA_WIDTH-1:0] gemm_wgt_rsp_data,

    input logic gemm_psum_read_valid,
    output logic gemm_psum_read_ready,
    input logic [BANK_NUM_WIDTH-1:0] gemm_psum_read_bank,
    input logic [ADDR_WIDTH-1:0] gemm_psum_read_addr,
    output logic gemm_psum_rsp_valid,
    output logic [BANK_NUM_WIDTH-1:0] gemm_psum_rsp_bank,
    output logic [READ_DATA_WIDTH-1:0] gemm_psum_rsp_data,

    input logic gemm_psum_write_valid,
    output logic gemm_psum_write_ready,
    input logic [BANK_NUM_WIDTH-1:0] gemm_psum_write_bank,
    input logic [ADDR_WIDTH-1:0] gemm_psum_write_addr,
    input logic [(WRITE_DATA_WIDTH/BYTE_WRITE_WIDTH)-1:0] gemm_psum_write_strb,
    input logic [WRITE_DATA_WIDTH-1:0] gemm_psum_write_data,

    output logic [0:BANK_NUM-1] bank_ena,
    output logic [0:BANK_NUM-1][(WRITE_DATA_WIDTH/BYTE_WRITE_WIDTH)-1:0] bank_wea,
    output logic [0:BANK_NUM-1][ADDR_WIDTH-1:0] bank_addra,
    output logic [0:BANK_NUM-1][WRITE_DATA_WIDTH-1:0] bank_dina,
    output logic [0:BANK_NUM-1] bank_enb,
    output logic [0:BANK_NUM-1][ADDR_WIDTH-1:0] bank_addrb,
    input logic [0:BANK_NUM-1][READ_DATA_WIDTH-1:0] bank_doutb,

    output logic router_error,
    output logic [2:0] router_error_code,
    output logic [PORT_ROLE_WIDTH-1:0] router_error_owner,
    output logic [BANK_NUM_WIDTH-1:0] router_error_bank
);
  localparam integer WRITE_STROBE_WIDTH = WRITE_DATA_WIDTH / BYTE_WRITE_WIDTH;
  localparam logic [2:0] ERR_NONE = 3'd0;
  localparam logic [2:0] ERR_BANK_OUT_OF_RANGE = 3'd1;
  localparam logic [2:0] ERR_BANK_NOT_BUSY = 3'd2;
  localparam logic [2:0] ERR_OWNER_MISMATCH = 3'd3;
  localparam logic [2:0] ERR_WRITE_COLLISION = 3'd4;
  localparam logic [2:0] ERR_READ_COLLISION = 3'd5;
  localparam logic [BANK_NUM_WIDTH:0] BANK_NUM_LIMIT = (BANK_NUM_WIDTH + 1)'(BANK_NUM);
  localparam integer REQUIRED_BANK_WIDTH = (BANK_NUM <= 1) ? 1 : $clog2(BANK_NUM);
  localparam logic PARAMETERS_LEGAL =
      (BANK_NUM >= 1) && (BANK_NUM_WIDTH >= REQUIRED_BANK_WIDTH) &&
      (PORT_ROLE_WIDTH >= 3) && (READ_LATENCY >= 1) &&
      (WRITE_DATA_WIDTH > 0) && (READ_DATA_WIDTH > 0) &&
      (BYTE_WRITE_WIDTH > 0) && ((WRITE_DATA_WIDTH % BYTE_WRITE_WIDTH) == 0) &&
      (OWNER_MM2S_ARBITER != 0) && (OWNER_S2MM_ARBITER != 0) &&
      (OWNER_GEMM_ACT != 0) && (OWNER_GEMM_WGT != 0) &&
      (OWNER_GEMM_PSUM != 0) &&
      (OWNER_MM2S_ARBITER != OWNER_S2MM_ARBITER) &&
      (OWNER_MM2S_ARBITER != OWNER_GEMM_ACT) &&
      (OWNER_MM2S_ARBITER != OWNER_GEMM_WGT) &&
      (OWNER_MM2S_ARBITER != OWNER_GEMM_PSUM) &&
      (OWNER_S2MM_ARBITER != OWNER_GEMM_ACT) &&
      (OWNER_S2MM_ARBITER != OWNER_GEMM_WGT) &&
      (OWNER_S2MM_ARBITER != OWNER_GEMM_PSUM) &&
      (OWNER_GEMM_ACT != OWNER_GEMM_WGT) &&
      (OWNER_GEMM_ACT != OWNER_GEMM_PSUM) &&
      (OWNER_GEMM_WGT != OWNER_GEMM_PSUM);

  logic mm2s_in_range_w, s2mm_in_range_w, act_in_range_w, wgt_in_range_w;
  logic psum_read_in_range_w, psum_write_in_range_w;
  logic mm2s_authorized_w, s2mm_authorized_w, act_authorized_w, wgt_authorized_w;
  logic psum_read_authorized_w, psum_write_authorized_w;
  logic mm2s_write_collision_w, psum_write_collision_w;
  logic s2mm_read_collision_w, act_read_collision_w, wgt_read_collision_w;
  logic psum_read_collision_w;
  logic fault_valid_w;
  logic [2:0] fault_code_w;
  logic [PORT_ROLE_WIDTH-1:0] fault_owner_w;
  logic [BANK_NUM_WIDTH-1:0] fault_bank_w;
  logic [READ_LATENCY-1:0] s2mm_valid_pipe_r, act_valid_pipe_r;
  logic [READ_LATENCY-1:0] wgt_valid_pipe_r, psum_valid_pipe_r;
  logic [BANK_NUM_WIDTH-1:0] s2mm_bank_pipe_r[0:READ_LATENCY-1];
  logic [BANK_NUM_WIDTH-1:0] act_bank_pipe_r[0:READ_LATENCY-1];
  logic [BANK_NUM_WIDTH-1:0] wgt_bank_pipe_r[0:READ_LATENCY-1];
  logic [BANK_NUM_WIDTH-1:0] psum_bank_pipe_r[0:READ_LATENCY-1];
  integer pipe_idx;

  always_comb begin
    mm2s_in_range_w = ({1'b0, mm2s_write_bank} < BANK_NUM_LIMIT);
    s2mm_in_range_w = ({1'b0, s2mm_read_bank} < BANK_NUM_LIMIT);
    act_in_range_w = ({1'b0, gemm_act_read_bank} < BANK_NUM_LIMIT);
    wgt_in_range_w = ({1'b0, gemm_wgt_read_bank} < BANK_NUM_LIMIT);
    psum_read_in_range_w = ({1'b0, gemm_psum_read_bank} < BANK_NUM_LIMIT);
    psum_write_in_range_w = ({1'b0, gemm_psum_write_bank} < BANK_NUM_LIMIT);

    mm2s_authorized_w = 1'b0;
    s2mm_authorized_w = 1'b0;
    act_authorized_w = 1'b0;
    wgt_authorized_w = 1'b0;
    psum_read_authorized_w = 1'b0;
    psum_write_authorized_w = 1'b0;
    if (mm2s_in_range_w) mm2s_authorized_w = bank_busy[mm2s_write_bank] && (bank_owner_port[mm2s_write_bank] == OWNER_MM2S_ARBITER);
    if (s2mm_in_range_w) s2mm_authorized_w = bank_busy[s2mm_read_bank] && (bank_owner_port[s2mm_read_bank] == OWNER_S2MM_ARBITER);
    if (act_in_range_w) act_authorized_w = bank_busy[gemm_act_read_bank] && (bank_owner_port[gemm_act_read_bank] == OWNER_GEMM_ACT);
    if (wgt_in_range_w) wgt_authorized_w = bank_busy[gemm_wgt_read_bank] && (bank_owner_port[gemm_wgt_read_bank] == OWNER_GEMM_WGT);
    if (psum_read_in_range_w) psum_read_authorized_w = bank_busy[gemm_psum_read_bank] && (bank_owner_port[gemm_psum_read_bank] == OWNER_GEMM_PSUM);
    if (psum_write_in_range_w)
      psum_write_authorized_w = bank_busy[gemm_psum_write_bank] && (bank_owner_port[gemm_psum_write_bank] == OWNER_GEMM_PSUM);

    mm2s_write_collision_w = mm2s_write_valid && gemm_psum_write_valid &&
        mm2s_in_range_w && psum_write_in_range_w &&
        (mm2s_write_bank == gemm_psum_write_bank);
    psum_write_collision_w = mm2s_write_collision_w;
    s2mm_read_collision_w = s2mm_read_valid &&
        ((gemm_act_read_valid && act_in_range_w && s2mm_in_range_w && (s2mm_read_bank == gemm_act_read_bank)) ||
         (gemm_wgt_read_valid && wgt_in_range_w && s2mm_in_range_w && (s2mm_read_bank == gemm_wgt_read_bank)) ||
         (gemm_psum_read_valid && psum_read_in_range_w && s2mm_in_range_w && (s2mm_read_bank == gemm_psum_read_bank)));
    act_read_collision_w = gemm_act_read_valid &&
        ((s2mm_read_valid && s2mm_in_range_w && act_in_range_w && (gemm_act_read_bank == s2mm_read_bank)) ||
         (gemm_wgt_read_valid && wgt_in_range_w && act_in_range_w && (gemm_act_read_bank == gemm_wgt_read_bank)) ||
         (gemm_psum_read_valid && psum_read_in_range_w && act_in_range_w && (gemm_act_read_bank == gemm_psum_read_bank)));
    wgt_read_collision_w = gemm_wgt_read_valid &&
        ((s2mm_read_valid && s2mm_in_range_w && wgt_in_range_w && (gemm_wgt_read_bank == s2mm_read_bank)) ||
         (gemm_act_read_valid && act_in_range_w && wgt_in_range_w && (gemm_wgt_read_bank == gemm_act_read_bank)) ||
         (gemm_psum_read_valid && psum_read_in_range_w && wgt_in_range_w && (gemm_wgt_read_bank == gemm_psum_read_bank)));
    psum_read_collision_w = gemm_psum_read_valid &&
        ((s2mm_read_valid && s2mm_in_range_w && psum_read_in_range_w && (gemm_psum_read_bank == s2mm_read_bank)) ||
         (gemm_act_read_valid && act_in_range_w && psum_read_in_range_w && (gemm_psum_read_bank == gemm_act_read_bank)) ||
         (gemm_wgt_read_valid && wgt_in_range_w && psum_read_in_range_w && (gemm_psum_read_bank == gemm_wgt_read_bank)));

    mm2s_write_ready = PARAMETERS_LEGAL && mm2s_authorized_w && !mm2s_write_collision_w;
    s2mm_read_ready = PARAMETERS_LEGAL && s2mm_authorized_w && !s2mm_read_collision_w;
    gemm_act_read_ready = PARAMETERS_LEGAL && act_authorized_w && !act_read_collision_w;
    gemm_wgt_read_ready = PARAMETERS_LEGAL && wgt_authorized_w && !wgt_read_collision_w;
    gemm_psum_read_ready = PARAMETERS_LEGAL && psum_read_authorized_w && !psum_read_collision_w;
    gemm_psum_write_ready = PARAMETERS_LEGAL && psum_write_authorized_w && !psum_write_collision_w;

    bank_ena = '0;
    bank_wea = '0;
    bank_addra = '0;
    bank_dina = '0;
    bank_enb = '0;
    bank_addrb = '0;
    if (mm2s_write_valid && mm2s_write_ready) begin
      bank_ena[mm2s_write_bank]   = 1'b1;
      bank_wea[mm2s_write_bank]   = mm2s_write_strb;
      bank_addra[mm2s_write_bank] = mm2s_write_addr;
      bank_dina[mm2s_write_bank]  = mm2s_write_data;
    end
    if (gemm_psum_write_valid && gemm_psum_write_ready) begin
      bank_ena[gemm_psum_write_bank]   = 1'b1;
      bank_wea[gemm_psum_write_bank]   = gemm_psum_write_strb;
      bank_addra[gemm_psum_write_bank] = gemm_psum_write_addr;
      bank_dina[gemm_psum_write_bank]  = gemm_psum_write_data;
    end
    if (s2mm_read_valid && s2mm_read_ready) begin
      bank_enb[s2mm_read_bank]   = 1'b1;
      bank_addrb[s2mm_read_bank] = s2mm_read_addr;
    end
    if (gemm_act_read_valid && gemm_act_read_ready) begin
      bank_enb[gemm_act_read_bank]   = 1'b1;
      bank_addrb[gemm_act_read_bank] = gemm_act_read_addr;
    end
    if (gemm_wgt_read_valid && gemm_wgt_read_ready) begin
      bank_enb[gemm_wgt_read_bank]   = 1'b1;
      bank_addrb[gemm_wgt_read_bank] = gemm_wgt_read_addr;
    end
    if (gemm_psum_read_valid && gemm_psum_read_ready) begin
      bank_enb[gemm_psum_read_bank]   = 1'b1;
      bank_addrb[gemm_psum_read_bank] = gemm_psum_read_addr;
    end

    fault_valid_w = 1'b0;
    fault_code_w  = ERR_NONE;
    fault_owner_w = '0;
    fault_bank_w  = '0;
    if (mm2s_write_valid) begin
      if (!mm2s_in_range_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_OUT_OF_RANGE;
        fault_owner_w = OWNER_MM2S_ARBITER;
        fault_bank_w  = mm2s_write_bank;
      end else if (mm2s_write_collision_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_WRITE_COLLISION;
        fault_owner_w = OWNER_MM2S_ARBITER;
        fault_bank_w  = mm2s_write_bank;
      end else if (!bank_busy[mm2s_write_bank]) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_NOT_BUSY;
        fault_owner_w = OWNER_MM2S_ARBITER;
        fault_bank_w  = mm2s_write_bank;
      end else if (bank_owner_port[mm2s_write_bank] != OWNER_MM2S_ARBITER) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_OWNER_MISMATCH;
        fault_owner_w = OWNER_MM2S_ARBITER;
        fault_bank_w  = mm2s_write_bank;
      end
    end
    if (!fault_valid_w && s2mm_read_valid) begin
      if (!s2mm_in_range_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_OUT_OF_RANGE;
        fault_owner_w = OWNER_S2MM_ARBITER;
        fault_bank_w  = s2mm_read_bank;
      end else if (s2mm_read_collision_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_READ_COLLISION;
        fault_owner_w = OWNER_S2MM_ARBITER;
        fault_bank_w  = s2mm_read_bank;
      end else if (!bank_busy[s2mm_read_bank]) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_NOT_BUSY;
        fault_owner_w = OWNER_S2MM_ARBITER;
        fault_bank_w  = s2mm_read_bank;
      end else if (bank_owner_port[s2mm_read_bank] != OWNER_S2MM_ARBITER) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_OWNER_MISMATCH;
        fault_owner_w = OWNER_S2MM_ARBITER;
        fault_bank_w  = s2mm_read_bank;
      end
    end
    if (!fault_valid_w && gemm_act_read_valid) begin
      if (!act_in_range_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_OUT_OF_RANGE;
        fault_owner_w = OWNER_GEMM_ACT;
        fault_bank_w  = gemm_act_read_bank;
      end else if (act_read_collision_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_READ_COLLISION;
        fault_owner_w = OWNER_GEMM_ACT;
        fault_bank_w  = gemm_act_read_bank;
      end else if (!bank_busy[gemm_act_read_bank]) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_NOT_BUSY;
        fault_owner_w = OWNER_GEMM_ACT;
        fault_bank_w  = gemm_act_read_bank;
      end else if (bank_owner_port[gemm_act_read_bank] != OWNER_GEMM_ACT) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_OWNER_MISMATCH;
        fault_owner_w = OWNER_GEMM_ACT;
        fault_bank_w  = gemm_act_read_bank;
      end
    end
    if (!fault_valid_w && gemm_wgt_read_valid) begin
      if (!wgt_in_range_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_OUT_OF_RANGE;
        fault_owner_w = OWNER_GEMM_WGT;
        fault_bank_w  = gemm_wgt_read_bank;
      end else if (wgt_read_collision_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_READ_COLLISION;
        fault_owner_w = OWNER_GEMM_WGT;
        fault_bank_w  = gemm_wgt_read_bank;
      end else if (!bank_busy[gemm_wgt_read_bank]) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_NOT_BUSY;
        fault_owner_w = OWNER_GEMM_WGT;
        fault_bank_w  = gemm_wgt_read_bank;
      end else if (bank_owner_port[gemm_wgt_read_bank] != OWNER_GEMM_WGT) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_OWNER_MISMATCH;
        fault_owner_w = OWNER_GEMM_WGT;
        fault_bank_w  = gemm_wgt_read_bank;
      end
    end
    if (!fault_valid_w && gemm_psum_write_valid) begin
      if (!psum_write_in_range_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_OUT_OF_RANGE;
        fault_owner_w = OWNER_GEMM_PSUM;
        fault_bank_w  = gemm_psum_write_bank;
      end else if (psum_write_collision_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_WRITE_COLLISION;
        fault_owner_w = OWNER_GEMM_PSUM;
        fault_bank_w  = gemm_psum_write_bank;
      end else if (!bank_busy[gemm_psum_write_bank]) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_NOT_BUSY;
        fault_owner_w = OWNER_GEMM_PSUM;
        fault_bank_w  = gemm_psum_write_bank;
      end else if (bank_owner_port[gemm_psum_write_bank] != OWNER_GEMM_PSUM) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_OWNER_MISMATCH;
        fault_owner_w = OWNER_GEMM_PSUM;
        fault_bank_w  = gemm_psum_write_bank;
      end
    end
    if (!fault_valid_w && gemm_psum_read_valid) begin
      if (!psum_read_in_range_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_OUT_OF_RANGE;
        fault_owner_w = OWNER_GEMM_PSUM;
        fault_bank_w  = gemm_psum_read_bank;
      end else if (psum_read_collision_w) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_READ_COLLISION;
        fault_owner_w = OWNER_GEMM_PSUM;
        fault_bank_w  = gemm_psum_read_bank;
      end else if (!bank_busy[gemm_psum_read_bank]) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_BANK_NOT_BUSY;
        fault_owner_w = OWNER_GEMM_PSUM;
        fault_bank_w  = gemm_psum_read_bank;
      end else if (bank_owner_port[gemm_psum_read_bank] != OWNER_GEMM_PSUM) begin
        fault_valid_w = 1;
        fault_code_w  = ERR_OWNER_MISMATCH;
        fault_owner_w = OWNER_GEMM_PSUM;
        fault_bank_w  = gemm_psum_read_bank;
      end
    end
  end

  assign s2mm_rsp_valid = s2mm_valid_pipe_r[READ_LATENCY-1];
  assign gemm_act_rsp_valid = act_valid_pipe_r[READ_LATENCY-1];
  assign gemm_wgt_rsp_valid = wgt_valid_pipe_r[READ_LATENCY-1];
  assign gemm_psum_rsp_valid = psum_valid_pipe_r[READ_LATENCY-1];
  assign s2mm_rsp_bank = s2mm_bank_pipe_r[READ_LATENCY-1];
  assign gemm_act_rsp_bank = act_bank_pipe_r[READ_LATENCY-1];
  assign gemm_wgt_rsp_bank = wgt_bank_pipe_r[READ_LATENCY-1];
  assign gemm_psum_rsp_bank = psum_bank_pipe_r[READ_LATENCY-1];
  assign s2mm_rsp_data = s2mm_rsp_valid ? bank_doutb[s2mm_rsp_bank] : '0;
  assign gemm_act_rsp_data = gemm_act_rsp_valid ? bank_doutb[gemm_act_rsp_bank] : '0;
  assign gemm_wgt_rsp_data = gemm_wgt_rsp_valid ? bank_doutb[gemm_wgt_rsp_bank] : '0;
  assign gemm_psum_rsp_data = gemm_psum_rsp_valid ? bank_doutb[gemm_psum_rsp_bank] : '0;

`ifndef SYNTHESIS
  initial if (!PARAMETERS_LEGAL) $error("bank_port_router illegal parameters");
`endif

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      s2mm_valid_pipe_r <= '0;
      act_valid_pipe_r  <= '0;
      wgt_valid_pipe_r  <= '0;
      psum_valid_pipe_r <= '0;
      for (pipe_idx = 0; pipe_idx < READ_LATENCY; pipe_idx = pipe_idx + 1) begin
        s2mm_bank_pipe_r[pipe_idx] <= '0;
        act_bank_pipe_r[pipe_idx]  <= '0;
        wgt_bank_pipe_r[pipe_idx]  <= '0;
        psum_bank_pipe_r[pipe_idx] <= '0;
      end
      router_error <= 1'b0;
      router_error_code <= ERR_NONE;
      router_error_owner <= '0;
      router_error_bank <= '0;
    end else begin
      s2mm_valid_pipe_r[0] <= s2mm_read_valid && s2mm_read_ready;
      act_valid_pipe_r[0]  <= gemm_act_read_valid && gemm_act_read_ready;
      wgt_valid_pipe_r[0]  <= gemm_wgt_read_valid && gemm_wgt_read_ready;
      psum_valid_pipe_r[0] <= gemm_psum_read_valid && gemm_psum_read_ready;
      s2mm_bank_pipe_r[0]  <= s2mm_read_bank;
      act_bank_pipe_r[0]   <= gemm_act_read_bank;
      wgt_bank_pipe_r[0]   <= gemm_wgt_read_bank;
      psum_bank_pipe_r[0]  <= gemm_psum_read_bank;
      for (pipe_idx = 1; pipe_idx < READ_LATENCY; pipe_idx = pipe_idx + 1) begin
        s2mm_valid_pipe_r[pipe_idx] <= s2mm_valid_pipe_r[pipe_idx-1];
        act_valid_pipe_r[pipe_idx]  <= act_valid_pipe_r[pipe_idx-1];
        wgt_valid_pipe_r[pipe_idx]  <= wgt_valid_pipe_r[pipe_idx-1];
        psum_valid_pipe_r[pipe_idx] <= psum_valid_pipe_r[pipe_idx-1];
        s2mm_bank_pipe_r[pipe_idx]  <= s2mm_bank_pipe_r[pipe_idx-1];
        act_bank_pipe_r[pipe_idx]   <= act_bank_pipe_r[pipe_idx-1];
        wgt_bank_pipe_r[pipe_idx]   <= wgt_bank_pipe_r[pipe_idx-1];
        psum_bank_pipe_r[pipe_idx]  <= psum_bank_pipe_r[pipe_idx-1];
      end
      if (!router_error && fault_valid_w) begin
        router_error <= 1'b1;
        router_error_code <= fault_code_w;
        router_error_owner <= fault_owner_w;
        router_error_bank <= fault_bank_w;
      end
    end
  end
endmodule
