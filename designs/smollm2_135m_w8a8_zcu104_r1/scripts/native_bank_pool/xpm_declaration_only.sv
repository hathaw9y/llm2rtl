`timescale 1ns/1ps
// Lint-only declaration: exact vendor XPM public declaration, no behavior. NEVER included in simulation/synthesis.
module xpm_memory_sdpram # (
  
  // Common module parameters
  parameter integer                 MEMORY_SIZE        = 2048,
  parameter                         MEMORY_PRIMITIVE   = "auto",
  parameter                         CLOCKING_MODE      = "common_clock",
  parameter                         ECC_MODE           = "no_ecc",
  parameter                         ECC_TYPE           = "NONE",
  parameter                         ECC_BIT_RANGE      = "[7:0]",
  parameter                         MEMORY_INIT_FILE   = "none",
  parameter                         MEMORY_INIT_PARAM  = "",
  parameter integer                 USE_MEM_INIT       = 1,
  parameter integer                 USE_MEM_INIT_MMI   = 0,
  parameter                         WAKEUP_TIME        = "disable_sleep",
  parameter integer                 AUTO_SLEEP_TIME    = 0,
  parameter integer                 MESSAGE_CONTROL    = 0,
  parameter integer                 USE_EMBEDDED_CONSTRAINT = 0,
  parameter                         MEMORY_OPTIMIZATION     = "true",
  parameter integer                 CASCADE_HEIGHT          = 0,
  parameter                         RAM_DECOMP              = "auto",
  parameter integer                 SIM_ASSERT_CHK          = 0,
  parameter integer                 WRITE_PROTECT           = 1,
  parameter integer                 IGNORE_INIT_SYNTH       = 0,

  // Port A module parameters
  parameter integer                 WRITE_DATA_WIDTH_A = 32,
  parameter integer                 BYTE_WRITE_WIDTH_A = WRITE_DATA_WIDTH_A,
  parameter integer                 ADDR_WIDTH_A       = $clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A),
  parameter                         RST_MODE_A         = "SYNC",

  // Port B module parameters
  parameter integer                 READ_DATA_WIDTH_B  = WRITE_DATA_WIDTH_A,
  parameter integer                 ADDR_WIDTH_B       = $clog2(MEMORY_SIZE/READ_DATA_WIDTH_B),
  parameter                         READ_RESET_VALUE_B = "0",
  parameter integer                 READ_LATENCY_B     = 2,
  parameter                         WRITE_MODE_B       = "no_change",
  parameter                         RST_MODE_B         = "SYNC"

) (

  // Common module ports
  input  wire                                               sleep,

  // Port A module ports
  input  wire                                               clka,
  input  wire                                               ena,
  input  wire [(WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A)-1:0] wea,
  input  wire [ADDR_WIDTH_A-1:0]                            addra,
  input  wire [WRITE_DATA_WIDTH_A-1:0]                      dina,
  input  wire                                               injectsbiterra,
  input  wire                                               injectdbiterra,

  // Port B module ports
  input  wire                                               clkb,
  input  wire                                               rstb,
  input  wire                                               enb,
  input  wire                                               regceb,
  input  wire [ADDR_WIDTH_B-1:0]                            addrb,
  output wire [READ_DATA_WIDTH_B-1:0]                       doutb,
  output wire                                               sbiterrb,
  output wire                                               dbiterrb
);
endmodule

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
endmodule

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
endmodule
