`timescale 1ns/1ps
// Native-bank adapter for the verified arithmetic child. A command's source,
// packed INT4 destination, and BF16 scale destination are saved independently.
module attention_quantizer_executor (
    input logic aclk, aresetn,
    input logic cmd_valid,
    output logic cmd_ready,
    input logic [1:0] cmd_src_bank, cmd_dst_bank, cmd_scale_bank,
    input logic [8:0] cmd_elements,
    output logic resp_valid,
    input logic resp_ready,
    output logic [1:0] resp_src_bank, resp_dst_bank, resp_scale_bank,
    output logic resp_error,
    output logic quant_src_bank_enb [0:2],
    output logic [31:0] quant_src_bank_addrb [0:2],
    input logic quant_src_bank_read_ready [0:2],
    input logic quant_src_bank_valid [0:2],
    input logic [127:0] quant_src_bank_doutb [0:2],
    output logic quant_data_bank_ena [0:2],
    output logic [31:0] quant_data_bank_addra [0:2],
    output logic [127:0] quant_data_bank_dina [0:2],
    output logic [15:0] quant_data_bank_wea [0:2],
    input logic quant_data_bank_ready [0:2],
    output logic quant_scale_bank_ena [0:2],
    output logic [31:0] quant_scale_bank_addra [0:2],
    output logic [127:0] quant_scale_bank_dina [0:2],
    output logic [15:0] quant_scale_bank_wea [0:2],
    input logic quant_scale_bank_ready [0:2]
);
  typedef enum logic [3:0] {
    IDLE, CORE_COMMAND, READ_REQUEST, READ_RESPONSE, FEED_INPUT,
    CAPTURE_OUTPUT, WRITE_DATA, WRITE_SCALE, CHILD_RESPONSE, RESPOND
  } state_t;
  state_t state_r;
  logic [1:0] src_bank_r, dst_bank_r, scale_bank_r;
  logic [8:0] elements_r, inputs_left_r;
  logic [31:0] source_word_index_r, data_word_index_r;
  logic [127:0] source_word_r, packed_word_r;
  logic [1:0] input_lane_r;
  logic [4:0] output_lane_r;
  logic final_word_r, error_r;
  logic [15:0] scale_r;
  logic child_cmd_valid, child_cmd_ready;
  logic child_input_valid, child_input_ready;
  logic [31:0] child_input_data;
  logic child_output_valid, child_output_ready, child_output_last;
  logic [3:0] child_output_data;
  logic [15:0] child_output_scale;
  logic child_resp_valid, child_resp_ready, child_resp_error;
  logic [7:0] unused_child_resp_id;
  logic command_legal_w;
  assign command_legal_w = cmd_src_bank < 2'd3 && cmd_dst_bank < 2'd3 && cmd_scale_bank < 2'd3 &&
      cmd_src_bank != cmd_dst_bank && cmd_src_bank != cmd_scale_bank && cmd_dst_bank != cmd_scale_bank &&
      cmd_elements > 9'd0 && cmd_elements <= 9'd256;
  assign cmd_ready = aresetn && state_r == IDLE;
  assign resp_valid = aresetn && state_r == RESPOND;
  assign resp_src_bank = src_bank_r;
  assign resp_dst_bank = dst_bank_r;
  assign resp_scale_bank = scale_bank_r;
  assign resp_error = error_r;
  assign child_cmd_valid = aresetn && state_r == CORE_COMMAND;
  assign child_input_valid = aresetn && state_r == FEED_INPUT;
  assign child_input_data = source_word_r[32*input_lane_r +: 32];
  assign child_output_ready = aresetn && state_r == CAPTURE_OUTPUT;
  // An error row produces no payload. Normal child response is held until
  // both the final packed-data write and independent scale write are accepted.
  assign child_resp_ready = aresetn && (state_r == CHILD_RESPONSE ||
      (state_r == CAPTURE_OUTPUT && child_resp_error));
  attention_int4_quantizer #(.MAX_ELEMENTS(256), .ID_WIDTH(8)) u_quantizer (
      .aclk(aclk), .aresetn(aresetn), .cmd_valid(child_cmd_valid), .cmd_ready(child_cmd_ready),
      .cmd_id(8'd0), .cmd_elements(elements_r), .s_axis_value_tvalid(child_input_valid),
      .s_axis_value_tready(child_input_ready), .s_axis_value_tdata(child_input_data),
      .m_axis_quant_tvalid(child_output_valid), .m_axis_quant_tready(child_output_ready),
      .m_axis_quant_tdata(child_output_data), .m_axis_quant_tscale(child_output_scale),
      .m_axis_quant_tlast(child_output_last), .resp_valid(child_resp_valid),
      .resp_ready(child_resp_ready), .resp_id(unused_child_resp_id), .resp_error(child_resp_error));
  // Native memory enables are acceptance pulses, not queued stream valids.
  // Addresses/data remain stable while waiting for the corresponding ready.
  for (genvar b=0; b<3; b++) begin : g_native_memory
    assign quant_src_bank_enb[b] = aresetn && state_r == READ_REQUEST && src_bank_r == 2'(b) && quant_src_bank_read_ready[b];
    assign quant_src_bank_addrb[b] = source_word_index_r;
    assign quant_data_bank_ena[b] = aresetn && state_r == WRITE_DATA && dst_bank_r == 2'(b) && quant_data_bank_ready[b];
    assign quant_data_bank_addra[b] = data_word_index_r;
    assign quant_data_bank_dina[b] = packed_word_r;
    assign quant_data_bank_wea[b] = 16'hffff;
    assign quant_scale_bank_ena[b] = aresetn && state_r == WRITE_SCALE && scale_bank_r == 2'(b) && quant_scale_bank_ready[b];
    assign quant_scale_bank_addra[b] = '0;
    assign quant_scale_bank_dina[b] = {112'd0,scale_r};
    assign quant_scale_bank_wea[b] = 16'hffff;
  end
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      state_r <= IDLE; src_bank_r <= '0; dst_bank_r <= '0; scale_bank_r <= '0;
      elements_r <= '0; inputs_left_r <= '0; source_word_index_r <= '0; data_word_index_r <= '0;
      source_word_r <= '0; packed_word_r <= '0; input_lane_r <= '0; output_lane_r <= '0;
      final_word_r <= 1'b0; error_r <= 1'b0; scale_r <= '0;
    end else begin
      case (state_r)
        IDLE: if (cmd_valid && cmd_ready) begin
          src_bank_r <= cmd_src_bank; dst_bank_r <= cmd_dst_bank; scale_bank_r <= cmd_scale_bank;
          elements_r <= cmd_elements; inputs_left_r <= cmd_elements;
          source_word_index_r <= '0; data_word_index_r <= '0; packed_word_r <= '0;
          input_lane_r <= '0; output_lane_r <= '0; final_word_r <= 1'b0; error_r <= !command_legal_w;
          if (command_legal_w) state_r <= CORE_COMMAND;
          else state_r <= RESPOND;
        end
        CORE_COMMAND: if (child_cmd_valid && child_cmd_ready) state_r <= READ_REQUEST;
        READ_REQUEST: if (quant_src_bank_enb[src_bank_r]) state_r <= READ_RESPONSE;
        READ_RESPONSE: if (quant_src_bank_valid[src_bank_r]) begin
          source_word_r <= quant_src_bank_doutb[src_bank_r]; input_lane_r <= '0; state_r <= FEED_INPUT;
        end
        FEED_INPUT: if (child_input_valid && child_input_ready) begin
          inputs_left_r <= inputs_left_r-9'd1;
          if (inputs_left_r == 9'd1) state_r <= CAPTURE_OUTPUT;
          else if (input_lane_r == 2'd3) begin
            source_word_index_r <= source_word_index_r+32'd1; state_r <= READ_REQUEST;
          end else input_lane_r <= input_lane_r+2'd1;
        end
        CAPTURE_OUTPUT: begin
          if (child_output_valid && child_output_ready) begin
            packed_word_r[4*output_lane_r +: 4] <= child_output_data;
            scale_r <= child_output_scale;
            if (output_lane_r == 5'd31 || child_output_last) begin
              final_word_r <= child_output_last; state_r <= WRITE_DATA;
            end else output_lane_r <= output_lane_r+5'd1;
          end
          if (child_resp_valid && child_resp_ready) begin error_r <= child_resp_error; state_r <= RESPOND; end
        end
        WRITE_DATA: if (quant_data_bank_ena[dst_bank_r]) begin
          if (final_word_r) state_r <= WRITE_SCALE;
          else begin
            packed_word_r <= '0; output_lane_r <= '0; data_word_index_r <= data_word_index_r+32'd1;
            state_r <= CAPTURE_OUTPUT;
          end
        end
        WRITE_SCALE: if (quant_scale_bank_ena[scale_bank_r]) state_r <= CHILD_RESPONSE;
        CHILD_RESPONSE: if (child_resp_valid && child_resp_ready) begin error_r <= child_resp_error; state_r <= RESPOND; end
        RESPOND: if (resp_valid && resp_ready) state_r <= IDLE;
        // Illegal internal state is an unclean fault. Never certify completion
        // or release ownership; coordinated reset cancels this command.
        default: state_r <= state_r;
      endcase
    end
  end
endmodule
