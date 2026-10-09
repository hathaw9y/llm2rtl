`timescale 1ns/1ps

module mm2s_stream_bank_adapter (
    input  logic          aclk,
    input  logic          aresetn,
    input  logic          s_ctrl_start,
    output logic          s_ctrl_done,
    input  logic          s_ctrl_abort,
    input  logic [22:0]   s_ctrl_byte_offset,
    input  logic [3:0]    s_ctrl_bank,

    input  logic [63:0]   s_axis_tdata,
    input  logic [7:0]    s_axis_tkeep,
    input  logic          s_axis_tvalid,
    output logic          s_axis_tready,
    input  logic          s_axis_tlast,

    output logic          bank_write_valid,
    input  logic          bank_write_ready,
    output logic [3:0]    bank_write_bank,
    output logic [31:0]   bank_write_addr,
    output logic [15:0]   bank_write_strb,
    output logic [127:0]  bank_write_data
);
  typedef enum logic [1:0] {IDLE, RUN, DONE} state_t;

  state_t state_r;
  logic [3:0] bank_r;
  logic [31:0] address_r;
  logic half_valid_r;
  logic [63:0] half_data_r;
  logic [7:0] half_keep_r;
  logic write_valid_r;
  logic write_last_r;
  logic [127:0] write_data_r;
  logic [15:0] write_strb_r;
  logic offset_alignment_w;

  // Native addresses intentionally floor byte offsets to 16-byte words.
  assign offset_alignment_w = ^s_ctrl_byte_offset[3:0];

  assign s_ctrl_done = (state_r == DONE);
  assign s_axis_tready = (state_r == RUN) && !s_ctrl_abort && !write_valid_r;

  assign bank_write_valid = write_valid_r;
  assign bank_write_bank = bank_r;
  assign bank_write_addr = address_r;
  assign bank_write_strb = write_strb_r;
  assign bank_write_data = write_data_r;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      state_r <= IDLE;
      bank_r <= '0;
      address_r <= '0;
      half_valid_r <= 1'b0;
      half_data_r <= '0;
      half_keep_r <= '0;
      write_valid_r <= 1'b0;
      write_last_r <= 1'b0;
      write_data_r <= '0;
      write_strb_r <= '0;
    end else begin
      case (state_r)
        IDLE: begin
          half_valid_r <= 1'b0;
          write_valid_r <= 1'b0;
          write_last_r <= 1'b0;
          if (s_ctrl_start) begin
            bank_r <= s_ctrl_bank;
            address_r <= {13'd0, s_ctrl_byte_offset[22:4]} |
                         {31'd0, (offset_alignment_w & 1'b0)};
            state_r <= RUN;
          end
        end

        RUN: begin
          if (write_valid_r && bank_write_ready) begin
            write_valid_r <= 1'b0;
            address_r <= address_r + 32'd1;
            if (write_last_r || s_ctrl_abort) begin
              half_valid_r <= 1'b0;
              state_r <= DONE;
            end
          end else if (s_ctrl_abort && !write_valid_r) begin
            half_valid_r <= 1'b0;
            state_r <= DONE;
          end

          if (s_axis_tvalid && s_axis_tready) begin
            if (!half_valid_r) begin
              if (s_axis_tlast) begin
                write_data_r <= {64'd0, s_axis_tdata};
                write_strb_r <= {8'd0, s_axis_tkeep};
                write_last_r <= 1'b1;
                write_valid_r <= 1'b1;
              end else begin
                half_data_r <= s_axis_tdata;
                half_keep_r <= s_axis_tkeep;
                half_valid_r <= 1'b1;
              end
            end else begin
              write_data_r <= {s_axis_tdata, half_data_r};
              write_strb_r <= {s_axis_tkeep, half_keep_r};
              write_last_r <= s_axis_tlast;
              write_valid_r <= 1'b1;
              half_valid_r <= 1'b0;
            end
          end
        end

        DONE: begin
          write_valid_r <= 1'b0;
          if (!s_ctrl_start) state_r <= IDLE;
        end

        default: state_r <= IDLE;
      endcase
    end
  end
endmodule
