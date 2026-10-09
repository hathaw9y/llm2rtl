`timescale 1ns/1ps
// Generated immutable configuration; descriptor source SHA256 f518c7b72912544ac8db2efc7bfbc869c7bc3c15645366d3156232b7103cb79e
package attention_tensor_config_pkg;
  import attention_tensor_pkg::*;
  localparam logic [5:0] CTX_TOKENS = 6'd4;
  localparam logic [2:0] CTX_HEADS = 3'd2;
  localparam logic [6:0] CTX_HEAD_DIM = 7'd3;
  localparam logic [5:0] CTX_QUERY_COUNT = 6'd3;
  localparam logic [0:0] CTX_CAUSAL = 1'd0;
  localparam logic [31:0] CTX_QK_FACTOR = 32'h3f13cd3a;
  localparam int BANK_DEPTHS [0:18] = '{64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64};
  function automatic tensor_desc_t get_descriptor(input logic [4:0] bank);
    case (bank)
      5'd0: get_descriptor = 256'h8800000000000004000000090000000100000090000000900000000000000090;
      5'd1: get_descriptor = 256'hd80000000000000600000009000000010000001b000000200000000600000030;
      5'd2: get_descriptor = 256'hd80000000000000600000009000000010000001b000000200000000600000030;
      5'd3: get_descriptor = 256'hd80000000000000600000009000000010000001b000000200000000600000030;
      5'd4: get_descriptor = 256'hd800000000000007000000060000000100000015000000200000000700000030;
      5'd5: get_descriptor = 256'ha400000000000004000000010000000100000004000000100000000000000010;
      5'd6: get_descriptor = 256'hb800000000000004000000090000000100000012000000200000000400000030;
      5'd7: get_descriptor = 256'h8800000000000004000000060000000100000060000000600000000000000060;
      5'd8: get_descriptor = 256'h8800000000000004000000060000000100000060000000600000000000000060;
      5'd9: get_descriptor = 256'h8800000000000004000000060000000100000060000000600000000000000060;
      5'd10: get_descriptor = 256'hbc0000000000000400000002000000030000000c000000100000000400000020;
      5'd11: get_descriptor = 256'hcc0000000000000400000002000000030000000c000000100000000800000020;
      5'd12: get_descriptor = 256'hcc0000000000000400000002000000030000000c000000100000000800000020;
      5'd13: get_descriptor = 256'h8c00000000000003000000020000000400000060000000600000000000000060;
      5'd14: get_descriptor = 256'h9c00000000000003000000020000000400000030000000300000000000000030;
      5'd15: get_descriptor = 256'h8800000000000003000000060000000100000048000000500000000000000050;
      5'd16: get_descriptor = 256'hb800000000000003000000060000000100000009000000100000000300000020;
      5'd17: get_descriptor = 256'h8800000000000003000000070000000100000054000000600000000000000060;
      5'd18: get_descriptor = 256'hb80000000000000300000007000000010000000b000000100000000300000020;
      default: get_descriptor = '0;
    endcase
  endfunction
  function automatic logic [31:0] capacity_words(input logic [4:0] bank);
    tensor_desc_t unused_d;
    unused_d=get_descriptor(bank);
    return unused_d.capacity_bytes >> 4;
  endfunction
  function automatic logic [4:0] query_value(input logic [4:0] index);
    case(index)
      5'd0: query_value=5'd3;
      5'd1: query_value=5'd0;
      5'd2: query_value=5'd3;
      default: query_value='0;
    endcase
  endfunction
  function automatic logic compute_legal(input logic [7:0] opcode, dst, src0, src1);
    case ({opcode,dst,src0,src1})
      32'h03060000: compute_legal=1'b1;
      32'h030a0700: compute_legal=1'b1;
      32'h030a0800: compute_legal=1'b1;
      32'h030a0900: compute_legal=1'b1;
      32'h030b0700: compute_legal=1'b1;
      32'h030b0800: compute_legal=1'b1;
      32'h030b0900: compute_legal=1'b1;
      32'h030c0700: compute_legal=1'b1;
      32'h030c0800: compute_legal=1'b1;
      32'h030c0900: compute_legal=1'b1;
      32'h03100f00: compute_legal=1'b1;
      32'h03121100: compute_legal=1'b1;
      32'h04070601: compute_legal=1'b1;
      32'h04070602: compute_legal=1'b1;
      32'h04070603: compute_legal=1'b1;
      32'h04080601: compute_legal=1'b1;
      32'h04080602: compute_legal=1'b1;
      32'h04080603: compute_legal=1'b1;
      32'h04090601: compute_legal=1'b1;
      32'h04090602: compute_legal=1'b1;
      32'h04090603: compute_legal=1'b1;
      32'h04111004: compute_legal=1'b1;
      32'h050d0a0b: compute_legal=1'b1;
      32'h050d0a0c: compute_legal=1'b1;
      32'h060e0d05: compute_legal=1'b1;
      32'h070f0e0b: compute_legal=1'b1;
      32'h070f0e0c: compute_legal=1'b1;
      default: compute_legal=1'b0;
    endcase
  endfunction
endpackage
