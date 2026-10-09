`timescale 1ns/1ps
// Generated immutable configuration; descriptor source SHA256 c0cf2de83d41d4030a13efe15b5417ba194fa29b0807a8bbedd941aa82ece303
package attention_tensor_config_pkg;
  import attention_tensor_pkg::*;
  localparam logic [5:0] CTX_TOKENS = 6'd2;
  localparam logic [2:0] CTX_HEADS = 3'd1;
  localparam logic [6:0] CTX_HEAD_DIM = 7'd2;
  localparam logic [5:0] CTX_QUERY_COUNT = 6'd2;
  localparam logic [0:0] CTX_CAUSAL = 1'd1;
  localparam logic [31:0] CTX_QK_FACTOR = 32'h3f3504f3;
  localparam int BANK_DEPTHS [0:18] = '{64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64};
  function automatic tensor_desc_t get_descriptor(input logic [4:0] bank);
    case (bank)
      5'd0: get_descriptor = 256'h8800000000000002000000030000000100000018000000200000000000000020;
      5'd1: get_descriptor = 256'hd800000000000002000000030000000100000003000000100000000200000020;
      5'd2: get_descriptor = 256'hd800000000000002000000030000000100000003000000100000000200000020;
      5'd3: get_descriptor = 256'hd800000000000002000000030000000100000003000000100000000200000020;
      5'd4: get_descriptor = 256'hd800000000000003000000020000000100000003000000100000000300000020;
      5'd5: get_descriptor = 256'ha400000000000002000000010000000100000002000000100000000000000010;
      5'd6: get_descriptor = 256'hb800000000000002000000030000000100000003000000100000000200000020;
      5'd7: get_descriptor = 256'h8800000000000002000000020000000100000010000000100000000000000010;
      5'd8: get_descriptor = 256'h8800000000000002000000020000000100000010000000100000000000000010;
      5'd9: get_descriptor = 256'h8800000000000002000000020000000100000010000000100000000000000010;
      5'd10: get_descriptor = 256'hbc00000000000002000000010000000200000002000000100000000200000020;
      5'd11: get_descriptor = 256'hcc00000000000002000000010000000200000002000000100000000200000020;
      5'd12: get_descriptor = 256'hcc00000000000002000000010000000200000002000000100000000200000020;
      5'd13: get_descriptor = 256'h8c00000000000002000000010000000200000010000000100000000000000010;
      5'd14: get_descriptor = 256'h9c00000000000002000000010000000200000008000000100000000000000010;
      5'd15: get_descriptor = 256'h8800000000000002000000020000000100000010000000100000000000000010;
      5'd16: get_descriptor = 256'hb800000000000002000000020000000100000002000000100000000200000020;
      5'd17: get_descriptor = 256'h8800000000000002000000030000000100000018000000200000000000000020;
      5'd18: get_descriptor = 256'hb800000000000002000000030000000100000003000000100000000200000020;
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
      default: query_value='0;
    endcase
  endfunction
  function automatic logic compute_legal(input logic [7:0] opcode, dst, src0, src1);
    case ({opcode,dst,src0,src1})
      32'h03060000: compute_legal=1'b1;
      32'h03061100: compute_legal=1'b1;
      32'h030a0700: compute_legal=1'b1;
      32'h030a0800: compute_legal=1'b1;
      32'h030a0900: compute_legal=1'b1;
      32'h030a0d00: compute_legal=1'b1;
      32'h030a0f00: compute_legal=1'b1;
      32'h030b0700: compute_legal=1'b1;
      32'h030b0800: compute_legal=1'b1;
      32'h030b0900: compute_legal=1'b1;
      32'h030b0d00: compute_legal=1'b1;
      32'h030b0f00: compute_legal=1'b1;
      32'h030c0700: compute_legal=1'b1;
      32'h030c0800: compute_legal=1'b1;
      32'h030c0900: compute_legal=1'b1;
      32'h030c0d00: compute_legal=1'b1;
      32'h030c0f00: compute_legal=1'b1;
      32'h03100700: compute_legal=1'b1;
      32'h03100800: compute_legal=1'b1;
      32'h03100900: compute_legal=1'b1;
      32'h03100d00: compute_legal=1'b1;
      32'h03100f00: compute_legal=1'b1;
      32'h03120000: compute_legal=1'b1;
      32'h03121100: compute_legal=1'b1;
      32'h04001004: compute_legal=1'b1;
      32'h04070601: compute_legal=1'b1;
      32'h04070602: compute_legal=1'b1;
      32'h04070603: compute_legal=1'b1;
      32'h04071201: compute_legal=1'b1;
      32'h04071202: compute_legal=1'b1;
      32'h04071203: compute_legal=1'b1;
      32'h04080601: compute_legal=1'b1;
      32'h04080602: compute_legal=1'b1;
      32'h04080603: compute_legal=1'b1;
      32'h04081201: compute_legal=1'b1;
      32'h04081202: compute_legal=1'b1;
      32'h04081203: compute_legal=1'b1;
      32'h04090601: compute_legal=1'b1;
      32'h04090602: compute_legal=1'b1;
      32'h04090603: compute_legal=1'b1;
      32'h04091201: compute_legal=1'b1;
      32'h04091202: compute_legal=1'b1;
      32'h04091203: compute_legal=1'b1;
      32'h040f0601: compute_legal=1'b1;
      32'h040f0602: compute_legal=1'b1;
      32'h040f0603: compute_legal=1'b1;
      32'h040f1201: compute_legal=1'b1;
      32'h040f1202: compute_legal=1'b1;
      32'h040f1203: compute_legal=1'b1;
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
