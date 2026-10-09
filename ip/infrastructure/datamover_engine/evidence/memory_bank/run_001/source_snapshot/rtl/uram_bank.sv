module uram_bank #(
    parameter int DATA_WIDTH   = 128,
    parameter int DEPTH        = 4096,
    parameter int READ_LATENCY = 1
) (
    input  logic                      aclk,
    input  logic                      aresetn,
    input  logic                      ena,
    input  logic [(DATA_WIDTH/8)-1:0] wea,
    input  logic [ $clog2(DEPTH)-1:0] addra,
    input  logic [    DATA_WIDTH-1:0] dina,
    input  logic                      enb,
    input  logic [ $clog2(DEPTH)-1:0] addrb,
    output logic [    DATA_WIDTH-1:0] doutb
);
  localparam int MEMORY_SIZE_BITS = DATA_WIDTH * DEPTH;

  xpm_memory_sdpram #(
      .ADDR_WIDTH_A           ($clog2(DEPTH)),
      .ADDR_WIDTH_B           ($clog2(DEPTH)),
      .AUTO_SLEEP_TIME        (0),
      .BYTE_WRITE_WIDTH_A     (8),
      .CASCADE_HEIGHT         (0),
      .CLOCKING_MODE          ("common_clock"),
      .ECC_MODE               ("no_ecc"),
      .MEMORY_INIT_FILE       ("none"),
      .MEMORY_INIT_PARAM      (""),
      .MEMORY_OPTIMIZATION    ("true"),
      .MEMORY_PRIMITIVE       ("ultra"),
      .MEMORY_SIZE            (MEMORY_SIZE_BITS),
      .MESSAGE_CONTROL        (0),
      .READ_DATA_WIDTH_B      (DATA_WIDTH),
      .READ_LATENCY_B         (READ_LATENCY),
      .READ_RESET_VALUE_B     ("0"),
      .RST_MODE_A             ("SYNC"),
      .RST_MODE_B             ("SYNC"),
      .SIM_ASSERT_CHK         (0),
      .USE_EMBEDDED_CONSTRAINT(0),
      .USE_MEM_INIT           (0),
      .WAKEUP_TIME            ("disable_sleep"),
      .WRITE_DATA_WIDTH_A     (DATA_WIDTH),
      .WRITE_MODE_B           ("read_first")
  ) u_xpm_memory_sdpram (
      .sleep         (1'b0),
      .clka          (aclk),
      .ena           (ena),
      .wea           (wea),
      .addra         (addra),
      .dina          (dina),
      .injectsbiterra(1'b0),
      .injectdbiterra(1'b0),
      .clkb          (aclk),
      .rstb          (!aresetn),
      .enb           (enb),
      .regceb        (1'b1),
      .addrb         (addrb),
      .doutb         (doutb),
      .sbiterrb      (),
      .dbiterrb      ()
  );
endmodule
