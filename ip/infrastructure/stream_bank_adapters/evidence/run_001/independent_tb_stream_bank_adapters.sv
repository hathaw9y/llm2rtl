`timescale 1ns/1ps

module independent_tb_stream_bank_adapters;
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

  integer failures = 0;
  integer mm_handshakes = 0;
  integer rd_handshakes = 0;
  integer rsp_pulses = 0;
  integer axis_handshakes = 0;
  logic random_mm_ready, random_sm_ready;

  logic rsp_pending;
  integer rsp_delay;
  logic [31:0] rsp_addr_pending;

  logic bw_stalled_r, rd_stalled_r, m_stalled_r;
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

  function automatic logic [63:0] mm_pattern(input integer txn, input integer beat);
    mm_pattern = {16'(txn), 16'(beat), 32'h9e37_79b9 ^ (txn * 32'd257 + beat)};
  endfunction

  function automatic logic [1023:0] bank_word(input logic [31:0] address);
    logic [1023:0] value;
    integer i;
    begin
      value = '0;
      for (i = 0; i < 16; i = i + 1)
        value[i*64 +: 64] = {address, 16'hc35a, 8'(i), 8'h5d};
      bank_word = value;
    end
  endfunction

  function automatic logic [7:0] final_keep(input integer byte_count);
    integer rem;
    begin
      rem = byte_count % 8;
      if (rem == 0) final_keep = 8'hff;
      else final_keep = (8'h1 << rem) - 1;
    end
  endfunction

  task automatic fail(input string message);
    begin
      failures = failures + 1;
      $display("INDEPENDENT_FAIL %s time=%0t", message, $time);
    end
  endtask

  task automatic check_ok(input logic condition, input string message);
    if (!condition) fail(message);
  endtask

  task automatic mm_send_beat(input logic [63:0] data,
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

  task automatic release_mm;
    integer i;
    begin
      wait (mm_done);
      for (i = 0; i < 3; i = i + 1) begin
        @(posedge aclk);
        check_ok(mm_done, "MM2S done was not held while start stayed high");
      end
      @(negedge aclk);
      mm_start = 1'b0;
      do @(posedge aclk); while (mm_done);
    end
  endtask

  task automatic run_mm_packet(input integer txn,
                               input integer beats,
                               input integer tail_bytes);
    integer base_hs;
    integer write_index;
    integer beat;
    integer expected_writes;
    logic [63:0] low_data;
    logic [7:0] low_keep;
    logic [127:0] expected_data;
    logic [15:0] expected_strb;
    logic [7:0] keep;
    begin
      base_hs = mm_handshakes;
      expected_writes = (beats + 1) / 2;
      @(negedge aclk);
      mm_offset = txn * 16;
      mm_bank = txn[3:0];
      mm_start = 1'b1;
      @(posedge aclk);

      write_index = 0;
      low_data = '0;
      low_keep = '0;
      fork
        begin : sender
          for (beat = 0; beat < beats; beat = beat + 1) begin
            keep = (beat == beats-1) ? ((8'h1 << tail_bytes) - 1) : 8'hff;
            mm_send_beat(mm_pattern(txn, beat), keep, beat == beats-1);
          end
        end
        begin : write_checker
          while (write_index < expected_writes) begin
            @(posedge aclk);
            if (bw_valid && bw_ready) begin
              if ((write_index*2 + 1) < beats) begin
                expected_data = {mm_pattern(txn, write_index*2+1),
                                 mm_pattern(txn, write_index*2)};
                expected_strb = {(write_index*2+1 == beats-1) ?
                                 ((8'h1 << tail_bytes) - 1) : 8'hff, 8'hff};
              end else begin
                expected_data = {64'd0, mm_pattern(txn, write_index*2)};
                expected_strb = {8'h00, ((8'h1 << tail_bytes) - 1)};
              end
              check_ok(bw_bank == txn[3:0], "MM2S captured bank mismatch");
              check_ok(bw_addr == txn + write_index, "MM2S handshake address mismatch");
              check_ok(bw_data == expected_data, "MM2S randomized packed data mismatch");
              check_ok(bw_strb == expected_strb, "MM2S randomized packed keep mismatch");
              write_index = write_index + 1;
            end
          end
        end
      join
      release_mm();
      check_ok(mm_handshakes == base_hs + expected_writes,
             "MM2S randomized write count mismatch");
    end
  endtask

  task automatic release_sm;
    integer i;
    begin
      wait (sm_done);
      for (i = 0; i < 3; i = i + 1) begin
        @(posedge aclk);
        check_ok(sm_done, "S2MM done was not held while start stayed high");
      end
      @(negedge aclk);
      sm_start = 1'b0;
      do @(posedge aclk); while (sm_done);
    end
  endtask

  task automatic run_sm_packet(input integer txn, input integer byte_count);
    integer base_rd;
    integer base_axis;
    integer beat;
    integer expected_beats;
    integer expected_requests;
    integer native_addr;
    integer chunk;
    logic [63:0] expected_data;
    logic [7:0] expected_keep;
    begin
      base_rd = rd_handshakes;
      base_axis = axis_handshakes;
      expected_beats = (byte_count + 7) / 8;
      expected_requests = (byte_count + 127) / 128;
      @(negedge aclk);
      sm_offset = txn * 128;
      sm_count = byte_count;
      sm_start = 1'b1;
      @(posedge aclk);
      beat = 0;
      while (beat < expected_beats) begin
        @(posedge aclk);
        if (m_valid && m_ready) begin
          native_addr = txn + beat/16;
          chunk = beat % 16;
          expected_data = {32'(native_addr), 16'hc35a, 8'(chunk), 8'h5d};
          expected_keep = (beat == expected_beats-1) ? final_keep(byte_count) : 8'hff;
          check_ok(m_data == expected_data, "S2MM randomized serialization/order mismatch");
          check_ok(m_keep == expected_keep, "S2MM randomized final keep mismatch");
          check_ok(m_last == (beat == expected_beats-1), "S2MM randomized last mismatch");
          beat = beat + 1;
        end
      end
      release_sm();
      check_ok(rd_handshakes == base_rd + expected_requests,
             "S2MM randomized request count mismatch");
      check_ok(axis_handshakes == base_axis + expected_beats,
             "S2MM randomized output count mismatch");
    end
  endtask

  always @(negedge aclk) begin
    if (random_mm_ready) bw_ready <= ($urandom_range(0, 4) != 0);
    if (random_sm_ready) begin
      rd_ready <= ($urandom_range(0, 3) != 0);
      m_ready <= ($urandom_range(0, 2) != 0);
    end
  end

  always @(posedge aclk) begin
    rsp_valid <= 1'b0;
    if (!aresetn) begin
      rsp_pending <= 1'b0;
      rsp_delay <= 0;
    end else begin
      if (rd_valid && rd_ready) begin
        check_ok(!rsp_pending, "S2MM duplicate request while response pending");
        rsp_pending <= 1'b1;
        rsp_addr_pending <= rd_addr;
        rsp_delay <= $urandom_range(1, 7);
        rd_handshakes <= rd_handshakes + 1;
      end
      if (rsp_pending) begin
        if (rsp_delay == 0) begin
          rsp_valid <= 1'b1;
          rsp_data <= bank_word(rsp_addr_pending);
          rsp_pending <= 1'b0;
          rsp_pulses <= rsp_pulses + 1;
        end else rsp_delay <= rsp_delay - 1;
      end
    end

    if (aresetn && bw_valid && bw_ready) mm_handshakes <= mm_handshakes + 1;
    if (aresetn && m_valid && m_ready) axis_handshakes <= axis_handshakes + 1;

    if (aresetn && bw_stalled_r) begin
      check_ok(bw_valid, "MM2S bank valid dropped during stall");
      check_ok(bw_bank == bw_bank_hold_r && bw_addr == bw_addr_hold_r &&
             bw_strb == bw_strb_hold_r && bw_data == bw_data_hold_r,
             "MM2S bank payload changed during stall");
    end
    bw_stalled_r <= aresetn && bw_valid && !bw_ready;
    if (bw_valid && !bw_ready) begin
      bw_bank_hold_r <= bw_bank;
      bw_addr_hold_r <= bw_addr;
      bw_strb_hold_r <= bw_strb;
      bw_data_hold_r <= bw_data;
    end

    if (aresetn && rd_stalled_r) begin
      check_ok(rd_valid, "S2MM request valid dropped during stall");
      check_ok(rd_addr == rd_addr_hold_r, "S2MM request address changed during stall");
    end
    rd_stalled_r <= aresetn && rd_valid && !rd_ready;
    if (rd_valid && !rd_ready) rd_addr_hold_r <= rd_addr;

    if (aresetn && m_stalled_r) begin
      check_ok(m_valid, "S2MM output valid dropped during stall");
      check_ok(m_data == m_data_hold_r && m_keep == m_keep_hold_r &&
             m_last == m_last_hold_r, "S2MM output changed during stall");
    end
    m_stalled_r <= aresetn && m_valid && !m_ready;
    if (m_valid && !m_ready) begin
      m_data_hold_r <= m_data;
      m_keep_hold_r <= m_keep;
      m_last_hold_r <= m_last;
    end
  end

  initial begin
    #1000000;
    $fatal(1, "INDEPENDENT_FAIL timeout");
  end

  initial begin : stimulus
    integer txn;
    integer base_mm;
    integer base_axis;

    mm_start = 0; mm_abort = 0; mm_offset = 0; mm_bank = 0;
    s_data = 0; s_keep = 0; s_valid = 0; s_last = 0;
    bw_ready = 0; random_mm_ready = 0;
    sm_start = 0; sm_abort = 0; sm_offset = 0; sm_count = 0;
    rd_ready = 0; rsp_valid = 0; rsp_data = 0; m_ready = 0;
    random_sm_ready = 0; rsp_pending = 0; rsp_delay = 0;
    bw_stalled_r = 0; rd_stalled_r = 0; m_stalled_r = 0;
    repeat (5) @(posedge aclk);
    @(negedge aclk); aresetn = 1'b1;

    random_mm_ready = 1;
    for (txn = 0; txn < 24; txn = txn + 1)
      run_mm_packet(txn, 1 + (txn % 11), 1 + ((txn * 3) % 8));

    // Abort an unpaired input beat: no bank write may be published.
    base_mm = mm_handshakes;
    @(negedge aclk); mm_offset = 0; mm_bank = 4'd7; mm_start = 1;
    @(posedge aclk);
    mm_send_beat(64'hfeed_face_dead_beef, 8'hff, 1'b0);
    @(negedge aclk); mm_abort = 1;
    @(posedge aclk); @(negedge aclk); mm_abort = 0;
    release_mm();
    check_ok(mm_handshakes == base_mm, "MM2S abort replayed unpaired half");

    random_sm_ready = 1;
    for (txn = 0; txn < 24; txn = txn + 1)
      run_sm_packet(txn, 1 + ((txn * 37) % 400));

    // Zero-byte repeated call must complete without a request.
    txn = rd_handshakes;
    @(negedge aclk); sm_offset = 0; sm_count = 0; sm_start = 1;
    @(posedge aclk); release_sm();
    check_ok(rd_handshakes == txn, "S2MM zero-byte command issued a request");

    // Abort with one request outstanding must drain response and emit no beat.
    random_sm_ready = 0; rd_ready = 1; m_ready = 1;
    base_axis = axis_handshakes;
    @(negedge aclk); sm_offset = 0; sm_count = 64; sm_start = 1;
    @(posedge aclk); wait (u_s2mm.outstanding_r);
    @(negedge aclk); sm_abort = 1;
    @(posedge aclk); @(negedge aclk); sm_abort = 0;
    release_sm();
    check_ok(axis_handshakes == base_axis, "S2MM abort emitted response payload");

    // Once an AXIS beat is offered, abort cannot retract or mutate it.
    base_axis = axis_handshakes;
    rd_ready = 1; m_ready = 0;
    @(negedge aclk); sm_offset = 0; sm_count = 32; sm_start = 1;
    @(posedge aclk); wait (m_valid);
    @(negedge aclk); sm_abort = 1;
    repeat (3) @(posedge aclk);
    @(negedge aclk); m_ready = 1;
    @(posedge aclk); @(negedge aclk); sm_abort = 0;
    release_sm();
    check_ok(axis_handshakes == base_axis + 1,
             "S2MM abort did not preserve exactly one irrevocable stalled beat");

    // Reset while outstanding must remove public and internal transaction state.
    @(negedge aclk); sm_offset = 0; sm_count = 64; sm_start = 1;
    @(posedge aclk); wait (u_s2mm.outstanding_r);
    @(negedge aclk); aresetn = 0;
    repeat (2) @(posedge aclk);
    check_ok(!rd_valid && !m_valid && !sm_done && !bw_valid && !mm_done,
           "Synchronous reset did not clear public state");
    @(negedge aclk); sm_start = 0; aresetn = 1;
    repeat (3) @(posedge aclk);

    // Successful calls after abort/reset prove repeatability.
    random_mm_ready = 1;
    run_mm_packet(29, 3, 5);
    random_sm_ready = 1;
    run_sm_packet(29, 257);

    check_ok(rsp_pulses <= rd_handshakes, "More responses than accepted requests");
    if (failures == 0) begin
      $display("INDEPENDENT_PASS stream_bank_adapters randomized_scoreboard mm_packets=25 s2mm_packets=25 abort reset repeat stable no_duplicate");
      $finish;
    end
    $fatal(1, "INDEPENDENT_FAIL failures=%0d", failures);
  end
endmodule
