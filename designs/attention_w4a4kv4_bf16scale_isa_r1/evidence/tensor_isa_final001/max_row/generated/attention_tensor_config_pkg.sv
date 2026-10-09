`timescale 1ns/1ps
// Generated immutable configuration; descriptor source SHA256 b1e60838e6fe89f1e6f566274d78ee1b694f138e2b525ade759407f7076c0857
package attention_tensor_config_pkg;
  import attention_tensor_pkg::*;
  localparam logic [5:0] CTX_TOKENS = 6'd1;
  localparam logic [2:0] CTX_HEADS = 3'd4;
  localparam logic [6:0] CTX_HEAD_DIM = 7'd64;
  localparam logic [5:0] CTX_QUERY_COUNT = 6'd1;
  localparam logic [0:0] CTX_CAUSAL = 1'd1;
  localparam logic [31:0] CTX_QK_FACTOR = 32'h3e000000;
  localparam int BANK_DEPTHS [0:18] = '{64,4096,4096,4096,64,64,64,64,64,64,64,64,64,64,64,64,64,64,64};
  function automatic tensor_desc_t get_descriptor(input logic [4:0] bank);
    case (bank)
      5'd0: get_descriptor = 256'h8800000000000001000001000000000100000400000004000000000000000400;
      5'd1: get_descriptor = 256'hd800000000000100000001000000000100008000000080000000080000009000;
      5'd2: get_descriptor = 256'hd800000000000100000001000000000100008000000080000000080000009000;
      5'd3: get_descriptor = 256'hd800000000000100000001000000000100008000000080000000080000009000;
      5'd4: get_descriptor = 256'hd800000000000001000001000000000100000080000000800000000800000090;
      5'd5: get_descriptor = 256'ha400000000000001000000010000000100000001000000100000000000000010;
      5'd6: get_descriptor = 256'hb800000000000001000001000000000100000080000000800000000100000090;
      5'd7: get_descriptor = 256'h8800000000000001000001000000000100000400000004000000000000000400;
      5'd8: get_descriptor = 256'h8800000000000001000001000000000100000400000004000000000000000400;
      5'd9: get_descriptor = 256'h8800000000000001000001000000000100000400000004000000000000000400;
      5'd10: get_descriptor = 256'hbc00000000000001000000040000004000000080000000800000000100000090;
      5'd11: get_descriptor = 256'hcc00000000000001000000040000004000000080000000800000000400000090;
      5'd12: get_descriptor = 256'hcc00000000000001000000040000004000000080000000800000000400000090;
      5'd13: get_descriptor = 256'h8c00000000000001000000040000000100000010000000100000000000000010;
      5'd14: get_descriptor = 256'h9c00000000000001000000040000000100000008000000100000000000000010;
      5'd15: get_descriptor = 256'h8800000000000001000001000000000100000400000004000000000000000400;
      5'd16: get_descriptor = 256'hb800000000000001000001000000000100000080000000800000000100000090;
      5'd17: get_descriptor = 256'h8800000000000001000000010000000100000004000000100000000000000010;
      5'd18: get_descriptor = 256'hb800000000000001000000010000000100000001000000100000000100000020;
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
      default: query_value='0;
    endcase
  endfunction
  function automatic logic compute_legal(input logic [7:0] opcode, dst, src0, src1);
    case ({opcode,dst,src0,src1})
      32'h03060000: compute_legal=1'b1;
      32'h03060700: compute_legal=1'b1;
      32'h03060800: compute_legal=1'b1;
      32'h03060900: compute_legal=1'b1;
      32'h03060f00: compute_legal=1'b1;
      32'h030a0000: compute_legal=1'b1;
      32'h030a0700: compute_legal=1'b1;
      32'h030a0800: compute_legal=1'b1;
      32'h030a0900: compute_legal=1'b1;
      32'h030a0f00: compute_legal=1'b1;
      32'h030b0000: compute_legal=1'b1;
      32'h030b0700: compute_legal=1'b1;
      32'h030b0800: compute_legal=1'b1;
      32'h030b0900: compute_legal=1'b1;
      32'h030b0f00: compute_legal=1'b1;
      32'h030c0000: compute_legal=1'b1;
      32'h030c0700: compute_legal=1'b1;
      32'h030c0800: compute_legal=1'b1;
      32'h030c0900: compute_legal=1'b1;
      32'h030c0f00: compute_legal=1'b1;
      32'h03100000: compute_legal=1'b1;
      32'h03100700: compute_legal=1'b1;
      32'h03100800: compute_legal=1'b1;
      32'h03100900: compute_legal=1'b1;
      32'h03100f00: compute_legal=1'b1;
      32'h03121100: compute_legal=1'b1;
      32'h04000601: compute_legal=1'b1;
      32'h04000602: compute_legal=1'b1;
      32'h04000603: compute_legal=1'b1;
      32'h04001001: compute_legal=1'b1;
      32'h04001002: compute_legal=1'b1;
      32'h04001003: compute_legal=1'b1;
      32'h04070601: compute_legal=1'b1;
      32'h04070602: compute_legal=1'b1;
      32'h04070603: compute_legal=1'b1;
      32'h04071001: compute_legal=1'b1;
      32'h04071002: compute_legal=1'b1;
      32'h04071003: compute_legal=1'b1;
      32'h04080601: compute_legal=1'b1;
      32'h04080602: compute_legal=1'b1;
      32'h04080603: compute_legal=1'b1;
      32'h04081001: compute_legal=1'b1;
      32'h04081002: compute_legal=1'b1;
      32'h04081003: compute_legal=1'b1;
      32'h04090601: compute_legal=1'b1;
      32'h04090602: compute_legal=1'b1;
      32'h04090603: compute_legal=1'b1;
      32'h04091001: compute_legal=1'b1;
      32'h04091002: compute_legal=1'b1;
      32'h04091003: compute_legal=1'b1;
      32'h040f0601: compute_legal=1'b1;
      32'h040f0602: compute_legal=1'b1;
      32'h040f0603: compute_legal=1'b1;
      32'h040f1001: compute_legal=1'b1;
      32'h040f1002: compute_legal=1'b1;
      32'h040f1003: compute_legal=1'b1;
      32'h04110604: compute_legal=1'b1;
      32'h04111004: compute_legal=1'b1;
      32'h050d0a0b: compute_legal=1'b1;
      32'h050d0a0c: compute_legal=1'b1;
      32'h060e0d05: compute_legal=1'b1;
      32'h07000e0b: compute_legal=1'b1;
      32'h07000e0c: compute_legal=1'b1;
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
