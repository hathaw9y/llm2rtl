`timescale 1ns/1ps

module s2mm_stream_bank_adapter (
    input  logic          aclk,
    input  logic          aresetn,
    input  logic          s_ctrl_start,
    output logic          s_ctrl_done,
    input  logic          s_ctrl_abort,
    input  logic [22:0]   s_ctrl_byte_offset,
    input  logic [22:0]   s_ctrl_byte_count,

    output logic          s2mm_read_valid,
    input  logic          s2mm_read_ready,
    output logic [31:0]   s2mm_read_addr,
    input  logic          s2mm_rsp_valid,
    input  logic [1023:0] s2mm_rsp_data,

    output logic [63:0]   m_axis_tdata,
    output logic [7:0]    m_axis_tkeep,
    output logic          m_axis_tvalid,
    input  logic          m_axis_tready,
    output logic          m_axis_tlast
);
  typedef enum logic [1:0] {IDLE, RUN, DONE} state_t;

  state_t state_r;
  logic abort_pending_r;
  logic outstanding_r;
  logic word_valid_r;
  logic [31:0] request_addr_r;
  logic [22:0] bytes_remaining_r;
  logic [1023:0] word_data_r;
  logic [3:0] chunk_index_r;
  logic offset_alignment_w;

  // Native addresses intentionally floor byte offsets to 128-byte words.
  assign offset_alignment_w = ^s_ctrl_byte_offset[6:0];

  function automatic logic [7:0] keep_from_remaining(input logic [22:0] count);
    begin
      if (count >= 23'd8) begin
        keep_from_remaining = 8'hff;
      end else begin
        keep_from_remaining = 8'hff >> (4'd8 - count[3:0]);
      end
    end
  endfunction

  assign s_ctrl_done = (state_r == DONE);
  assign s2mm_read_valid = (state_r == RUN) && !s_ctrl_abort && !abort_pending_r &&
                           !outstanding_r && !word_valid_r && (bytes_remaining_r != 0);
  assign s2mm_read_addr = request_addr_r;

  assign m_axis_tvalid = (state_r == RUN) && word_valid_r;
  assign m_axis_tdata = word_data_r[chunk_index_r*64 +: 64];
  assign m_axis_tkeep = keep_from_remaining(bytes_remaining_r);
  assign m_axis_tlast = m_axis_tvalid && (bytes_remaining_r <= 23'd8);

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      state_r <= IDLE;
      abort_pending_r <= 1'b0;
      outstanding_r <= 1'b0;
      word_valid_r <= 1'b0;
      request_addr_r <= '0;
      bytes_remaining_r <= '0;
      word_data_r <= '0;
      chunk_index_r <= '0;
    end else begin
      case (state_r)
        IDLE: begin
          abort_pending_r <= 1'b0;
          outstanding_r <= 1'b0;
          word_valid_r <= 1'b0;
          chunk_index_r <= '0;
          if (s_ctrl_start) begin
            request_addr_r <= {16'd0, s_ctrl_byte_offset[22:7]} |
                              {31'd0, (offset_alignment_w & 1'b0)};
            bytes_remaining_r <= s_ctrl_byte_count;
            if (s_ctrl_byte_count == 0) state_r <= DONE;
            else state_r <= RUN;
          end
        end

        RUN: begin
          if (s_ctrl_abort) abort_pending_r <= 1'b1;

          if (s2mm_read_valid && s2mm_read_ready) begin
            outstanding_r <= 1'b1;
            request_addr_r <= request_addr_r + 32'd1;
          end

          if (s2mm_rsp_valid && outstanding_r) begin
            outstanding_r <= 1'b0;
            if (s_ctrl_abort || abort_pending_r) begin
              state_r <= DONE;
            end else begin
              word_data_r <= s2mm_rsp_data;
              word_valid_r <= 1'b1;
              chunk_index_r <= '0;
            end
          end

          if (m_axis_tvalid && m_axis_tready) begin
            if (bytes_remaining_r <= 23'd8) begin
              bytes_remaining_r <= '0;
              word_valid_r <= 1'b0;
              state_r <= DONE;
            end else if (s_ctrl_abort || abort_pending_r) begin
              word_valid_r <= 1'b0;
              state_r <= DONE;
            end else begin
              bytes_remaining_r <= bytes_remaining_r - 23'd8;
              if (chunk_index_r == 4'd15) begin
                word_valid_r <= 1'b0;
                chunk_index_r <= '0;
              end else begin
                chunk_index_r <= chunk_index_r + 4'd1;
              end
            end
          end else if ((s_ctrl_abort || abort_pending_r) && !word_valid_r && !outstanding_r) begin
            state_r <= DONE;
          end
        end

        DONE: begin
          outstanding_r <= 1'b0;
          word_valid_r <= 1'b0;
          if (!s_ctrl_start) state_r <= IDLE;
        end

        default: state_r <= IDLE;
      endcase
    end
  end
endmodule
