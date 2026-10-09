`timescale 1ns/1ps
module attention_int4_quantizer #(
    parameter int MAX_ELEMENTS = 256,
    parameter int ID_WIDTH = 8,
    parameter int COUNT_WIDTH = (MAX_ELEMENTS < 2) ? 1 : $clog2(MAX_ELEMENTS+1)
) (
    input logic aclk,
    input logic aresetn,
    input logic cmd_valid,
    output logic cmd_ready,
    input logic [ID_WIDTH-1:0] cmd_id,
    input logic [COUNT_WIDTH-1:0] cmd_elements,
    input logic s_axis_value_tvalid,
    output logic s_axis_value_tready,
    input logic [31:0] s_axis_value_tdata,
    output logic m_axis_quant_tvalid,
    input logic m_axis_quant_tready,
    output logic [3:0] m_axis_quant_tdata,
    output logic [15:0] m_axis_quant_tscale,
    output logic m_axis_quant_tlast,
    output logic resp_valid,
    input logic resp_ready,
    output logic [ID_WIDTH-1:0] resp_id,
    output logic resp_error
);
  localparam int ROW_ADDR_WIDTH = MAX_ELEMENTS < 2 ? 1 : $clog2(MAX_ELEMENTS);
  localparam int REQUIRED_COUNT_WIDTH = MAX_ELEMENTS < 2 ? 1 : $clog2(MAX_ELEMENTS+1);
  localparam logic PARAMETERS_LEGAL = MAX_ELEMENTS >= 1 && ID_WIDTH >= 1 &&
      COUNT_WIDTH == REQUIRED_COUNT_WIDTH;
  localparam logic [COUNT_WIDTH-1:0] ELEMENT_LIMIT = COUNT_WIDTH'(MAX_ELEMENTS);
  typedef enum logic [3:0] {
    IDLE, INPUT_ROW, SCALE_PREP, SCALE_DIV, SCALE_ROUND, THRESHOLDS, OUTPUT_ROW, RESPOND
  } state_t;
  state_t state_r;
  logic [ID_WIDTH-1:0] id_r;
  logic [COUNT_WIDTH-1:0] count_r, write_index_r, read_index_r;
  logic row_error_r;
  logic [30:0] max_magnitude_r;
  (* ram_style = "block" *) logic [31:0] row_memory [0:MAX_ELEMENTS-1];
  logic [23:0] scale_mantissa_r;
  logic signed [9:0] scale_exponent_r;
  logic scale_high_branch_r;
  logic [8:0] scale_quotient_r;
  logic [16:0] scale_remainder_r;
  logic [15:0] scale_r;
  logic [30:0] thresholds_r [0:6];
  logic [31:0] read_value_r;
  logic read_valid_r, read_last_r;
  logic compare_valid_r, compare_last_r, compare_sign_r;
  logic [6:0] crossed_r;
  logic [6:0] crossed_w;
  logic [30:0] read_magnitude_w;
  logic [1:0] pair01_w, pair23_w, pair45_w;
  logic [2:0] four_w, three_w;
  logic [3:0] level_w;
  logic out_valid_r, out_last_r;
  logic [3:0] out_data_r;
  logic input_fire_w, input_nonfinite_w, output_advance_w, row_read_w, invalid_count_w;
  logic [30:0] input_magnitude_w;
  logic [8:0] quotient_w, rounded_quotient_w;
  logic [2:0] integer_remainder_w;
  logic [16:0] remainder_w, halfway_w;
  logic signed [9:0] rounded_exponent_w;
  logic [15:0] rounded_scale_w;

`ifndef SYNTHESIS
  initial if (!PARAMETERS_LEGAL) $fatal(1, "attention_int4_quantizer illegal parameters");
