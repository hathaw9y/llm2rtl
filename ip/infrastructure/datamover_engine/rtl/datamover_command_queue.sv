// Direction-local command/response accounting. Recovery policy belongs to
// the scheduler. No automatic adapter abort, reset, queue flush or retry.
module datamover_command_queue #(
  parameter integer BANK_NUM=4,
  parameter integer BANK_WIDTH=(BANK_NUM<=1)?1:$clog2(BANK_NUM),
  parameter integer DEPTH=16,
  parameter integer DDR_ALIGN_BYTES=8,
  parameter logic [BANK_NUM*32-1:0] BANK_WORD_BYTES={BANK_NUM{32'd8}},
  parameter logic [BANK_NUM*32-1:0] BANK_CAPACITY_BYTES={BANK_NUM{32'd4096}}
) (
  input logic aclk,aresetn,
  input logic pause, scheduler_abort,
  input logic cmd_valid, output logic cmd_ready,
  input logic [31:0] cmd_addr,
  input logic [22:0] cmd_btt,cmd_offset,
  input logic [BANK_WIDTH-1:0] cmd_bank,
  output logic dma_cmd_valid,input logic dma_cmd_ready,
  output logic [71:0] dma_cmd_data,
  input logic status_valid,output logic status_ready,
  input logic [7:0] status_data,input logic status_keep,status_last,
  output logic head_active,
  output logic [BANK_WIDTH-1:0] head_bank,
  output logic [22:0] head_offset,head_btt,
  input logic adapter_done,
  output logic adapter_finished,
  output logic completion_valid,input logic completion_ready,
  output logic [BANK_WIDTH-1:0] completion_bank,
  output logic [3:0] completion_tag,completion_received_tag,
  output logic [7:0] completion_code,completion_raw_status,
  output logic faulted
);
  localparam integer META_WIDTH=BANK_WIDTH+46+4+8;
  // Descriptor processing is intentionally split into capture, bank-table
  // selection/basic validation, and final local-range validation.  Besides
  // isolating the scheduler interface from validation, this prevents a
  // parameter-selected divide/modulo and capacity adder from forming one
  // command-input-to-result path.
  logic capture_valid_r,precheck_valid_r,pending_r;
  logic [31:0] address_r;
  logic [22:0] btt_r,offset_r;
  logic [BANK_WIDTH-1:0] bank_r;
  logic [3:0] next_tag_r,tag_r,head_tag;
  logic [7:0] basic_code_w,basic_code_r,descriptor_code_w,descriptor_code_r,head_code;
  logic [31:0] word_mask_w,word_mask_r,capacity_w,capacity_r;
  logic empty_w,full_w,push_w,pop_w;
  logic status_seen_r,adapter_seen_r;
  logic abort_response_pending_r;
  logic [7:0] raw_status_r,status_code_w;
  logic status_fire_w;
  initial begin
    if(DEPTH<1 || DEPTH>16) $fatal(1,"DEPTH must be 1..16 for four-bit tags");
    if(BANK_NUM<1 || BANK_NUM>(2**BANK_WIDTH) || DDR_ALIGN_BYTES<1
       || ((DDR_ALIGN_BYTES & (DDR_ALIGN_BYTES-1)) != 0))
      $fatal(1,"invalid bank/alignment configuration");
    for(integer i=0;i<BANK_NUM;i=i+1) begin
      if(BANK_WORD_BYTES[i*32+:32]==0 || BANK_CAPACITY_BYTES[i*32+:32]==0)
        $fatal(1,"bank word size and capacity must be positive");
      if((BANK_WORD_BYTES[i*32+:32] & (BANK_WORD_BYTES[i*32+:32]-1)) != 0)
        $fatal(1,"bank word size must be a power of two");
    end
  end
  always_comb begin
    word_mask_w=0;capacity_w=0;
    if(int'(bank_r)<BANK_NUM) begin
      // Every table entry is elaboration-time constant and power-of-two, so
      // alignment is a mask check rather than a dynamic modulo operator.
      word_mask_w=BANK_WORD_BYTES[int'(bank_r)*32+:32]-1;
      capacity_w=BANK_CAPACITY_BYTES[int'(bank_r)*32+:32];
    end
    basic_code_w=0;
    if(btt_r==0) basic_code_w=8'h01;
    else if((address_r & (DDR_ALIGN_BYTES-1))!=0) basic_code_w=8'h02;
    else if(({1'b0,address_r}+{10'd0,btt_r})>33'h1_0000_0000) basic_code_w=8'h03;
    else if(int'(bank_r)>=BANK_NUM) basic_code_w=8'h04;

    descriptor_code_w=basic_code_r;
    if(basic_code_r==0) begin
      if((32'(offset_r) & word_mask_r)!=0) descriptor_code_w=8'h05;
      else if(({10'd0,offset_r}+{10'd0,btt_r})>{1'b0,capacity_r}) descriptor_code_w=8'h06;
    end
  end
  // Reserve one metadata slot before offering a command to DataMover.
  // Once staged, command VALID/data remain stable even if pause/fault arrives.
  assign cmd_ready=aresetn && !pause && !scheduler_abort && !faulted
                   && !capture_valid_r && !precheck_valid_r && !pending_r && !full_w;
  assign dma_cmd_valid=pending_r && descriptor_code_r==0;
  assign dma_cmd_data={4'd0,tag_r,address_r,1'b0,1'b1,6'd0,1'b1,btt_r};
  assign push_w=pending_r && (descriptor_code_r!=0 || dma_cmd_ready);
  assign pop_w=completion_valid && completion_ready && !faulted && !scheduler_abort;
  fifo #(.FIFO_DEPTH(DEPTH),.DATA_WIDTH(META_WIDTH)) metadata (
    .aclk(aclk),.aresetn(aresetn),.push(push_w),.pop(pop_w),
    .din({descriptor_code_r,tag_r,bank_r,offset_r,btt_r}),
    .dout({head_code,head_tag,head_bank,head_offset,head_btt}),
    .empty(empty_w),.full(full_w),.count());
  assign head_active=!empty_w && head_code==0;
  assign adapter_finished=adapter_seen_r || adapter_done;
  // Invalid descriptors have no DataMover status. Later statuses wait behind
  // them. Empty-queue status is consumed and reported as an unsolicited fault.
  assign status_ready=aresetn && !faulted && !status_seen_r && !completion_valid
                     && (head_active || (empty_w && !capture_valid_r
                                                   && !precheck_valid_r && !pending_r));
  assign status_fire_w=status_valid && status_ready;
  always_comb begin
    status_code_w=0;
    if(empty_w) status_code_w=8'h40;
    else if(!status_keep || !status_last) status_code_w=8'h30;
    else if(status_data[3:0]!=head_tag) status_code_w=8'h20;
    else if(!status_data[7] || (|status_data[6:4])) status_code_w=8'h10;
  end
  always_ff @(posedge aclk) begin
    if(!aresetn) begin
      capture_valid_r<=0;precheck_valid_r<=0;pending_r<=0;
      address_r<=0;btt_r<=0;offset_r<=0;bank_r<='0;
      next_tag_r<=0;tag_r<=0;descriptor_code_r<=0;
      basic_code_r<=0;word_mask_r<=0;capacity_r<=0;
      status_seen_r<=0;adapter_seen_r<=0;raw_status_r<=0;faulted<=0;
      abort_response_pending_r<=0;
      completion_valid<=0;completion_bank<='0;completion_tag<=0;
      completion_received_tag<=0;completion_code<=0;completion_raw_status<=0;
    end else begin
      if(cmd_valid && cmd_ready) begin
        capture_valid_r<=1;address_r<=cmd_addr;btt_r<=cmd_btt;offset_r<=cmd_offset;
        bank_r<=cmd_bank;tag_r<=next_tag_r;next_tag_r<=next_tag_r+4'd1;
      end
      if(capture_valid_r) begin
        capture_valid_r<=0;precheck_valid_r<=1;
        basic_code_r<=basic_code_w;word_mask_r<=word_mask_w;capacity_r<=capacity_w;
      end
      if(precheck_valid_r) begin
        precheck_valid_r<=0;pending_r<=1;descriptor_code_r<=descriptor_code_w;
      end
      if(push_w) pending_r<=0;
      if(head_active && adapter_done) adapter_seen_r<=1;
      if(completion_valid && completion_ready) completion_valid<=0;
      if(pop_w) begin status_seen_r<=0;adapter_seen_r<=0;raw_status_r<=0;end
      if(status_fire_w) begin
        status_seen_r<=1;raw_status_r<=status_data;
        if(status_code_w!=0) begin
          // Report without waiting for an adapter that may never complete.
          // Keep head ownership; only scheduler-controlled recovery can release it.
          faulted<=1;completion_valid<=1;completion_code<=status_code_w;
          completion_bank<=empty_w?'0:head_bank;
          completion_tag<=empty_w?4'd0:head_tag;
          completion_received_tag<=status_data[3:0];completion_raw_status<=status_data;
        end
      end
      if(!faulted && !scheduler_abort && !completion_valid && !empty_w
         && !(status_fire_w && status_code_w!=0)) begin
        if(head_code!=0 || (status_seen_r && adapter_seen_r)) begin
          completion_valid<=1;completion_code<=head_code;
          completion_bank<=head_bank;completion_tag<=head_tag;
          completion_received_tag<=head_code!=0?4'd0:raw_status_r[3:0];
          completion_raw_status<=head_code!=0?8'd0:raw_status_r;
        end
      end
      // Abort has priority over every response newly formed on this edge.
      // An already-offered response remains stable; after its handshake the
      // abort diagnostic is offered without retiring the retained FIFO head.
      if(scheduler_abort && !faulted) begin
        faulted<=1;
        if(completion_valid) begin
          if(completion_ready) begin
            completion_valid<=1;completion_code<=8'h50;
            completion_bank<=empty_w?'0:head_bank;
            completion_tag<=empty_w?4'd0:head_tag;
            completion_received_tag<=0;completion_raw_status<=0;
          end else begin
            abort_response_pending_r<=1;
          end
        end else begin
          completion_valid<=1;completion_code<=8'h50;
          completion_bank<=empty_w?'0:head_bank;
          completion_tag<=empty_w?4'd0:head_tag;
          completion_received_tag<=status_fire_w?status_data[3:0]:4'd0;
          completion_raw_status<=status_fire_w?status_data:8'd0;
        end
      end
      if(abort_response_pending_r && completion_valid && completion_ready) begin
        abort_response_pending_r<=0;completion_valid<=1;completion_code<=8'h50;
        completion_bank<=empty_w?'0:head_bank;
        completion_tag<=empty_w?4'd0:head_tag;
        completion_received_tag<=0;completion_raw_status<=0;
      end
    end
  end
endmodule
