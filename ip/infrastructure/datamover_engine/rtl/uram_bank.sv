`timescale 1ns/1ps
module uram_bank #(
    parameter integer DATA_WIDTH = 128,
    parameter longint unsigned DEPTH = 8192,
    parameter integer READ_LATENCY = 3,
    parameter integer ADDR_WIDTH = 32
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic ena,
    input  logic [(DATA_WIDTH/8)-1:0] wea,
    input  logic [ADDR_WIDTH-1:0] addra,
    input  logic [DATA_WIDTH-1:0] dina,
    input  logic enb,
    input  logic [ADDR_WIDTH-1:0] addrb,
    output logic [DATA_WIDTH-1:0] doutb
);
  localparam longint unsigned MEMORY_SIZE_BITS =
      longint'(DATA_WIDTH) * longint'(DEPTH);
  localparam integer XPM_ADDR_WIDTH =
      (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam logic [ADDR_WIDTH:0] DEPTH_LIMIT =
      (ADDR_WIDTH + 1)'(DEPTH);
  localparam logic PARAMETERS_LEGAL =
      (DATA_WIDTH > 0) && (DEPTH > 0) && ((DATA_WIDTH % 8) == 0) &&
      (READ_LATENCY >= 1) && (ADDR_WIDTH >= XPM_ADDR_WIDTH);

  logic [XPM_ADDR_WIDTH-1:0] xpm_addra_w;
  logic [XPM_ADDR_WIDTH-1:0] xpm_addrb_w;
  logic addra_in_range_w;
  logic addrb_in_range_w;
  logic xpm_ena_w;
  logic xpm_enb_w;

  assign addra_in_range_w = ({1'b0, addra} < DEPTH_LIMIT);
  assign addrb_in_range_w = ({1'b0, addrb} < DEPTH_LIMIT);
  assign xpm_addra_w = XPM_ADDR_WIDTH'(addra);
  assign xpm_addrb_w = XPM_ADDR_WIDTH'(addrb);
  assign xpm_ena_w = ena && addra_in_range_w && PARAMETERS_LEGAL;
  assign xpm_enb_w = enb && addrb_in_range_w && PARAMETERS_LEGAL;

`ifndef SYNTHESIS
  initial if (!PARAMETERS_LEGAL) $error("uram_bank illegal parameters");
  always_ff @(posedge aclk) begin
    if (aresetn && ena && !addra_in_range_w)
      $error("uram_bank write address out of range: %0d", addra);
    if (aresetn && enb && !addrb_in_range_w)
      $error("uram_bank read address out of range: %0d", addrb);
  end
`endif

  xpm_memory_sdpram #(
      .ADDR_WIDTH_A(XPM_ADDR_WIDTH), .ADDR_WIDTH_B(XPM_ADDR_WIDTH),
      .AUTO_SLEEP_TIME(0), .BYTE_WRITE_WIDTH_A(8), .CASCADE_HEIGHT(0),
      .CLOCKING_MODE("common_clock"), .ECC_MODE("no_ecc"),
      .MEMORY_INIT_FILE("none"), .MEMORY_INIT_PARAM(""),
      .MEMORY_OPTIMIZATION("true"), .MEMORY_PRIMITIVE("ultra"),
      .MEMORY_SIZE(MEMORY_SIZE_BITS), .MESSAGE_CONTROL(0),
      .READ_DATA_WIDTH_B(DATA_WIDTH), .READ_LATENCY_B(READ_LATENCY),
      .READ_RESET_VALUE_B("0"), .RST_MODE_A("SYNC"), .RST_MODE_B("SYNC"),
      .SIM_ASSERT_CHK(0), .USE_EMBEDDED_CONSTRAINT(0), .USE_MEM_INIT(0),
      .WAKEUP_TIME("disable_sleep"), .WRITE_DATA_WIDTH_A(DATA_WIDTH),
      .WRITE_MODE_B("read_first")
  ) u_xpm_memory_sdpram (
      .sleep(1'b0), .clka(aclk), .ena(xpm_ena_w), .wea(wea),
      .addra(xpm_addra_w), .dina(dina), .injectsbiterra(1'b0),
      .injectdbiterra(1'b0), .clkb(aclk), .rstb(!aresetn),
      .enb(xpm_enb_w), .regceb(1'b1), .addrb(xpm_addrb_w),
      .doutb(doutb), .sbiterrb(), .dbiterrb()
  );
endmodule
