`timescale 1ns/1ps
module bank_native_ownership #(
    parameter int BANK_NUM = 2,
    parameter int ROLE_WIDTH = 3,
    parameter logic [BANK_NUM-1:0][(1<<ROLE_WIDTH)-1:0] WR_CAPABILITIES = '0,
    parameter logic [BANK_NUM-1:0][(1<<ROLE_WIDTH)-1:0] RD_CAPABILITIES = '0
) (
    input logic aclk, aresetn,
    input logic [BANK_NUM-1:0] bank_wr_acquire_valid, bank_rd_acquire_valid,
    input logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] bank_wr_acquire_port, bank_rd_acquire_port,
    input logic [BANK_NUM-1:0] bank_wr_release_valid, bank_rd_release_valid,
    input logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] bank_wr_release_port, bank_rd_release_port,
    output logic [BANK_NUM-1:0] bank_wr_busy, bank_rd_busy,
    output logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] bank_wr_owner_port, bank_rd_owner_port,
    output logic [BANK_NUM-1:0] wr_acquire_accepted, rd_acquire_accepted,
    output logic [BANK_NUM-1:0] wr_release_accepted, rd_release_accepted,
    output logic ownership_error,
    output logic [2:0] ownership_error_code
);
  logic acquire_bad_w, release_bad_w;
  logic [2:0] acquire_code_w, release_code_w;
  always_comb begin
    acquire_bad_w = 1'b0;
    release_bad_w = 1'b0;
    acquire_code_w = 3'd0;
    release_code_w = 3'd0;
    for (int b=0; b<BANK_NUM; b++) begin
      if ((bank_wr_acquire_valid[b] &&
           ((bank_wr_acquire_port[b] == '0) || !WR_CAPABILITIES[b][bank_wr_acquire_port[b]])) ||
          (bank_rd_acquire_valid[b] &&
           ((bank_rd_acquire_port[b] == '0) || !RD_CAPABILITIES[b][bank_rd_acquire_port[b]]))) begin
        acquire_bad_w = 1'b1;
        acquire_code_w = 3'd1;
      end else if ((bank_wr_acquire_valid[b] && (bank_wr_busy[b] || bank_wr_release_valid[b])) ||
                   (bank_rd_acquire_valid[b] && (bank_rd_busy[b] || bank_rd_release_valid[b]))) begin
        acquire_bad_w = 1'b1;
        if (acquire_code_w == 3'd0) acquire_code_w = 3'd2;
      end
      if ((bank_wr_release_valid[b] &&
           ((bank_wr_release_port[b] == '0) || !WR_CAPABILITIES[b][bank_wr_release_port[b]])) ||
          (bank_rd_release_valid[b] &&
           ((bank_rd_release_port[b] == '0) || !RD_CAPABILITIES[b][bank_rd_release_port[b]]))) begin
        release_bad_w = 1'b1;
        release_code_w = 3'd1;
      end else if ((bank_wr_release_valid[b] &&
                    (!bank_wr_busy[b] || bank_wr_owner_port[b] != bank_wr_release_port[b] || bank_wr_acquire_valid[b])) ||
                   (bank_rd_release_valid[b] &&
                    (!bank_rd_busy[b] || bank_rd_owner_port[b] != bank_rd_release_port[b] ||
                     bank_rd_acquire_valid[b]))) begin
        release_bad_w = 1'b1;
        if (release_code_w == 3'd0) release_code_w = 3'd3;
      end
    end
    wr_acquire_accepted = aresetn && !acquire_bad_w ? bank_wr_acquire_valid : '0;
    rd_acquire_accepted = aresetn && !acquire_bad_w ? bank_rd_acquire_valid : '0;
    wr_release_accepted = aresetn && !release_bad_w ? bank_wr_release_valid : '0;
    rd_release_accepted = aresetn && !release_bad_w ? bank_rd_release_valid : '0;
  end
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      bank_wr_busy <= '0; bank_rd_busy <= '0;
      bank_wr_owner_port <= '0; bank_rd_owner_port <= '0;
      ownership_error <= 1'b0; ownership_error_code <= '0;
    end else begin
      for (int b=0; b<BANK_NUM; b++) begin
        if (!release_bad_w && bank_wr_release_valid[b]) begin
          bank_wr_busy[b] <= 1'b0; bank_wr_owner_port[b] <= '0;
        end
        if (!release_bad_w && bank_rd_release_valid[b]) begin
          bank_rd_busy[b] <= 1'b0; bank_rd_owner_port[b] <= '0;
        end
        if (!acquire_bad_w && bank_wr_acquire_valid[b]) begin
          bank_wr_busy[b] <= 1'b1; bank_wr_owner_port[b] <= bank_wr_acquire_port[b];
        end
        if (!acquire_bad_w && bank_rd_acquire_valid[b]) begin
          bank_rd_busy[b] <= 1'b1; bank_rd_owner_port[b] <= bank_rd_acquire_port[b];
        end
      end
      if (!ownership_error) begin
        if (acquire_bad_w) begin ownership_error <= 1'b1; ownership_error_code <= acquire_code_w; end
        else if (release_bad_w) begin ownership_error <= 1'b1; ownership_error_code <= release_code_w; end
      end
    end
  end
endmodule
