`timescale 1ns/1ps
package attention_tensor_pkg;
  localparam int BANK_NUM = 19;
  localparam int BANK_ID_WIDTH = 5;
  localparam int ROLE_WIDTH = 3;
  localparam int BANK_WORD_WIDTH = 128;
  localparam int BANK_READ_LATENCY = 3;
  localparam logic [2:0] FMT_F32 = 3'd0;
  localparam logic [2:0] FMT_BF16 = 3'd1;
  localparam logic [2:0] FMT_U8 = 3'd2;
  localparam logic [2:0] FMT_I4_ROW = 3'd3;
  localparam logic [2:0] FMT_I4_HEAD = 3'd4;
  localparam logic [2:0] FMT_I4_GROUP32 = 3'd5;
  localparam logic [7:0] OP_END = 8'd0;
  localparam logic [7:0] OP_MM2S = 8'd1;
  localparam logic [7:0] OP_S2MM = 8'd2;
  localparam logic [7:0] OP_QUANTIZE = 8'd3;
  localparam logic [7:0] OP_PROJECT = 8'd4;
  localparam logic [7:0] OP_QK = 8'd5;
  localparam logic [7:0] OP_SOFTMAX = 8'd6;
  localparam logic [7:0] OP_PV = 8'd7;
  localparam logic [ROLE_WIDTH-1:0] OWNER_MM2S = 3'd1;
  localparam logic [ROLE_WIDTH-1:0] OWNER_S2MM = 3'd2;
  localparam logic [ROLE_WIDTH-1:0] OWNER_SRC0 = 3'd3;
  localparam logic [ROLE_WIDTH-1:0] OWNER_SRC1 = 3'd4;
  localparam logic [ROLE_WIDTH-1:0] OWNER_DST = 3'd5;
  // Header then seven 32-bit fields, exactly 256 bits MSB to LSB.
  typedef struct packed {
    logic valid;
    logic [2:0] format;
    logic [1:0] rank;
    logic [25:0] reserved;
    logic [31:0] dim0;
    logic [31:0] dim1;
    logic [31:0] dim2;
    logic [31:0] data_bytes;
    logic [31:0] scale_offset;
    logic [31:0] scale_count;
    logic [31:0] capacity_bytes;
  } tensor_desc_t;
endpackage
