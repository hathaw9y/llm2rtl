// Frozen int8_dot_core packet: exact signed arithmetic; no overflow detector.
module int8_dot_core (
 input logic clk, resetn,
 input logic step_valid, output logic step_ready,
 input logic [127:0] step_a, input logic [2047:0] step_b,
 input logic [6:0] step_row, input logic step_first_k, step_last_k,
 input logic [4:0] step_n_valid, input logic [95:0] step_tag,
 input logic [31:0] step_scale,
 output logic result_valid, input logic result_ready,
 output logic [511:0] result_sums, output logic [4:0] result_n_valid,
 output logic [95:0] result_tag, output logic [31:0] result_scale
);
 logic advance_w;
 logic [4:0] valid_r;
 logic [6:0] row_r [0:4];
 logic first_r [0:4], last_r [0:4];
 logic [4:0] n_valid_r [0:4];
 logic [95:0] tag_r [0:4];
 logic [31:0] scale_r [0:4];
 (* use_dsp = "yes" *) logic signed [15:0] product_r [0:15][0:15];
 logic signed [16:0] reduce1_r [0:15][0:7];
 logic signed [17:0] reduce2_r [0:15][0:3];
 logic signed [18:0] reduce3_r [0:15][0:1];
 logic signed [19:0] reduce4_r [0:15];
 logic signed [31:0] psum_r [0:15][0:95];
 logic signed [31:0] completed_w [0:15];
 assign advance_w = !result_valid || result_ready;
 assign step_ready = resetn && advance_w;
 for (genvar n=0; n<16; n=n+1) begin: lane
   assign completed_w[n] = first_r[4] ? {{12{reduce4_r[n][19]}},reduce4_r[n]} :
       psum_r[n][row_r[4]] + {{12{reduce4_r[n][19]}},reduce4_r[n]};
   always_ff @(posedge clk) begin
     if (!resetn) begin
       for (integer r=0;r<96;r=r+1) psum_r[n][r] <= '0;
     end else if (advance_w && valid_r[4]) begin
       psum_r[n][row_r[4]] <= completed_w[n];
     end
   end
   always_ff @(posedge clk) begin
     if (advance_w && resetn) begin
       for (integer k=0;k<16;k=k+1)
         product_r[n][k] <= (n < step_n_valid) ?
           $signed(step_a[k*8 +: 8]) * $signed(step_b[(n*16+k)*8 +: 8]) : 16'sd0;
       for (integer k=0;k<8;k=k+1)
         reduce1_r[n][k] <= {product_r[n][2*k][15],product_r[n][2*k]} +
                              {product_r[n][2*k+1][15],product_r[n][2*k+1]};
       for (integer k=0;k<4;k=k+1)
         reduce2_r[n][k] <= {reduce1_r[n][2*k][16],reduce1_r[n][2*k]} +
                              {reduce1_r[n][2*k+1][16],reduce1_r[n][2*k+1]};
       for (integer k=0;k<2;k=k+1)
         reduce3_r[n][k] <= {reduce2_r[n][2*k][17],reduce2_r[n][2*k]} +
                              {reduce2_r[n][2*k+1][17],reduce2_r[n][2*k+1]};
       reduce4_r[n] <= {reduce3_r[n][0][18],reduce3_r[n][0]} +
                        {reduce3_r[n][1][18],reduce3_r[n][1]};
     end
   end
 end
 always_ff @(posedge clk) begin
   if (!resetn) begin
     valid_r <= '0;
     result_valid <= 1'b0;
     result_sums <= '0; result_n_valid <= '0;
     result_tag <= '0; result_scale <= '0;
     for (integer s=0;s<5;s=s+1) begin
       row_r[s] <= '0; first_r[s] <= 1'b0; last_r[s] <= 1'b0;
       n_valid_r[s] <= '0; tag_r[s] <= '0; scale_r[s] <= '0;
     end
   end else if (advance_w) begin
     valid_r <= {valid_r[3:0],step_valid};
     row_r[0] <= step_row; first_r[0] <= step_first_k; last_r[0] <= step_last_k;
     n_valid_r[0] <= step_n_valid; tag_r[0] <= step_tag; scale_r[0] <= step_scale;
     for (integer s=1;s<5;s=s+1) begin
       row_r[s] <= row_r[s-1]; first_r[s] <= first_r[s-1]; last_r[s] <= last_r[s-1];
       n_valid_r[s] <= n_valid_r[s-1]; tag_r[s] <= tag_r[s-1]; scale_r[s] <= scale_r[s-1];
     end
     result_valid <= valid_r[4] && last_r[4];
     if (valid_r[4] && last_r[4]) begin
       for (integer n=0;n<16;n=n+1) result_sums[n*32 +: 32] <= completed_w[n];
       result_n_valid <= n_valid_r[4]; result_tag <= tag_r[4]; result_scale <= scale_r[4];
     end
   end
 end
endmodule
