`timescale 1ns/1ps

module tb_stream_bank_adapters;
  logic aclk = 1'b0;
  logic aresetn = 1'b0;
  always #2.5 aclk = ~aclk;

  logic mm_start, mm_done, mm_abort;
  logic [22:0] mm_offset;
  logic [3:0] mm_bank;
  logic [63:0] s_data;
  logic [7:0] s_keep;
  logic s_valid, s_ready, s_last;
  logic bw_valid, bw_ready;
  logic [3:0] bw_bank;
  logic [31:0] bw_addr;
  logic [15:0] bw_strb;
  logic [127:0] bw_data;

  logic sm_start, sm_done, sm_abort;
  logic [22:0] sm_offset, sm_count;
  logic rd_valid, rd_ready;
  logic [31:0] rd_addr;
  logic rsp_valid;
  logic [1023:0] rsp_data;
  logic [63:0] m_data;
  logic [7:0] m_keep;
  logic m_valid, m_ready, m_last;

  logic mm_random_ready, sm_random_ready;
  integer failures = 0;
  integer mm_write_count = 0;
  logic [3:0] mm_seen_bank [0:15];
  logic [31:0] mm_seen_addr [0:15];
  logic [15:0] mm_seen_strb [0:15];
  logic [127:0] mm_seen_data [0:15];

  integer request_count = 0;
  integer response_count = 0;
  integer output_count = 0;
  logic model_pending;
  integer model_delay;
  logic [31:0] model_addr;
  logic model_enable;

  logic bw_stalled_r, m_stalled_r, rd_stalled_r;
  logic [3:0] bw_bank_hold_r;
  logic [31:0] bw_addr_hold_r, rd_addr_hold_r;
  logic [15:0] bw_strb_hold_r;
  logic [127:0] bw_data_hold_r;
  logic [63:0] m_data_hold_r;
  logic [7:0] m_keep_hold_r;
  logic m_last_hold_r;

  mm2s_stream_bank_adapter u_mm2s (
      .aclk, .aresetn, .s_ctrl_start(mm_start), .s_ctrl_done(mm_done),
      .s_ctrl_abort(mm_abort), .s_ctrl_byte_offset(mm_offset), .s_ctrl_bank(mm_bank),
      .s_axis_tdata(s_data), .s_axis_tkeep(s_keep), .s_axis_tvalid(s_valid),
      .s_axis_tready(s_ready), .s_axis_tlast(s_last),
      .bank_write_valid(bw_valid), .bank_write_ready(bw_ready),
      .bank_write_bank(bw_bank), .bank_write_addr(bw_addr),
      .bank_write_strb(bw_strb), .bank_write_data(bw_data));

  s2mm_stream_bank_adapter u_s2mm (
      .aclk, .aresetn, .s_ctrl_start(sm_start), .s_ctrl_done(sm_done),
      .s_ctrl_abort(sm_abort), .s_ctrl_byte_offset(sm_offset),
      .s_ctrl_byte_count(sm_count), .s2mm_read_valid(rd_valid),
      .s2mm_read_ready(rd_ready), .s2mm_read_addr(rd_addr),
      .s2mm_rsp_valid(rsp_valid), .s2mm_rsp_data(rsp_data),
      .m_axis_tdata(m_data), .m_axis_tkeep(m_keep), .m_axis_tvalid(m_valid),
      .m_axis_tready(m_ready), .m_axis_tlast(m_last));

  function automatic logic [1023:0] make_word(input logic [31:0] address);
    logic [1023:0] value;
    integer i;
    begin
      value = '0;
      for (i = 0; i < 16; i = i + 1)
        value[i*64 +: 64] = {address, 24'h5a_c300, i[7:0]};
      make_word = value;
    end
  endfunction

  task automatic check(input logic condition, input string message);
    begin
      if (!condition) begin
        failures = failures + 1;
        $display("FAIL: %s at %0t", message, $time);
      end
    end
  endtask

  task automatic drive_mm_beat(input logic [63:0] data,
                               input logic [7:0] keep,
                               input logic last);
    begin
      @(negedge aclk);
      s_data = data;
      s_keep = keep;
      s_last = last;
      s_valid = 1'b1;
      do @(posedge aclk); while (!s_ready);
      @(negedge aclk);
      s_valid = 1'b0;
      s_last = 1'b0;
    end
  endtask

  task automatic start_mm(input logic [22:0] offset, input logic [3:0] bank);
    begin
      @(negedge aclk);
      mm_offset = offset;
      mm_bank = bank;
      mm_start = 1'b1;
      @(posedge aclk);
    end
  endtask

  task automatic release_mm;
    begin
      wait (mm_done);
      repeat (3) begin
        @(posedge aclk);
        check(mm_done, "MM2S done held while start remains high");
      end
      @(negedge aclk);
      mm_start = 1'b0;
      do @(posedge aclk); while (mm_done);
    end
  endtask

  task automatic start_sm(input logic [22:0] offset, input logic [22:0] count);
    begin
      @(negedge aclk);
      sm_offset = offset;
      sm_count = count;
      sm_start = 1'b1;
      @(posedge aclk);
    end
  endtask

  task automatic release_sm;
    begin
      wait (sm_done);
      repeat (3) begin
        @(posedge aclk);
        check(sm_done, "S2MM done held while start remains high");
      end
      @(negedge aclk);
      sm_start = 1'b0;
      do @(posedge aclk); while (sm_done);
    end
  endtask

  always @(negedge aclk) begin
    if (mm_random_ready) bw_ready <= ($urandom_range(0, 3) != 0);
    if (sm_random_ready) begin
      rd_ready <= ($urandom_range(0, 3) != 0);
      m_ready <= ($urandom_range(0, 2) != 0);
    end
  end

  always @(posedge aclk) begin
    rsp_valid <= 1'b0;
    if (!aresetn || !model_enable) begin
      model_pending <= 1'b0;
      model_delay <= 0;
    end else begin
      if (rd_valid && rd_ready) begin
        check(!model_pending, "duplicate bank request while response outstanding");
        model_pending <= 1'b1;
        model_addr <= rd_addr;
        model_delay <= $urandom_range(0, 5);
        request_count <= request_count + 1;
      end
      if (model_pending) begin
        if (model_delay == 0) begin
          rsp_valid <= 1'b1;
          rsp_data <= make_word(model_addr);
          model_pending <= 1'b0;
          response_count <= response_count + 1;
        end else begin
          model_delay <= model_delay - 1;
        end
      end
    end

    if (aresetn && bw_valid && bw_ready) begin
      mm_seen_bank[mm_write_count] <= bw_bank;
      mm_seen_addr[mm_write_count] <= bw_addr;
      mm_seen_strb[mm_write_count] <= bw_strb;
      mm_seen_data[mm_write_count] <= bw_data;
      mm_write_count <= mm_write_count + 1;
    end

    if (aresetn && bw_stalled_r) begin
      check(bw_valid, "MM2S write valid dropped under stall");
      check(bw_bank == bw_bank_hold_r && bw_addr == bw_addr_hold_r &&
            bw_strb == bw_strb_hold_r && bw_data == bw_data_hold_r,
            "MM2S write fields changed under stall");
    end
    bw_stalled_r <= aresetn && bw_valid && !bw_ready;
    if (bw_valid && !bw_ready) begin
      bw_bank_hold_r <= bw_bank;
      bw_addr_hold_r <= bw_addr;
      bw_strb_hold_r <= bw_strb;
      bw_data_hold_r <= bw_data;
    end

    if (aresetn && m_stalled_r) begin
      check(m_valid, "S2MM AXIS valid dropped under stall");
      check(m_data == m_data_hold_r && m_keep == m_keep_hold_r &&
            m_last == m_last_hold_r, "S2MM AXIS fields changed under stall");
    end
    m_stalled_r <= aresetn && m_valid && !m_ready;
    if (m_valid && !m_ready) begin
      m_data_hold_r <= m_data;
      m_keep_hold_r <= m_keep;
      m_last_hold_r <= m_last;
    end

    if (aresetn && rd_stalled_r) begin
      check(rd_valid, "S2MM request valid dropped under stall");
      check(rd_addr == rd_addr_hold_r, "S2MM request address changed under stall");
    end
    rd_stalled_r <= aresetn && rd_valid && !rd_ready;
    if (rd_valid && !rd_ready) rd_addr_hold_r <= rd_addr;
  end

  initial begin : timeout_block
    #200000;
    $fatal(1, "FAIL: timeout");
  end

  initial begin : stimulus
    integer base_writes;
    integer base_requests;
    integer base_outputs;
    integer beat;
    integer expected_beats;
    integer current_word;
    logic [63:0] expected_data;
    logic [7:0] expected_keep;

    mm_start = 0; mm_abort = 0; mm_offset = 0; mm_bank = 0;
    s_data = 0; s_keep = 0; s_valid = 0; s_last = 0;
    bw_ready = 0; mm_random_ready = 0;
    sm_start = 0; sm_abort = 0; sm_offset = 0; sm_count = 0;
    rd_ready = 0; rsp_valid = 0; rsp_data = 0; m_ready = 0;
    sm_random_ready = 0; model_enable = 1;
    model_pending = 0; model_delay = 0; model_addr = 0;
    bw_stalled_r = 0; m_stalled_r = 0; rd_stalled_r = 0;

    repeat (4) @(posedge aclk);
    @(negedge aclk); aresetn = 1'b1;

    // MM2S: one full native word followed by a one-beat partial word.
    base_writes = mm_write_count;
    mm_random_ready = 1;
    start_mm(23'd64, 4'd2);
    drive_mm_beat(64'h0706_0504_0302_0100, 8'hff, 1'b0);
    drive_mm_beat(64'h0f0e_0d0c_0b0a_0908, 8'hff, 1'b0);
    drive_mm_beat(64'h1716_1514_1312_1110, 8'h0f, 1'b1);
    release_mm();
    check(mm_write_count == base_writes + 2, "MM2S full/partial write count");
    check(mm_seen_bank[base_writes] == 4'd2, "MM2S bank captured");
    check(mm_seen_addr[base_writes] == 32'd4 &&
          mm_seen_addr[base_writes+1] == 32'd5, "MM2S native address sequence");
    check(mm_seen_strb[base_writes] == 16'hffff &&
          mm_seen_strb[base_writes+1] == 16'h000f, "MM2S keep packing");
    check(mm_seen_data[base_writes] ==
          128'h0f0e0d0c0b0a0908_0706050403020100, "MM2S data packing");

    // MM2S final keep in the upper half of a two-beat native word.
    base_writes = mm_write_count;
    start_mm(23'd32, 4'd0);
    drive_mm_beat(64'haaaa_bbbb_cccc_dddd, 8'hff, 1'b0);
    drive_mm_beat(64'h1111_2222_3333_4444, 8'h03, 1'b1);
    release_mm();
    check(mm_write_count == base_writes + 1, "MM2S upper partial write count");
    check(mm_seen_strb[base_writes] == 16'h03ff, "MM2S upper partial keep");

    // MM2S abort discards an unpaired beat.
    base_writes = mm_write_count;
    start_mm(23'd0, 4'd1);
    drive_mm_beat(64'hdead_beef_0123_4567, 8'hff, 1'b0);
    @(negedge aclk); mm_abort = 1'b1;
    @(posedge aclk); @(negedge aclk); mm_abort = 1'b0;
    release_mm();
    check(mm_write_count == base_writes, "MM2S abort discarded half word");

    // MM2S keeps a completed write stable through abort and bank stall.
    mm_random_ready = 0; bw_ready = 0;
    base_writes = mm_write_count;
    start_mm(23'd16, 4'd3);
    drive_mm_beat(64'h1111_2222_3333_4444, 8'hff, 1'b1);
    wait (bw_valid); repeat (3) @(posedge aclk);
    @(negedge aclk); mm_abort = 1'b1; repeat (2) @(posedge aclk);
    @(negedge aclk); bw_ready = 1'b1;
    @(posedge aclk); @(negedge aclk); mm_abort = 1'b0; bw_ready = 1'b0;
    release_mm();
    check(mm_write_count == base_writes + 1, "MM2S stalled irrevocable write on abort");

    // S2MM: 150 bytes => one full word and 22-byte partial word.
    sm_random_ready = 1;
    base_requests = request_count;
    base_outputs = output_count;
    start_sm(23'd256, 23'd150);
    expected_beats = 19;
    beat = 0;
    while (beat < expected_beats) begin
      @(posedge aclk);
      if (m_valid && m_ready) begin
        current_word = beat / 16;
        expected_data = {32'(2 + current_word), 24'h5a_c300, 8'(beat % 16)};
        expected_keep = (beat == expected_beats-1) ? 8'h3f : 8'hff;
        check(m_data == expected_data, "S2MM serialized payload");
        check(m_keep == expected_keep, "S2MM partial keep");
        check(m_last == (beat == expected_beats-1), "S2MM last placement");
        beat = beat + 1;
        output_count = output_count + 1;
      end
    end
    release_sm();
    check(request_count == base_requests + 2, "S2MM native request count");
    check(response_count == request_count, "S2MM response count");
    check(output_count == base_outputs + 19, "S2MM output count");

    // Repeated short transaction and zero byte-count completion.
    start_sm(23'd128, 23'd5);
    do @(posedge aclk); while (!(m_valid && m_ready));
    check(m_keep == 8'h1f && m_last, "S2MM five-byte final beat");
    release_sm();
    start_sm(23'd0, 23'd0);
    release_sm();

    // Abort while a request is outstanding drains its response, emits no data.
    sm_random_ready = 0; rd_ready = 1; m_ready = 1;
    base_outputs = output_count;
    start_sm(23'd0, 23'd64);
    wait (u_s2mm.outstanding_r);
    @(negedge aclk); sm_abort = 1'b1;
    @(posedge aclk); @(negedge aclk); sm_abort = 1'b0;
    release_sm();
    check(output_count == base_outputs, "S2MM abort while outstanding emitted no data");

    // Abort while an AXIS beat is stalled preserves that offered beat.
    start_sm(23'd0, 23'd32);
    wait (m_valid);
    @(negedge aclk); m_ready = 0; sm_abort = 1;
    repeat (3) @(posedge aclk);
    @(negedge aclk); m_ready = 1;
    @(posedge aclk); @(negedge aclk); sm_abort = 0;
    release_sm();

    // Synchronous reset during an outstanding request removes all old state.
    start_sm(23'd0, 23'd64);
    wait (u_s2mm.outstanding_r);
    @(negedge aclk); aresetn = 0;
    repeat (2) @(posedge aclk);
    check(!rd_valid && !m_valid && !sm_done && !bw_valid && !mm_done,
          "synchronous reset clears public state");
    @(negedge aclk); sm_start = 0; aresetn = 1; model_enable = 1;
    repeat (3) @(posedge aclk);

    if (failures == 0) begin
      $display("PASS stream_bank_adapters randomized stalls full partial abort reset repeated no_duplicate");
      $finish;
    end else begin
      $fatal(1, "FAIL stream_bank_adapters failures=%0d", failures);
    end
  end
endmodule
