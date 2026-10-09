`timescale 1ns/1ps
package bank_config_pkg;
  localparam integer BANK_NUM = 16;
  localparam integer BANK_ADDR_WIDTH = 32;
  localparam integer OPCODE_WIDTH = 4;
  localparam integer BANK_READ_LATENCY = 3;
  localparam integer PORT_ROLE_WIDTH = 3;

  typedef enum logic [1:0] {BANK_NONE=2'd0, BANK_BRAM=2'd1, BANK_URAM=2'd2} bank_type_t;

  localparam logic [PORT_ROLE_WIDTH-1:0] OWNER_NONE = 3'd0;
  localparam logic [PORT_ROLE_WIDTH-1:0] OWNER_MM2S = 3'd1;
  localparam logic [PORT_ROLE_WIDTH-1:0] OWNER_S2MM = 3'd2;
  localparam logic [PORT_ROLE_WIDTH-1:0] OWNER_SA_ACT = 3'd3;
  localparam logic [PORT_ROLE_WIDTH-1:0] OWNER_SA_WGT = 3'd4;
  localparam logic [PORT_ROLE_WIDTH-1:0] OWNER_SA_OUT = 3'd5;

  localparam logic [BANK_NUM-1:0] ACTIVE_BANK_MASK = 16'h000f;
  localparam logic [BANK_NUM-1:0] MM2S_BANK_MASK = 16'h0007;
  localparam logic [BANK_NUM-1:0] S2MM_BANK_MASK = 16'h0008;
  localparam logic [BANK_NUM-1:0] SA_ACT_BANK_MASK = 16'h0002;
  localparam logic [BANK_NUM-1:0] SA_WGT_BANK_MASK = 16'h0004;
  localparam logic [BANK_NUM-1:0] SA_OUT_BANK_MASK = 16'h0008;
  localparam integer MM2S_BANK_COUNT=3,S2MM_BANK_COUNT=1,SA_ACT_BANK_COUNT=1;
  localparam integer SA_WGT_BANK_COUNT=1,SA_OUT_BANK_COUNT=1;
  localparam logic [3:0] MM2S_BANK_IDS [0:2] = '{4'd0,4'd1,4'd2};
  localparam logic [3:0] S2MM_BANK_IDS [0:0] = '{4'd3};
  localparam logic [3:0] SA_ACT_BANK_IDS [0:0] = '{4'd1};
  localparam logic [3:0] SA_WGT_BANK_IDS [0:0] = '{4'd2};
  localparam logic [3:0] SA_OUT_BANK_IDS [0:0] = '{4'd3};

  function automatic logic bank_active(input integer bank_id);
    bank_active=(bank_id>=0)&&(bank_id<BANK_NUM)&&ACTIVE_BANK_MASK[bank_id];
  endfunction
  function automatic bank_type_t bank_type(input integer bank_id);
    case(bank_id) 0,1,3:bank_type=BANK_BRAM;2:bank_type=BANK_URAM;default:bank_type=BANK_NONE;endcase
  endfunction
  function automatic integer bank_write_width(input integer bank_id);
    case(bank_id) 0,1,2:bank_write_width=128;3:bank_write_width=1024;default:bank_write_width=0;endcase
  endfunction
  function automatic integer bank_read_width(input integer bank_id);
    case(bank_id) 0,2:bank_read_width=128;1:bank_read_width=256;3:bank_read_width=1024;default:bank_read_width=0;endcase
  endfunction
  function automatic integer bank_write_depth(input integer bank_id);
    case(bank_id) 0:bank_write_depth=2048;1:bank_write_depth=4096;2:bank_write_depth=65536;3:bank_write_depth=1024;default:bank_write_depth=0;endcase
  endfunction
  function automatic logic bank_allows_mm2s(input integer bank_id);
    bank_allows_mm2s=(bank_id>=0)&&(bank_id<BANK_NUM)&&MM2S_BANK_MASK[bank_id];
  endfunction
  function automatic logic bank_allows_s2mm(input integer bank_id);
    bank_allows_s2mm=(bank_id>=0)&&(bank_id<BANK_NUM)&&S2MM_BANK_MASK[bank_id];
  endfunction
  function automatic logic bank_allows_sa_act(input integer bank_id);
    bank_allows_sa_act=(bank_id>=0)&&(bank_id<BANK_NUM)&&SA_ACT_BANK_MASK[bank_id];
  endfunction
  function automatic logic bank_allows_sa_wgt(input integer bank_id);
    bank_allows_sa_wgt=(bank_id>=0)&&(bank_id<BANK_NUM)&&SA_WGT_BANK_MASK[bank_id];
  endfunction
  function automatic logic bank_allows_sa_out(input integer bank_id);
    bank_allows_sa_out=(bank_id>=0)&&(bank_id<BANK_NUM)&&SA_OUT_BANK_MASK[bank_id];
  endfunction
endpackage
