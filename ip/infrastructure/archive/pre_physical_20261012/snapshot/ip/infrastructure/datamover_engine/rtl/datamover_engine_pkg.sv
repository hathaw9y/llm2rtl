package datamover_engine_pkg;
  parameter int AXI_ADDR_WIDTH = 32;
  parameter int BTT_WIDTH = 23;
  parameter int CMD_DATA_WIDTH = 72;
  parameter int STS_DATA_WIDTH = 8;
  parameter int STS_KEEP_WIDTH = STS_DATA_WIDTH / 8;
  parameter int MM2S_DATA_WIDTH = 64;
  parameter int MM2S_KEEP_WIDTH = MM2S_DATA_WIDTH / 8;
  parameter int S2MM_DATA_WIDTH = 64;
  parameter int S2MM_KEEP_WIDTH = S2MM_DATA_WIDTH / 8;
  parameter int FIFO_DEPTH = 16;
endpackage
