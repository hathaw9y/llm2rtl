`timescale 1ns/1ps
// Generated immutable configuration; descriptor source SHA256 717d291d5cc97dcfd67ab93666a9a920003d17a0daddcf3628c6eba022da8b33
package attention_tensor_config_pkg;
  import attention_tensor_pkg::*;
  localparam logic [5:0] CTX_TOKENS = 6'd32;
  localparam logic [2:0] CTX_HEADS = 3'd2;
  localparam logic [6:0] CTX_HEAD_DIM = 7'd3;
  localparam logic [5:0] CTX_QUERY_COUNT = 6'd32;
  localparam logic [0:0] CTX_CAUSAL = 1'd1;
  localparam logic [31:0] CTX_QK_FACTOR = 32'h3f13cd3a;
  localparam int BANK_DEPTHS [0:18] = '{512,64,64,64,64,64,64,64,64,64,64,64,64,512,256,64,64,64,64};
  function automatic tensor_desc_t get_descriptor(input logic [4:0] bank);
    case (bank)
      5'd0: get_descriptor = 256'h8800000000000020000000210000000100001080000010800000000000001080;
      5'd1: get_descriptor = 256'hd800000000000006000000210000000100000063000000700000000c00000090;
      5'd2: get_descriptor = 256'hd800000000000006000000210000000100000063000000700000000c00000090;
      5'd3: get_descriptor = 256'hd800000000000006000000210000000100000063000000700000000c00000090;
      5'd4: get_descriptor = 256'hd800000000000007000000060000000100000015000000200000000700000030;
      5'd5: get_descriptor = 256'ha400000000000020000000010000000100000020000000200000000000000020;
      5'd6: get_descriptor = 256'hb800000000000020000000210000000100000210000002100000002000000250;
      5'd7: get_descriptor = 256'h8800000000000020000000060000000100000300000003000000000000000300;
      5'd8: get_descriptor = 256'h8800000000000020000000060000000100000300000003000000000000000300;
      5'd9: get_descriptor = 256'h8800000000000020000000060000000100000300000003000000000000000300;
      5'd10: get_descriptor = 256'hbc000000000000200000000200000003000000600000006000000020000000a0;
      5'd11: get_descriptor = 256'hcc000000000000200000000200000003000000600000006000000040000000e0;
      5'd12: get_descriptor = 256'hcc000000000000200000000200000003000000600000006000000040000000e0;
      5'd13: get_descriptor = 256'h8c00000000000020000000020000002000002000000020000000000000002000;
      5'd14: get_descriptor = 256'h9c00000000000020000000020000002000001000000010000000000000001000;
      5'd15: get_descriptor = 256'h8800000000000020000000060000000100000300000003000000000000000300;
      5'd16: get_descriptor = 256'hb8000000000000200000000600000001000000600000006000000020000000a0;
      5'd17: get_descriptor = 256'h8800000000000020000000070000000100000380000003800000000000000380;
      5'd18: get_descriptor = 256'hb8000000000000200000000700000001000000700000007000000020000000b0;
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
      5'd0: query_value=5'd0;
      5'd1: query_value=5'd1;
      5'd2: query_value=5'd2;
      5'd3: query_value=5'd3;
      5'd4: query_value=5'd4;
      5'd5: query_value=5'd5;
      5'd6: query_value=5'd6;
      5'd7: query_value=5'd7;
      5'd8: query_value=5'd8;
      5'd9: query_value=5'd9;
      5'd10: query_value=5'd10;
      5'd11: query_value=5'd11;
      5'd12: query_value=5'd12;
      5'd13: query_value=5'd13;
      5'd14: query_value=5'd14;
      5'd15: query_value=5'd15;
      5'd16: query_value=5'd16;
      5'd17: query_value=5'd17;
      5'd18: query_value=5'd18;
      5'd19: query_value=5'd19;
      5'd20: query_value=5'd20;
      5'd21: query_value=5'd21;
      5'd22: query_value=5'd22;
      5'd23: query_value=5'd23;
      5'd24: query_value=5'd24;
      5'd25: query_value=5'd25;
      5'd26: query_value=5'd26;
      5'd27: query_value=5'd27;
      5'd28: query_value=5'd28;
      5'd29: query_value=5'd29;
      5'd30: query_value=5'd30;
      5'd31: query_value=5'd31;
      default: query_value='0;
    endcase
  endfunction
  function automatic logic compute_legal(input logic [7:0] opcode, dst, src0, src1);
    case ({opcode,dst,src0,src1})
      32'h03060000: compute_legal=1'b1;
      32'h030a0700: compute_legal=1'b1;
      32'h030a0800: compute_legal=1'b1;
      32'h030a0900: compute_legal=1'b1;
      32'h030a0f00: compute_legal=1'b1;
      32'h030b0700: compute_legal=1'b1;
      32'h030b0800: compute_legal=1'b1;
      32'h030b0900: compute_legal=1'b1;
      32'h030b0f00: compute_legal=1'b1;
      32'h030c0700: compute_legal=1'b1;
      32'h030c0800: compute_legal=1'b1;
      32'h030c0900: compute_legal=1'b1;
      32'h030c0f00: compute_legal=1'b1;
      32'h03100700: compute_legal=1'b1;
      32'h03100800: compute_legal=1'b1;
      32'h03100900: compute_legal=1'b1;
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
      32'h040f0601: compute_legal=1'b1;
      32'h040f0602: compute_legal=1'b1;
      32'h040f0603: compute_legal=1'b1;
      32'h04111004: compute_legal=1'b1;
      32'h050d0a0b: compute_legal=1'b1;
      32'h050d0a0c: compute_legal=1'b1;
      32'h060e0d05: compute_legal=1'b1;
      32'h07070e0b: compute_legal=1'b1;
      32'h07070e0c: compute_legal=1'b1;
      32'h07080e0b: compute_legal=1'b1;
      32'h07080e0c: compute_legal=1'b1;
      32'h07090e0b: compute_legal=1'b1;
      32'h07090e0c: compute_legal=1'b1;
      32'h070f0e0b: compute_legal=1'b1;
      32'h070f0e0c: compute_legal=1'b1;
      default: compute_legal=1'b0;
    endcase
  endfunction
endpackage
