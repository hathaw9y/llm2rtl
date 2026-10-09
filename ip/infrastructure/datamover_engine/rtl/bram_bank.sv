`timescale 1ns/1ps
module bram_bank #(
    parameter integer WRITE_DATA_WIDTH = 128,
    parameter longint unsigned WRITE_DEPTH = 4096,
    parameter integer READ_DATA_WIDTH = 128,
    parameter integer BYTE_WRITE_WIDTH = 8,
    parameter integer READ_LATENCY = 3,
    parameter integer ADDR_WIDTH = 32
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic ena,
    input  logic [(WRITE_DATA_WIDTH/BYTE_WRITE_WIDTH)-1:0] wea,
    input  logic [ADDR_WIDTH-1:0] addra,
    input  logic [WRITE_DATA_WIDTH-1:0] dina,
    input  logic enb,
    input  logic [ADDR_WIDTH-1:0] addrb,
    output logic [READ_DATA_WIDTH-1:0] doutb
);
  localparam longint unsigned MEMORY_SIZE_BITS =
      longint'(WRITE_DATA_WIDTH) * longint'(WRITE_DEPTH);
  localparam longint unsigned SAFE_READ_DATA_WIDTH =
      (READ_DATA_WIDTH > 0) ? longint'(READ_DATA_WIDTH) : 1;
  localparam longint unsigned SAFE_WRITE_DATA_WIDTH =
      (WRITE_DATA_WIDTH > 0) ? longint'(WRITE_DATA_WIDTH) : 1;
  localparam longint unsigned READ_DEPTH =
      MEMORY_SIZE_BITS / SAFE_READ_DATA_WIDTH;
  localparam integer XPM_ADDR_WIDTH_A =
      (WRITE_DEPTH <= 1) ? 1 : $clog2(WRITE_DEPTH);
  localparam integer XPM_ADDR_WIDTH_B =
      (READ_DEPTH <= 1) ? 1 : $clog2(READ_DEPTH);
  localparam integer REQUIRED_ADDR_WIDTH =
      (XPM_ADDR_WIDTH_A > XPM_ADDR_WIDTH_B) ?
      XPM_ADDR_WIDTH_A : XPM_ADDR_WIDTH_B;
  localparam logic [ADDR_WIDTH:0] WRITE_DEPTH_LIMIT =
      (ADDR_WIDTH + 1)'(WRITE_DEPTH);
  localparam logic [ADDR_WIDTH:0] READ_DEPTH_LIMIT =
      (ADDR_WIDTH + 1)'(READ_DEPTH);
  localparam logic PARAMETERS_LEGAL =
      (WRITE_DATA_WIDTH > 0) && (READ_DATA_WIDTH > 0) &&
      (BYTE_WRITE_WIDTH > 0) && (WRITE_DEPTH > 0) &&
      (READ_LATENCY >= 1) && (ADDR_WIDTH >= REQUIRED_ADDR_WIDTH) &&
      ((WRITE_DATA_WIDTH % BYTE_WRITE_WIDTH) == 0) &&
      ((MEMORY_SIZE_BITS % SAFE_READ_DATA_WIDTH) == 0) &&
      (((SAFE_WRITE_DATA_WIDTH % SAFE_READ_DATA_WIDTH) == 0) ||
       ((SAFE_READ_DATA_WIDTH % SAFE_WRITE_DATA_WIDTH) == 0));

  logic [XPM_ADDR_WIDTH_A-1:0] xpm_addra_w;
  logic [XPM_ADDR_WIDTH_B-1:0] xpm_addrb_w;
  logic addra_in_range_w;
  logic addrb_in_range_w;
  logic xpm_ena_w;
  logic xpm_enb_w;

  assign addra_in_range_w = ({1'b0, addra} < WRITE_DEPTH_LIMIT);
  assign addrb_in_range_w = ({1'b0, addrb} < READ_DEPTH_LIMIT);
  assign xpm_addra_w = XPM_ADDR_WIDTH_A'(addra);
  assign xpm_addrb_w = XPM_ADDR_WIDTH_B'(addrb);
  assign xpm_ena_w = ena && addra_in_range_w && PARAMETERS_LEGAL;
  assign xpm_enb_w = enb && addrb_in_range_w && PARAMETERS_LEGAL;

`ifndef SYNTHESIS
  initial if (!PARAMETERS_LEGAL) $error("bram_bank illegal parameters");
  always_ff @(posedge aclk) begin
    if (aresetn && ena && !addra_in_range_w)
      $error("bram_bank write address out of range: %0d", addra);
    if (aresetn && enb && !addrb_in_range_w)
      $error("bram_bank read address out of range: %0d", addrb);
  end
`endif

  xpm_memory_sdpram #(
      .ADDR_WIDTH_A(XPM_ADDR_WIDTH_A), .ADDR_WIDTH_B(XPM_ADDR_WIDTH_B),
      .AUTO_SLEEP_TIME(0), .BYTE_WRITE_WIDTH_A(BYTE_WRITE_WIDTH),
      .CASCADE_HEIGHT(0), .CLOCKING_MODE("common_clock"),
      .ECC_MODE("no_ecc"), .MEMORY_INIT_FILE("none"),
      .MEMORY_INIT_PARAM(""), .MEMORY_OPTIMIZATION("true"),
      .MEMORY_PRIMITIVE("block"), .MEMORY_SIZE(MEMORY_SIZE_BITS),
      .MESSAGE_CONTROL(0), .READ_DATA_WIDTH_B(READ_DATA_WIDTH),
      .READ_LATENCY_B(READ_LATENCY), .READ_RESET_VALUE_B("0"),
      .RST_MODE_A("SYNC"), .RST_MODE_B("SYNC"), .SIM_ASSERT_CHK(0),
      .USE_EMBEDDED_CONSTRAINT(0), .USE_MEM_INIT(0),
      .WAKEUP_TIME("disable_sleep"), .WRITE_DATA_WIDTH_A(WRITE_DATA_WIDTH),
      .WRITE_MODE_B("read_first")
  ) u_xpm_memory_sdpram (
      .sleep(1'b0), .clka(aclk), .ena(xpm_ena_w), .wea(wea),
      .addra(xpm_addra_w), .dina(dina), .injectsbiterra(1'b0),
      .injectdbiterra(1'b0), .clkb(aclk), .rstb(!aresetn),
      .enb(xpm_enb_w), .regceb(1'b1), .addrb(xpm_addrb_w),
      .doutb(doutb), .sbiterrb(), .dbiterrb()
  );
endmodule
