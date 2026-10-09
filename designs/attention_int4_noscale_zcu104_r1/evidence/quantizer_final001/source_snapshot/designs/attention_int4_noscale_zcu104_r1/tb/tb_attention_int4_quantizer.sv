`timescale 1ns/1ps
module tb_attention_int4_quantizer #(
  parameter integer MAX_ELEMENTS=13,
  parameter integer ROW_COUNT=1,
  parameter integer COUNT_WIDTH=(MAX_ELEMENTS<2)?1:$clog2(MAX_ELEMENTS+1)
);
  logic aclk=0,aresetn=0;always #2.5 aclk=~aclk;
  logic cmd_valid=0;wire cmd_ready;logic[7:0]cmd_id=0;logic[COUNT_WIDTH-1:0]cmd_elements=0;
  logic s_axis_value_tvalid=0;wire s_axis_value_tready;logic[31:0]s_axis_value_tdata=0;
  wire m_axis_quant_tvalid;logic m_axis_quant_tready=0;wire[3:0]m_axis_quant_tdata;wire[15:0]m_axis_quant_tscale;wire m_axis_quant_tlast;
  wire resp_valid;logic resp_ready=0;wire[7:0]resp_id;wire resp_error;
  attention_int4_quantizer #(.MAX_ELEMENTS(MAX_ELEMENTS),.COUNT_WIDTH(COUNT_WIDTH))dut(.*);
  logic[31:0]inputs[0:MAX_ELEMENTS*512-1],metadata[0:511];logic[3:0]outputs[0:MAX_ELEMENTS*512-1];
  integer row_index=0,expected_count=0,input_count=0,output_count=0,completions=0,cycles=0,cases=0;
  logic active=0,expected_error=0,output_hold=0;logic[15:0]expected_scale=0;logic[7:0]expected_id=0;
  logic prior_output_stall=0,prior_resp_stall=0;logic[20:0]prior_output_fields=0;logic[8:0]prior_resp_fields=0;
  always @(posedge aclk)begin
    if(!aresetn)begin
      active=0;input_count=0;output_count=0;prior_output_stall=0;prior_resp_stall=0;
    end else begin
      cycles++;
      if(prior_output_stall && (!m_axis_quant_tvalid||{m_axis_quant_tlast,m_axis_quant_tscale,m_axis_quant_tdata}!==prior_output_fields))$fatal(1,"quant output changed under stall");
      if(prior_resp_stall && (!resp_valid||{resp_error,resp_id}!==prior_resp_fields))$fatal(1,"completion changed under stall");
      prior_output_stall=m_axis_quant_tvalid&&!m_axis_quant_tready;prior_output_fields={m_axis_quant_tlast,m_axis_quant_tscale,m_axis_quant_tdata};
      prior_resp_stall=resp_valid&&!resp_ready;prior_resp_fields={resp_error,resp_id};
      if(cmd_valid&&cmd_ready)begin
        if(active)$fatal(1,"second command accepted while active");active=1;input_count=0;output_count=0;
        if(cmd_id!==expected_id||cmd_elements!==COUNT_WIDTH'(expected_count))$fatal(1,"driver command mismatch");
      end
      if(s_axis_value_tvalid&&s_axis_value_tready)begin
        if(!active||input_count>=expected_count)$fatal(1,"input outside command/count");input_count++;
      end
      if(m_axis_quant_tvalid&&m_axis_quant_tready)begin
        if(!active||expected_error||input_count!=expected_count||output_count>=expected_count)$fatal(1,"unexpected quant output row%0d",row_index);
        if(m_axis_quant_tscale!==expected_scale||m_axis_quant_tdata!==outputs[row_index*MAX_ELEMENTS+output_count]||m_axis_quant_tlast!==(output_count==expected_count-1))
          $fatal(1,"quant mismatch max%0d row%0d index%0d gotq%h expq%h gotscale%h expscale%h last%0b",MAX_ELEMENTS,row_index,output_count,m_axis_quant_tdata,outputs[row_index*MAX_ELEMENTS+output_count],m_axis_quant_tscale,expected_scale,m_axis_quant_tlast);
        if(m_axis_quant_tdata==4'h8)$fatal(1,"forbidden minus8 code");output_count++;
      end
      if(resp_valid)begin
        if(!active||resp_id!==expected_id||resp_error!==expected_error)$fatal(1,"completion identity/error");
        if(expected_error)begin
          if(output_count!=0)$fatal(1,"error command produced output");
          if(expected_count>0&&expected_count<=MAX_ELEMENTS&&input_count!=expected_count)$fatal(1,"nonfinite command did not consume complete row");
          if((expected_count==0||expected_count>MAX_ELEMENTS)&&input_count!=0)$fatal(1,"illegal count consumed input");
        end else if(input_count!=expected_count||output_count!=expected_count)$fatal(1,"completion before final payload acceptance");
      end
      if(resp_valid&&resp_ready)begin active=0;completions++;end
    end
  end
  // Deterministic output backpressure is independent of input task sequencing.
  always @(negedge aclk)if(aresetn)m_axis_quant_tready=!output_hold&&(cycles%7!=0&&cycles%7!=1&&cycles%13!=0);
  task automatic tick;@(posedge aclk);#1;@(negedge aclk);#0.1;endtask
  task automatic reset_dut;
    @(negedge aclk);#0.1;aresetn=0;cmd_valid=0;s_axis_value_tvalid=0;resp_ready=0;m_axis_quant_tready=0;output_hold=0;
    repeat(3)tick();aresetn=1;tick();
    if(resp_valid||m_axis_quant_tvalid||!cmd_ready)$fatal(1,"reset valid/state");
  endtask
  task automatic issue(input integer count,input integer id,input bit error,input logic[15:0]scale);
    expected_count=count;expected_id=8'(id);expected_error=error;expected_scale=scale;
    cmd_elements=COUNT_WIDTH'(count);cmd_id=8'(id);cmd_valid=1;
    while(!cmd_ready)tick();tick();cmd_valid=0;
  endtask
  task automatic send_value(input logic[31:0]value);
    s_axis_value_tdata=value;s_axis_value_tvalid=1;
    while(!s_axis_value_tready)tick();tick();s_axis_value_tvalid=0;
  endtask
  task automatic finish_row;
    while(!resp_valid)tick();
    repeat(4)begin if(!resp_valid||resp_id!==expected_id||resp_error!==expected_error)$fatal(1,"completion hold");tick();end
    resp_ready=1;tick();resp_ready=0;
    repeat(2)begin if(resp_valid||m_axis_quant_tvalid||active)$fatal(1,"payload after completion");tick();end
  endtask
  initial begin
    $readmemh("inputs.hex",inputs,0,ROW_COUNT*MAX_ELEMENTS-1);
    $readmemh("outputs.hex",outputs,0,ROW_COUNT*MAX_ELEMENTS-1);
    $readmemh("metadata.hex",metadata,0,ROW_COUNT-1);
    reset_dut();
    // Payload valid before command may not be consumed.
    s_axis_value_tvalid=1;s_axis_value_tdata=32'h3f800000;repeat(3)begin if(s_axis_value_tready)$fatal(1,"input ready before command");tick();end;s_axis_value_tvalid=0;cases++;
    for(integer row=0;row<ROW_COUNT;row++)begin
      row_index=row;issue(metadata[row]>>17,row%256,metadata[row][16],metadata[row][15:0]);
      // Ready for a second command must stay low throughout input collection.
      for(integer elem=0;elem<expected_count;elem++)begin
        if(cmd_ready)$fatal(1,"multiple outstanding allowed");
        if((elem+row)%4==0)tick();send_value(inputs[row*MAX_ELEMENTS+elem]);
      end
      finish_row();cases++;
    end
    // Invalid count creates error without consuming any payload.
    for(integer bad=0;bad<2;bad++)begin
      row_index=0;issue(bad==0?0:MAX_ELEMENTS+1,8'he0+bad,1,0);
      s_axis_value_tvalid=1;repeat(3)begin if(s_axis_value_tready)$fatal(1,"bad count consumed payload");tick();end;s_axis_value_tvalid=0;
      finish_row();cases++;
    end
    // Synchronous reset cancels a partially supplied command without completion.
    row_index=0;issue(MAX_ELEMENTS,8'hf1,0,16'h3f80);send_value(32'h3f800000);reset_dut();repeat(8)begin if(resp_valid||m_axis_quant_tvalid)$fatal(1,"reset input cancellation");tick();end;cases++;
    // Cancel a valid output held in backpressure, then successfully repeat a row.
    output_hold=1;row_index=0;issue(metadata[0]>>17,8'hf2,metadata[0][16],metadata[0][15:0]);
    for(integer elem=0;elem<expected_count;elem++)send_value(inputs[elem]);
    while(!m_axis_quant_tvalid)tick();
    @(negedge aclk);#0.1;aresetn=0;cmd_valid=0;s_axis_value_tvalid=0;resp_ready=0;m_axis_quant_tready=0;repeat(3)tick();output_hold=0;aresetn=1;tick();
    if(resp_valid||m_axis_quant_tvalid||!cmd_ready)$fatal(1,"reset output cancellation");cases++;
    row_index=0;issue(metadata[0]>>17,8'hf3,metadata[0][16],metadata[0][15:0]);
    for(integer elem=0;elem<expected_count;elem++)send_value(inputs[elem]);finish_row();cases++;
    $display("QUANTIZER_CASES=%0d MAX_ELEMENTS=%0d reference_rows=%0d completions=%0d",cases,MAX_ELEMENTS,ROW_COUNT,completions);
    $display("ATTENTION_INT4_QUANTIZER_XSIM_PASS");$finish;
  end
  initial begin #20000000;$fatal(1,"quantizer global timeout");end
endmodule