`endif
  assign cmd_ready = aresetn && state_r == IDLE;
  assign s_axis_value_tready = aresetn && state_r == INPUT_ROW;
  assign input_fire_w = s_axis_value_tvalid && s_axis_value_tready;
  assign input_nonfinite_w = s_axis_value_tdata[30:23] == 8'hff;
  // FP32 exponent-zero inputs, including signed zero, are flushed to zero.
  assign input_magnitude_w = s_axis_value_tdata[30:23] == '0 ? '0 : s_axis_value_tdata[30:0];
  assign m_axis_quant_tvalid = aresetn && state_r == OUTPUT_ROW && out_valid_r;
  assign m_axis_quant_tdata = out_data_r;
  assign m_axis_quant_tscale = scale_r;
  assign m_axis_quant_tlast = out_last_r;
  assign resp_valid = aresetn && state_r == RESPOND;
  assign resp_id = id_r;
  assign resp_error = row_error_r;
  assign output_advance_w = !out_valid_r || m_axis_quant_tready;
  assign row_read_w = aresetn && state_r == OUTPUT_ROW && output_advance_w && read_index_r < count_r;
  if (64'(MAX_ELEMENTS) == (64'd1 << COUNT_WIDTH)-64'd1) begin : g_full_count_range
    assign invalid_count_w = !PARAMETERS_LEGAL || cmd_elements == '0;
  end else begin : g_partial_count_range
    assign invalid_count_w = !PARAMETERS_LEGAL || cmd_elements == '0 || cmd_elements > ELEMENT_LIMIT;
  end

  // If M is the 24-bit FP32 significand, max/7 has BF16 exponent E-3
  // below M=7*2^21 and E-2 otherwise. Its unrounded BF16 significand
  // is M/(7*2^13) or M/(7*2^14). Divide only the high 11/10 bits by 7;
  // concatenate its remainder and untouched low bits for exact rounding.
  always_comb begin
    quotient_w = '0; integer_remainder_w = '0; remainder_w = '0;
    if (scale_high_branch_r) begin
      quotient_w = 9'(scale_mantissa_r[23:14] / 10'd7);
      integer_remainder_w = 3'(scale_mantissa_r[23:14] % 10'd7);
      remainder_w = {integer_remainder_w, scale_mantissa_r[13:0]};
    end else begin
      quotient_w = 9'(scale_mantissa_r[23:13] / 11'd7);
      integer_remainder_w = 3'(scale_mantissa_r[23:13] % 11'd7);
      remainder_w = {1'b0, integer_remainder_w, scale_mantissa_r[12:0]};
    end
  end
  always_comb begin
    halfway_w = scale_high_branch_r ? 17'd57344 : 17'd28672;
    rounded_quotient_w = scale_quotient_r;
    if (scale_remainder_r > halfway_w ||
        (scale_remainder_r == halfway_w && scale_quotient_r[0]))
      rounded_quotient_w = scale_quotient_r + 9'd1;
    rounded_exponent_w = scale_exponent_r;
    if (rounded_quotient_w == 9'd256) rounded_exponent_w = scale_exponent_r + 10'sd1;
    if (rounded_exponent_w <= 10'sd0) rounded_scale_w = 16'h0080;
    else if (rounded_quotient_w == 9'd256)
      rounded_scale_w = {1'b0, 8'(rounded_exponent_w), 7'd0};
    else rounded_scale_w = {1'b0, 8'(rounded_exponent_w), rounded_quotient_w[6:0]};
  end

  // BF16 normal significand Q times (2*k+1)/2 is exactly representable
  // in FP32: the product has at most 12 significant bits. Positive FP32
  // encodings preserve magnitude order, including the min-scale half
  // threshold represented as an FP32 subnormal.
  function automatic logic [30:0] half_threshold(input logic [14:0] scale,
                                                input logic [3:0] odd);
    logic [11:0] product;
    logic [23:0] normalized;
    logic [8:0] exponent;
    integer highest;
    begin
      product = 12'({1'b1,scale[6:0]}) * 12'(odd);
      highest = 0;
      for (int b=0; b<12; b++) if (product[b]) highest = b;
      normalized = 24'(product) << (23-highest);
      exponent = 9'(scale[14:7]) + 9'(highest) - 9'd8;
      if (exponent >= 9'd255) half_threshold = 31'h7f800000;
      else if (exponent == '0) half_threshold = {8'd0, normalized[23:1]};
      else half_threshold = {exponent[7:0], normalized[22:0]};
    end
  endfunction
  assign read_magnitude_w = read_value_r[30:23] == '0 ? '0 : read_value_r[30:0];
  for (genvar k=0; k<7; k++) begin : g_compare
    // At k+0.5, ties choose k when k is even and k+1 otherwise.
    assign crossed_w[k] = read_magnitude_w > thresholds_r[k] ||
        (read_magnitude_w == thresholds_r[k] && (k % 2 == 1));
  end
  // Balanced popcount of the seven exact boundary comparisons. The result
  // is inherently bounded to [0,7], so signed output never produces -8.
  assign pair01_w = {1'b0,crossed_r[0]} + {1'b0,crossed_r[1]};
  assign pair23_w = {1'b0,crossed_r[2]} + {1'b0,crossed_r[3]};
  assign pair45_w = {1'b0,crossed_r[4]} + {1'b0,crossed_r[5]};
  assign four_w = {1'b0,pair01_w} + {1'b0,pair23_w};
  assign three_w = {1'b0,pair45_w} + {2'b0,crossed_r[6]};
  assign level_w = {1'b0,four_w} + {1'b0,three_w};

  // The row memory is never reset. Only accepted input words are written and
  // only the accepted row length is replayed, so stale contents are unreachable.
  always_ff @(posedge aclk) begin
    if (input_fire_w) row_memory[ROW_ADDR_WIDTH'(write_index_r)] <= s_axis_value_tdata;
    if (row_read_w) read_value_r <= row_memory[ROW_ADDR_WIDTH'(read_index_r)];
  end
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      state_r <= IDLE; id_r <= '0; count_r <= '0;
      write_index_r <= '0; read_index_r <= '0; row_error_r <= 1'b0;
      max_magnitude_r <= '0; scale_mantissa_r <= '0; scale_exponent_r <= '0;
      scale_high_branch_r <= 1'b0; scale_quotient_r <= '0; scale_remainder_r <= '0;
      scale_r <= 16'h3f80;
      for (int k=0; k<7; k++) thresholds_r[k] <= '0;
      read_valid_r <= 1'b0; read_last_r <= 1'b0;
      compare_valid_r <= 1'b0; compare_last_r <= 1'b0; compare_sign_r <= 1'b0; crossed_r <= '0;
      out_valid_r <= 1'b0; out_last_r <= 1'b0; out_data_r <= '0;
    end else begin
      case (state_r)
        IDLE: if (cmd_valid && cmd_ready) begin
          id_r <= cmd_id; count_r <= cmd_elements;
          write_index_r <= '0; read_index_r <= '0; max_magnitude_r <= '0;
          read_valid_r <= 1'b0; compare_valid_r <= 1'b0; out_valid_r <= 1'b0;
          row_error_r <= invalid_count_w;
          if (invalid_count_w) state_r <= RESPOND;
          else state_r <= INPUT_ROW;
        end
        INPUT_ROW: if (input_fire_w) begin
          write_index_r <= write_index_r + COUNT_WIDTH'(1);
          if (input_nonfinite_w) row_error_r <= 1'b1;
          else if (input_magnitude_w > max_magnitude_r) max_magnitude_r <= input_magnitude_w;
          if (write_index_r == count_r-COUNT_WIDTH'(1)) begin
            if (row_error_r || input_nonfinite_w) state_r <= RESPOND;
            else state_r <= SCALE_PREP;
          end
        end
        SCALE_PREP: begin
          if (max_magnitude_r == '0) begin scale_r <= 16'h3f80; state_r <= THRESHOLDS; end
          else begin
            scale_mantissa_r <= {1'b1,max_magnitude_r[22:0]};
            scale_high_branch_r <= {1'b1,max_magnitude_r[22:0]} >= 24'((7<<21));
            if ({1'b1,max_magnitude_r[22:0]} >= 24'((7<<21)))
              scale_exponent_r <= $signed({2'b0,max_magnitude_r[30:23]})-10'sd2;
            else scale_exponent_r <= $signed({2'b0,max_magnitude_r[30:23]})-10'sd3;
            state_r <= SCALE_DIV;
          end
        end
        SCALE_DIV: begin
          scale_quotient_r <= quotient_w; scale_remainder_r <= remainder_w;
          state_r <= SCALE_ROUND;
        end
        SCALE_ROUND: begin scale_r <= rounded_scale_w; state_r <= THRESHOLDS; end
        THRESHOLDS: begin
          for (int k=0; k<7; k++) thresholds_r[k] <= half_threshold(scale_r[14:0],4'(2*k+1));
          state_r <= OUTPUT_ROW;
        end
        OUTPUT_ROW: begin
          if (output_advance_w) begin
            read_valid_r <= row_read_w;
            read_last_r <= row_read_w && read_index_r == count_r-COUNT_WIDTH'(1);
            if (row_read_w) read_index_r <= read_index_r + COUNT_WIDTH'(1);
            compare_valid_r <= read_valid_r;
            if (read_valid_r) begin
              crossed_r <= crossed_w; compare_sign_r <= read_value_r[31]; compare_last_r <= read_last_r;
            end
            out_valid_r <= compare_valid_r;
            if (compare_valid_r) begin
              out_data_r <= compare_sign_r ? 4'd0-level_w : level_w;
              out_last_r <= compare_last_r;
            end
          end
          if (m_axis_quant_tvalid && m_axis_quant_tready && out_last_r) begin
            out_valid_r <= 1'b0; read_valid_r <= 1'b0; compare_valid_r <= 1'b0; state_r <= RESPOND;
          end
        end
        RESPOND: if (resp_valid && resp_ready) state_r <= IDLE;
        default: begin row_error_r <= 1'b1; out_valid_r <= 1'b0; read_valid_r <= 1'b0; compare_valid_r <= 1'b0; state_r <= RESPOND; end
      endcase
    end
  end
endmodule
