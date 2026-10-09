`timescale 1ns/1ps
// Illustrative DMA-only configuration. Generate a design-owned copy before use.
package controller_test_config_pkg;
  localparam int BANK_NUM = 2;
  localparam int ROLE_WIDTH = 3;
  localparam int ADDR_WIDTH = 32;
  localparam int MAX_DATA_WIDTH = 128;
  localparam int MEMORY_READ_LATENCY = 3;
  localparam int TOTAL_READ_LATENCY = MEMORY_READ_LATENCY + 1;
  localparam logic [ROLE_WIDTH-1:0] OWNER_MM2S = 3'd1;
  localparam logic [ROLE_WIDTH-1:0] OWNER_S2MM = 3'd2;
  localparam int MEMORY_TYPES [0:BANK_NUM-1] = '{1,2}; // 0:none, 1:BRAM, 2:URAM
  localparam int WRITE_WIDTHS [0:BANK_NUM-1] = '{128,128};
  localparam int READ_WIDTHS [0:BANK_NUM-1] = '{128,128};
  localparam longint unsigned WRITE_DEPTHS [0:BANK_NUM-1] = '{64,4096};
  localparam int MM2S_BANK_NUM = 2;
  localparam int MM2S_BANK_COUNT = MM2S_BANK_NUM;
  localparam int S2MM_BANK_NUM = 2;
  localparam int S2MM_BANK_COUNT = S2MM_BANK_NUM;
  localparam int MM2S_DATA_WIDTH = 128;
  localparam int S2MM_DATA_WIDTH = 128;
  localparam int MM2S_BANK_IDS [0:MM2S_BANK_COUNT-1] = '{0,1};
  localparam int S2MM_BANK_IDS [0:S2MM_BANK_COUNT-1] = '{0,1};
  // Role 0 is reserved. Each bank's bit N permits role N in that direction.
  localparam logic [BANK_NUM-1:0][(1<<ROLE_WIDTH)-1:0] WR_CAPABILITIES = '{8'h12,8'h12};
  localparam logic [BANK_NUM-1:0][(1<<ROLE_WIDTH)-1:0] RD_CAPABILITIES = '{8'h0c,8'h0c};
  // USER_CONFIG_BEGIN
  // Agents add design-specific role IDs/configuration here and update masks above.
  // USER_CONFIG_END
endpackage
