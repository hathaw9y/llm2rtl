`timescale 1ns/1ps
// Generated immutable configuration; descriptor source SHA256 5b53756bbfca7dee0554c13ac42e347c9f4be66b6801c037f005447d1096eda2
package attention_tensor_config_pkg;
  import attention_tensor_pkg::*;
  localparam logic [5:0] CTX_TOKENS = 6'd4;
  localparam logic [2:0] CTX_HEADS = 3'd3;
  localparam logic [6:0] CTX_HEAD_DIM = 7'd11;
  localparam logic [5:0] CTX_QUERY_COUNT = 6'd4;
  localparam logic [0:0] CTX_CAUSAL = 1'd1;
  localparam logic [31:0] CTX_QK_FACTOR = 32'h3e9a5fb2;
  localparam int BANK_DEPTHS [0:18] = '{64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64};
  function automatic tensor_desc_t get_descriptor(input logic [4:0] bank);
    case (bank)
      5'd0: get_descriptor = 256'h8800000000000004000000230000000100000230000002300000000000000230;
      5'd1: get_descriptor = 256'hd8000000000000210000002300000001000002420000025000000042000002e0;
      5'd2: get_descriptor = 256'hd8000000000000210000002300000001000002420000025000000042000002e0;
      5'd3: get_descriptor = 256'hd8000000000000210000002300000001000002420000025000000042000002e0;
      5'd4: get_descriptor = 256'hd800000000000011000000210000000100000119000001200000002200000170;
      5'd5: get_descriptor = 256'ha400000000000004000000010000000100000004000000100000000000000010;
      5'd6: get_descriptor = 256'hb800000000000004000000230000000100000046000000500000000400000060;
      5'd7: get_descriptor = 256'h8800000000000004000000210000000100000210000002100000000000000210;
      5'd8: get_descriptor = 256'h8800000000000004000000210000000100000210000002100000000000000210;
      5'd9: get_descriptor = 256'h8800000000000004000000210000000100000210000002100000000000000210;
      5'd10: get_descriptor = 256'hbc00000000000004000000030000000b00000042000000500000000400000060;
      5'd11: get_descriptor = 256'hcc00000000000004000000030000000b00000042000000500000000c00000070;
      5'd12: get_descriptor = 256'hcc00000000000004000000030000000b00000042000000500000000c00000070;
      5'd13: get_descriptor = 256'h8c000000000000040000000300000004000000c0000000c000000000000000c0;
      5'd14: get_descriptor = 256'h9c00000000000004000000030000000400000060000000600000000000000060;
      5'd15: get_descriptor = 256'h8800000000000004000000210000000100000210000002100000000000000210;
      5'd16: get_descriptor = 256'hb800000000000004000000210000000100000042000000500000000400000060;
      5'd17: get_descriptor = 256'h8800000000000004000000110000000100000110000001100000000000000110;
      5'd18: get_descriptor = 256'hb800000000000004000000110000000100000022000000300000000400000040;
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
