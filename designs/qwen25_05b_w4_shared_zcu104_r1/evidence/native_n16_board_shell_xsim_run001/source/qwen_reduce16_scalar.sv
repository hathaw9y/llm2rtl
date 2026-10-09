module qwen_reduce16_scalar(
  input logic clk,rst_n,
  input logic cmd_valid,output logic cmd_ready,
  input logic [9:0] cmd_id,input logic [511:0] cmd_values,
  output logic rsp_valid,input logic rsp_ready,
  output logic [9:0] rsp_cmd_id,output logic [31:0] rsp_data,output logic rsp_error
);
  typedef enum logic [1:0] {IDLE,ISSUE,WAIT_RESULT,RESPONSE} state_t;
  state_t state_r;
  logic [31:0] values_r[0:15];
  logic [4:0] width_r,index_r;
  logic [9:0] id_r;
  logic error_r;
  logic fp_valid,fp_ready,fp_rsp_valid,fp_rsp_ready,fp_error;
  logic [31:0] fp_data;logic [9:0] fp_id;
  assign cmd_ready=state_r==IDLE && rst_n;assign rsp_valid=state_r==RESPONSE;
  assign rsp_cmd_id=id_r;assign rsp_data=values_r[0];assign rsp_error=error_r;
  assign fp_valid=state_r==ISSUE;assign fp_rsp_ready=state_r==WAIT_RESULT;
  qwen_fp32_pipe arithmetic(.clk,.rst_n,.cmd_valid(fp_valid),.cmd_ready(fp_ready),.cmd_id(id_r),
    .cmd_multiply(1'b0),.cmd_a(values_r[index_r*2]),.cmd_b(values_r[index_r*2+1]),
    .rsp_valid(fp_rsp_valid),.rsp_ready(fp_rsp_ready),.rsp_id(fp_id),.rsp_data(fp_data),.rsp_error(fp_error));
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r<=IDLE;width_r<=16;index_r<=0;id_r<=0;error_r<=0;
      for(integer i=0;i<16;i=i+1) values_r[i]<=0;
    end else case(state_r)
      IDLE:if(cmd_valid && cmd_ready) begin
        for(integer i=0;i<16;i=i+1) values_r[i]<=cmd_values[i*32+:32];
        width_r<=16;index_r<=0;id_r<=cmd_id;error_r<=0;state_r<=ISSUE;
      end
      ISSUE:if(fp_ready) state_r<=WAIT_RESULT;
      WAIT_RESULT:if(fp_rsp_valid) begin
        values_r[index_r]<=fp_data;
        if(fp_error || fp_id!=id_r) begin error_r<=1;state_r<=RESPONSE;end
        else if(width_r==2) state_r<=RESPONSE;
        else if(index_r==(width_r/2)-1) begin index_r<=0;width_r<=width_r/2;state_r<=ISSUE;end
        else begin index_r<=index_r+1'b1;state_r<=ISSUE;end
      end
      RESPONSE:if(rsp_ready) state_r<=IDLE;
      default:state_r<=IDLE;
    endcase
  end
endmodule
