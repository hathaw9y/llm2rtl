`timescale 1ns/1ps

module bank_ownership_table #(
    parameter integer BANK_NUM = 16,
    parameter integer PORT_ROLE_WIDTH = 3
) (
    input logic aclk,
    input logic aresetn,
    input logic [0:BANK_NUM-1] acquire_valid,
    input logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] acquire_port,
    input logic [0:BANK_NUM-1] release_valid,
    input logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] release_port,
    output logic [0:BANK_NUM-1] bank_busy,
    output logic [0:BANK_NUM-1][PORT_ROLE_WIDTH-1:0] bank_owner_port,
    output logic ownership_error,
    output logic [2:0] ownership_error_code
);
  localparam logic [2:0] ERR_NONE = 3'd0;
  localparam logic [2:0] ERR_ACQUIRE_CONFLICT = 3'd1;
  localparam logic [2:0] ERR_RELEASE_FREE = 3'd2;
  localparam logic [2:0] ERR_RELEASE_OWNER_MISMATCH = 3'd3;
  localparam logic [2:0] ERR_ACQUIRE_RELEASE_OVERLAP = 3'd4;
  localparam logic PARAMETERS_LEGAL = (BANK_NUM >= 1) && (PORT_ROLE_WIDTH >= 3);

  logic acquire_conflict_w;
  logic release_free_w;
  logic release_mismatch_w;
  logic overlap_w;
  integer comb_idx;
  integer seq_idx;

  always_comb begin
    acquire_conflict_w = 1'b0;
    release_free_w = 1'b0;
    release_mismatch_w = 1'b0;
    overlap_w = 1'b0;
    for (comb_idx = 0; comb_idx < BANK_NUM; comb_idx = comb_idx + 1) begin
      if (acquire_valid[comb_idx] && bank_busy[comb_idx])
        acquire_conflict_w = 1'b1;
      if (release_valid[comb_idx] && !bank_busy[comb_idx])
        release_free_w = 1'b1;
      if (release_valid[comb_idx] && bank_busy[comb_idx] &&
          (release_port[comb_idx] != bank_owner_port[comb_idx]))
        release_mismatch_w = 1'b1;
      if (acquire_valid[comb_idx] && release_valid[comb_idx])
        overlap_w = 1'b1;
    end
  end

`ifndef SYNTHESIS
  initial if (!PARAMETERS_LEGAL) $error("bank_ownership_table illegal parameters");
`endif

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      bank_busy <= '0;
      bank_owner_port <= '0;
      ownership_error <= 1'b0;
      ownership_error_code <= ERR_NONE;
    end else begin
      if (!ownership_error) begin
        if (overlap_w) begin
          ownership_error <= 1'b1;
          ownership_error_code <= ERR_ACQUIRE_RELEASE_OVERLAP;
        end else if (acquire_conflict_w) begin
          ownership_error <= 1'b1;
          ownership_error_code <= ERR_ACQUIRE_CONFLICT;
        end else if (release_free_w) begin
          ownership_error <= 1'b1;
          ownership_error_code <= ERR_RELEASE_FREE;
        end else if (release_mismatch_w) begin
          ownership_error <= 1'b1;
          ownership_error_code <= ERR_RELEASE_OWNER_MISMATCH;
        end
      end

      if (!overlap_w) begin
        if (!release_free_w && !release_mismatch_w) begin
          for (seq_idx = 0; seq_idx < BANK_NUM; seq_idx = seq_idx + 1) begin
            if (release_valid[seq_idx]) begin
              bank_busy[seq_idx] <= 1'b0;
              bank_owner_port[seq_idx] <= '0;
            end
          end
        end
        if (!acquire_conflict_w) begin
          for (seq_idx = 0; seq_idx < BANK_NUM; seq_idx = seq_idx + 1) begin
            if (acquire_valid[seq_idx]) begin
              bank_busy[seq_idx] <= 1'b1;
              bank_owner_port[seq_idx] <= acquire_port[seq_idx];
            end
          end
        end
      end
    end
  end
endmodule
