`timescale 1ns/1ps
// Generated immutable configuration; descriptor source SHA256 cfd47f312cf1b5d9f964c20958595ba8d06f88248184e1c51cddf22ad1ed11c6
package attention_tensor_config_pkg;
  import attention_tensor_pkg::*;
  localparam logic [5:0] CTX_TOKENS = 6'd3;
  localparam logic [2:0] CTX_HEADS = 3'd2;
  localparam logic [6:0] CTX_HEAD_DIM = 7'd16;
  localparam logic [5:0] CTX_QUERY_COUNT = 6'd1;
  localparam logic [0:0] CTX_CAUSAL = 1'd1;
  localparam logic [31:0] CTX_QK_FACTOR = 32'h3e800000;
  localparam int BANK_DEPTHS [0:18] = '{64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64};
  function automatic tensor_desc_t get_descriptor(input logic [4:0] bank);
    case (bank)
      5'd0: get_descriptor = 256'h880000000000000300000021000000010000018c000001900000000000000190;
      5'd1: get_descriptor = 256'hd800000000000020000000210000000100000210000002100000004000000290;
      5'd2: get_descriptor = 256'hd800000000000020000000210000000100000210000002100000004000000290;
      5'd3: get_descriptor = 256'hd800000000000020000000210000000100000210000002100000004000000290;
      5'd4: get_descriptor = 256'hd800000000000021000000200000000100000210000002100000002100000260;
      5'd5: get_descriptor = 256'ha400000000000003000000010000000100000003000000100000000000000010;
      5'd6: get_descriptor = 256'hb800000000000003000000210000000100000032000000400000000300000050;
      5'd7: get_descriptor = 256'h8800000000000003000000200000000100000180000001800000000000000180;
      5'd8: get_descriptor = 256'h8800000000000003000000200000000100000180000001800000000000000180;
      5'd9: get_descriptor = 256'h8800000000000003000000200000000100000180000001800000000000000180;
      5'd10: get_descriptor = 256'hbc00000000000003000000020000001000000030000000300000000300000040;
      5'd11: get_descriptor = 256'hcc00000000000003000000020000001000000030000000300000000600000040;
      5'd12: get_descriptor = 256'hcc00000000000003000000020000001000000030000000300000000600000040;
      5'd13: get_descriptor = 256'h8c00000000000001000000020000000300000018000000200000000000000020;
      5'd14: get_descriptor = 256'h9c0000000000000100000002000000030000000c000000100000000000000010;
      5'd15: get_descriptor = 256'h8800000000000001000000200000000100000080000000800000000000000080;
      5'd16: get_descriptor = 256'hb800000000000001000000200000000100000010000000100000000100000020;
      5'd17: get_descriptor = 256'h8800000000000001000000210000000100000084000000900000000000000090;
      5'd18: get_descriptor = 256'hb800000000000001000000210000000100000011000000200000000100000030;
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
      5'd0: query_value=5'd2;
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
      32'h040f1201: compute_legal=1'b1;
      32'h040f1202: compute_legal=1'b1;
      32'h040f1203: compute_legal=1'b1;
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
