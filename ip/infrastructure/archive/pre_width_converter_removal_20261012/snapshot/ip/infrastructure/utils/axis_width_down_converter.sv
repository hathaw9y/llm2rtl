module axis_width_down_converter #(
    parameter int MASTER_DATA_WIDTH = 64,
    parameter int SLAVE_DATA_WIDTH  = 32,
    parameter int MASTER_KEEP_WIDTH = MASTER_DATA_WIDTH / 8,
    parameter int SLAVE_KEEP_WIDTH  = SLAVE_DATA_WIDTH / 8
) (
    input  logic                         aclk,
    input  logic                         aresetn,
    output logic [MASTER_DATA_WIDTH-1:0] m_axis_tdata,
    output logic [MASTER_KEEP_WIDTH-1:0] m_axis_tkeep,
    output logic                         m_axis_tvalid,
    input  logic                         m_axis_tready,
    output logic                         m_axis_tlast,
    input  logic [ SLAVE_DATA_WIDTH-1:0] s_axis_tdata,
    input  logic [ SLAVE_KEEP_WIDTH-1:0] s_axis_tkeep,
    input  logic                         s_axis_tvalid,
    output logic                         s_axis_tready,
    input  logic                         s_axis_tlast
);
  localparam int RATIO = SLAVE_DATA_WIDTH / MASTER_DATA_WIDTH;
  localparam int CNT_WIDTH = (RATIO <= 1) ? 1 : $clog2(RATIO);

  logic [SLAVE_DATA_WIDTH-1:0] data_buf      [2];
  logic [SLAVE_KEEP_WIDTH-1:0] keep_buf      [2];
  logic                        last_buf      [2];
  logic [       CNT_WIDTH-1:0] last_chunk_buf[2];

  logic wr_ptr, rd_ptr;
  logic [          1:0] count;
  logic [CNT_WIDTH-1:0] beat_cnt_r;
  logic [CNT_WIDTH-1:0] last_chunk_w;
  logic m_axis_fire_w, s_axis_fire_w, beat_last_w;
  logic word_push_w, word_pop_w;

  assign s_axis_tready = aresetn && (count < 2'd2);
  assign s_axis_fire_w = s_axis_tvalid && s_axis_tready;
  assign word_push_w   = s_axis_fire_w;

  always_comb begin
    last_chunk_w = CNT_WIDTH'(RATIO - 1);
    for (int c = 0; c < RATIO; c++) if (|s_axis_tkeep[c*MASTER_KEEP_WIDTH+:MASTER_KEEP_WIDTH]) last_chunk_w = CNT_WIDTH'(c);
  end

  always_ff @(posedge aclk) begin
    if (word_push_w) begin
      data_buf[wr_ptr]       <= s_axis_tdata;
      keep_buf[wr_ptr]       <= s_axis_tkeep;
      last_buf[wr_ptr]       <= s_axis_tlast;
      last_chunk_buf[wr_ptr] <= last_chunk_w;
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) wr_ptr <= 1'b0;
    else if (word_push_w) wr_ptr <= ~wr_ptr;
  end

  assign beat_last_w = last_buf[rd_ptr] ? (beat_cnt_r == last_chunk_buf[rd_ptr])
                                             : (beat_cnt_r == CNT_WIDTH'(RATIO - 1));

  assign m_axis_tvalid = (count > 2'd0);
  assign m_axis_tdata  = data_buf[rd_ptr][beat_cnt_r*MASTER_DATA_WIDTH+:MASTER_DATA_WIDTH];
  assign m_axis_tkeep  = keep_buf[rd_ptr][beat_cnt_r*MASTER_KEEP_WIDTH+:MASTER_KEEP_WIDTH];
  assign m_axis_tlast  = last_buf[rd_ptr] && beat_last_w;
  assign m_axis_fire_w = m_axis_tvalid && m_axis_tready;
  assign word_pop_w    = m_axis_fire_w && beat_last_w;

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      rd_ptr     <= 1'b0;
      beat_cnt_r <= '0;
    end else if (m_axis_fire_w) begin
      if (beat_last_w) begin
        rd_ptr     <= ~rd_ptr;
        beat_cnt_r <= '0;
      end else begin
        beat_cnt_r <= beat_cnt_r + 1'b1;
      end
    end
  end

  always_ff @(posedge aclk) begin
    if (!aresetn) count <= '0;
    else
      case ({
        word_push_w, word_pop_w
      })
        2'b10:   count <= count + 2'd1;
        2'b01:   count <= count - 2'd1;
        default: count <= count;
      endcase
  end

endmodule
