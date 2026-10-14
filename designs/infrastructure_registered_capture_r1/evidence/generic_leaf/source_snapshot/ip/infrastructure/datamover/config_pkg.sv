package config_pkg;
  // Softmax operates on one attention head at a time.
  parameter int SOFTMAX_MAX_LEN = 32768;
  parameter string SOFTMAX_EXP_LUT_FILE = "pl/hdl/compute/softmax/softmax_exp_q32.mem";
  // Quantization Configuration
  parameter int ACT_EXP = 8;
  parameter int ACT_FRAC = 8;
  parameter int ACT_WIDTH = ACT_EXP + ACT_FRAC;
  parameter int GAMMA_WIDTH = 16;
  parameter int RESIDUAL_LANE_NUM = 4;
  parameter int RESIDUAL_ACT_DATA_WIDTH = ACT_WIDTH * RESIDUAL_LANE_NUM;

  // Bank configuration
  // Current token BF16 projection; pending transposed BF16 tails live in DDR.
  parameter int V_CACHE_BANK_ID = 17;
  parameter int V_CACHE_WORK_BANK_ID = 18;
  parameter int V_CACHE_LAYER_NUM = 6;
  parameter int V_CACHE_CHANNEL_NUM = 512;
  parameter int V_CACHE_TOKEN_NUM = 32;
  parameter int V_CACHE_TILE_CHANNEL_NUM = 32;
  parameter int V_CACHE_WRITE_WIDTH = 64;
  parameter int V_CACHE_READ_WIDTH = 64;
  parameter int V_CACHE_WORDS_PER_TOKEN = V_CACHE_CHANNEL_NUM / 4;
  parameter int V_CACHE_WRITE_DEPTH = V_CACHE_WORDS_PER_TOKEN;
  parameter int V_CACHE_TILE_DATA_WORDS = V_CACHE_TILE_CHANNEL_NUM * V_CACHE_TOKEN_NUM / 4;
  parameter int V_CACHE_TILE_INPUT_WORDS = V_CACHE_TILE_DATA_WORDS;
  parameter int V_CACHE_TILE_BFP4_OFFSET = V_CACHE_TILE_INPUT_WORDS;
  parameter int V_CACHE_TILE_SCALE_OFFSET = V_CACHE_TILE_BFP4_OFFSET + V_CACHE_TILE_CHANNEL_NUM * V_CACHE_TOKEN_NUM / 16;
  parameter int V_CACHE_TILE_EXPORT_WORDS = V_CACHE_TILE_SCALE_OFFSET + V_CACHE_TILE_CHANNEL_NUM / 4;
  parameter int V_CACHE_WORK_DEPTH = 512;

  parameter int BANK_NUM = 19;
  parameter int BANK_NUM_WIDTH = (BANK_NUM <= 1) ? 1 : $clog2(BANK_NUM);
  parameter int BANK_ADDR_WIDTH = 32;
  parameter int BANK_MEM_RD_LATENCY = 2;
  // One request register after BANK selection, followed by the memory pipeline.
  parameter int BANK_RD_LATENCY = 1 + BANK_MEM_RD_LATENCY;
  parameter int TOTAL_BANK_PORT_NUM = 32;
  parameter int PORT_ID_WIDTH = $clog2(TOTAL_BANK_PORT_NUM + 1);
  typedef enum logic [PORT_ID_WIDTH-1:0] {
    PORT_NONE,
    PORT_MM2S,
    PORT_S2MM,
    PORT_RN_ACT,
    PORT_RN_GAMMA,
    PORT_RN_NORM,
    PORT_GEMV_ACT,
    PORT_GEMV_WGT,
    PORT_GEMV_OUT,
    PORT_MM2S_WGT,
    PORT_GEMV_SCL,
    PORT_CONV0,
    PORT_CONV1,
    PORT_CONV2,
    PORT_CONV_WGT,
    PORT_CONV_OUT,
    PORT_EW_A,
    PORT_EW_B,
    PORT_EW_OUT,
    PORT_RESIDUAL_A,
    PORT_RESIDUAL_B,
    PORT_RESIDUAL_OUT,
    PORT_ROPE_ACT,
    PORT_ROPE_OUT,
    PORT_SOFTMAX_ACT,
    PORT_SOFTMAX_OUT,
    PORT_V_CACHE,  // BF16 projection reader
    PORT_V_CACHE_WORK_RD,
    PORT_V_CACHE_WORK_WR,
    PORT_V_CACHE_WGT,
    PORT_V_CACHE_SCL,
    PORT_INT4_ACT,
    PORT_INT4_OUT
  } port_id_t;

  // BFP Quantization configuration
  parameter int BFP_EXP_WIDTH = 8;
  parameter int MAX_BFP_QUANT_WIDTH = 8;
  parameter int BFP_QUANT_WIDTH_WIDTH = (MAX_BFP_QUANT_WIDTH <= 1) ? 1 : $clog2(
      MAX_BFP_QUANT_WIDTH + 1
  );
  parameter int BFP_QUANT_LANE_NUM = 32;
  // Shared RMSNorm/EW quantizer; GEMV instantiates a dedicated quantizer.
  parameter int BFP_QUANT_REQUEST_NUM = 2;
  parameter int BFP_QUANT_SRC_WIDTH = (BFP_QUANT_REQUEST_NUM <= 1) ? 1 : $clog2(
      BFP_QUANT_REQUEST_NUM
  );

  parameter int S2MM_DATA_WIDTH = 64;  // Matches BANK0 read width.

  // BF16 block -> symmetric INT4 with a stored BF16 maxabs/7 scale.
  parameter int INT4_QUANT_LANE_NUM = BFP_QUANT_LANE_NUM;
  parameter int INT4_QUANT_PARALLEL_NUM = 4;
  parameter int INT4_QUANT_MAX_LEN = 2048;
  parameter int INT4_QUANT_LEN_WIDTH = $clog2(INT4_QUANT_MAX_LEN + 1);
  parameter int INT4_QUANT_ACT_DATA_WIDTH = 64;
  parameter int INT4_QUANT_OUT_DATA_WIDTH = INT4_QUANT_LANE_NUM * 4 + 16;
  parameter int INT4_QUANT_OUT_KEEP_WIDTH = INT4_QUANT_OUT_DATA_WIDTH / 8;
  parameter string INT4_QUANT_LUT_FILE = "pl/hdl/compute/quantization/int4_bf16_scale_q17.mem";
  parameter string INT4_QUANT_SCALE_LUT_FILE = "pl/hdl/compute/quantization/int4_bf16_scale.mem";

  // Softmax score input and BFP8 probability output (one head per command).
  // BANK1 can be reused after QKV projections no longer need RMSNorm input.
  parameter int SOFTMAX_ACT_DATA_WIDTH = 64;
  parameter int SOFTMAX_OUT_DATA_WIDTH = BFP_QUANT_LANE_NUM * 8 + BFP_EXP_WIDTH;
  parameter int SOFTMAX_OUT_KEEP_WIDTH = SOFTMAX_OUT_DATA_WIDTH / 8;
  parameter int SOFTMAX_ACT_BANK_NUM = 2;
  parameter int SOFTMAX_ACT_BANK_IDS[SOFTMAX_ACT_BANK_NUM] = '{5, 6};
  parameter int ATTENTION_GQA_GROUP_SIZE = 4;
  parameter int SOFTMAX_P_HEAD_WORDS = (SOFTMAX_MAX_LEN + BFP_QUANT_LANE_NUM - 1) / BFP_QUANT_LANE_NUM;
  parameter int SOFTMAX_P_BANK_DEPTH = ATTENTION_GQA_GROUP_SIZE * SOFTMAX_P_HEAD_WORDS;
  parameter int SOFTMAX_OUT_BANK_NUM = 1;
  parameter int SOFTMAX_OUT_BANK_IDS[SOFTMAX_OUT_BANK_NUM] = '{1};
  parameter int SOFTMAX_LEN_WIDTH = $clog2(SOFTMAX_MAX_LEN + 1);

  // RMSNorm configuration
  // OP_RMSNORM SRC0=Activation/Residual, SRC1=gamma, SRC2=Out projection.
  // Payload bit 5 selects the initial BANK0 + zero operation.
  parameter int RN_INITIAL_BIT = 5;
  // OP_RMSNORM payload bit 4: head-wise QNorm/KNorm, no residual add or BFP.
  // Length index 0/1/2 selects 64/512/2048 BF16 elements; each head has 64.
  // SRC0 BANK5/6 -> DST BANK8/9. SRC1 BANK10 gamma offset is shared by heads.
  parameter int RN_HEAD_NORM_BIT = 4;
  parameter int QK_HEAD_DIM = 64;
  parameter int RN_MAX_LEN = 2048;
  parameter int RN_LEN_NUM = 3;
  parameter int QK_NORM_LEN_LIST[RN_LEN_NUM] = '{64, 512, 2048};
  parameter int RN_LEN_LIST[RN_LEN_NUM] = '{64, 1024, 2048};
  parameter int RN_SHIFT_LIST[RN_LEN_NUM] = '{6, 10, 11};

  parameter int RN_BFP_QUANT_WIDTH = 8;
  parameter int RN_MULT_LANE_NUM = 4;
  parameter int RN_ACT_DATA_WIDTH = RESIDUAL_ACT_DATA_WIDTH;
  parameter int RN_GAMMA_DATA_WIDTH = RN_MULT_LANE_NUM * GAMMA_WIDTH;
  parameter int RN_NORM_PAYLOAD_WIDTH = RN_BFP_QUANT_WIDTH * BFP_QUANT_LANE_NUM + BFP_EXP_WIDTH;
  parameter int RN_NORM_DATA_WIDTH = RN_NORM_PAYLOAD_WIDTH;
  parameter int RN_NORM_KEEP_WIDTH = RN_NORM_DATA_WIDTH / 8;

  parameter int RN_LANE_NUM = RESIDUAL_LANE_NUM;

  parameter int RN_ACT_BANK_NUM = 3;
  parameter int RN_ACT_BANK_IDS[RN_ACT_BANK_NUM] = '{0, 5, 6};
  parameter int RN_GAMMA_BANK_NUM = 1;
  parameter int RN_GAMMA_BANK_IDS[RN_GAMMA_BANK_NUM] = '{10};
  parameter int RN_NORM_BANK_NUM = 3;
  parameter int RN_NORM_BANK_IDS[RN_NORM_BANK_NUM] = '{1, 8, 9};

  parameter int RN_FIXED_INT_WIDTH = 16;
  parameter int RN_FIXED_FRAC_WIDTH = 16;
  parameter int RN_FIXED_WIDTH = RN_FIXED_INT_WIDTH + RN_FIXED_FRAC_WIDTH;

  parameter int RN_SSQ_LANE_NUM = 4;
  parameter int RN_SSQ_GROUP_NUM = RN_LANE_NUM / RN_SSQ_LANE_NUM;
  parameter int RN_SSQ_GROUP_WIDTH = (RN_SSQ_GROUP_NUM <= 1) ? 1 : $clog2(RN_SSQ_GROUP_NUM);

  parameter int RN_NORM_FRAC_WIDTH = 12;
  parameter int RN_NORM_MANT_WIDTH = 2 + RN_NORM_FRAC_WIDTH;
  // Relative to the repository root when running simulation or synthesis.
  parameter string RN_RSQRT_LUT_FILE = "pl/hdl/compute/rmsnorm/rmsnorm_rsqrt_bf16.mem";
  parameter int RN_RSQRT_EXP_WIDTH = 8;
  parameter int RN_RSQRT_FRAC_WIDTH = 8;  // Including the hidden bit
  parameter int RN_RSQRT_WIDTH = RN_RSQRT_EXP_WIDTH + RN_RSQRT_FRAC_WIDTH;
  parameter int RN_LUT_DEPTH = 2 ** RN_NORM_MANT_WIDTH - 2 ** RN_NORM_FRAC_WIDTH;

  parameter int RN_MULT_GROUP_NUM = RN_LANE_NUM / RN_MULT_LANE_NUM;
  parameter int RN_MULT_GROUP_WIDTH = (RN_MULT_GROUP_NUM <= 1) ? 1 : $clog2(RN_MULT_GROUP_NUM);

  parameter int RN_BFP_QUANT_ID = 0;
  parameter int RN_BFP_GROUP_NUM = BFP_QUANT_LANE_NUM / RN_MULT_LANE_NUM;
  parameter int RN_BFP_GROUP_WIDTH = (RN_BFP_GROUP_NUM <= 1) ? 1 : $clog2(RN_BFP_GROUP_NUM);

  // GEMV configuration
  parameter int GEMV_REDUCTION_NUM = 8;
  parameter int GEMV_K_TILE_SIZE = BFP_QUANT_LANE_NUM;
  parameter int GEMV_N_TILE_SIZE = GEMV_K_TILE_SIZE / GEMV_REDUCTION_NUM;  // 4
  parameter int GEMV_ACT_DATA_WIDTH = RN_NORM_DATA_WIDTH;
  parameter int GEMV_ACT_KEEP_WIDTH = GEMV_ACT_DATA_WIDTH / 8;
  parameter int GEMV_WGT_DATA_WIDTH = 512;
  parameter int GEMV_WGT_KEEP_WIDTH = GEMV_WGT_DATA_WIDTH / 8;
  // Keep 1 MiB per weight bank: 16384 512-bit words in UltraRAM.
  parameter int GEMV_WGT_BANK_DEPTH = 16384;
  parameter int GEMV_WGT_URAM_DEPTH = 4096;
  parameter int GEMV_SCL_DATA_WIDTH = GEMV_N_TILE_SIZE * 16;  // Per lane: BF16 scale for simple and attention GEMV
  parameter int GEMV_SCL_KEEP_WIDTH = GEMV_SCL_DATA_WIDTH / 8;
  parameter int GEMV_SCL_BANK_DEPTH = GEMV_WGT_BANK_DEPTH;  // One four-scale word per weight word; 128 KiB per bank.
  parameter int GEMV_MODE_SIMPLE = 0;
  parameter int GEMV_MODE_BX = 1;
  parameter int GEMV_MODE_ATTENTION = 2;
  parameter int GEMV_MODE_SWIGLU = 3;
  parameter int SWIGLU_BANK_ID = 7;
  parameter int SWIGLU_BANK_DATA_WIDTH = BFP_QUANT_LANE_NUM * MAX_BFP_QUANT_WIDTH + BFP_EXP_WIDTH;
  // SIMPLE -> BANK7 quantizes rounded BF16 results to BFP8 (e.g. PV).
  // Q occupies the first 64 words; PV can occupy the following 64 words.
  parameter int ATTENTION_PV_BANK_ID = SWIGLU_BANK_ID;
  parameter int ATTENTION_PV_BANK_OFFSET = RN_MAX_LEN / BFP_QUANT_LANE_NUM;
  parameter int SWIGLU_BANK_DEPTH = 256;  // 8192 elements; 32 BFP8 elements per word.
  parameter string SILU_LUT_FILE = "pl/hdl/compute/gemv/silu_bf16.mem";
  parameter int GEMV_BX_LANE_NUM = GEMV_N_TILE_SIZE / 2;
  parameter int GEMV_BX_OUT_DATA_WIDTH = GEMV_BX_LANE_NUM * 16;
  parameter int GEMV_BX_OUT_KEEP_WIDTH = GEMV_BX_OUT_DATA_WIDTH / 8;
  parameter int GEMV_OUT_BANK_DATA_WIDTH = 64;
  parameter int GEMV_BF16_OUT_DATA_WIDTH = GEMV_N_TILE_SIZE * 16;
  parameter int GEMV_BF16_OUT_KEEP_WIDTH = GEMV_BF16_OUT_DATA_WIDTH / 8;
  parameter int GEMV_OUT_DATA_WIDTH = 1024;
  parameter int GEMV_OUT_KEEP_WIDTH = GEMV_OUT_DATA_WIDTH / 8;
  parameter int GEMV_ACT_BANK_NUM = 2;
  parameter int GEMV_ACT_BANK_IDS[GEMV_ACT_BANK_NUM] = '{1, SWIGLU_BANK_ID};
  parameter int GEMV_WGT_BANK_NUM = 2;
  parameter int GEMV_WGT_BANK_IDS[GEMV_WGT_BANK_NUM] = '{14, 15};
  parameter int GEMV_SCL_BANK_NUM = 2;
  parameter int GEMV_SCL_BANK_IDS[GEMV_SCL_BANK_NUM] = '{12, 13};
  // Attention reuses BANK5 for BF16 Q projection and BANK6 for BF16 K projection.
  parameter int GEMV_OUT_BANK_NUM = 7;
  parameter int GEMV_OUT_BANK_IDS[GEMV_OUT_BANK_NUM] = '{
      2,
      3,
      4,
      6,
      SWIGLU_BANK_ID,
      5,
      V_CACHE_BANK_ID
  };

  parameter int GEMV_CMD_MODE_WIDTH = 2;

  parameter int PV_MAX_CONTEXT = 32768;
  parameter int PV_HEAD_DIM = 64;
  parameter int GEMV_MAX_K = 32768;  // One complete PV context, without command-level chunk accumulation.
  parameter int GEMV_K_WIDTH = (GEMV_MAX_K <= 1) ? 1 : $clog2(GEMV_MAX_K + 1);
  parameter int GEMV_SIMPLE_MAX_N = 4608;
  parameter int GEMV_MAX_N = PV_MAX_CONTEXT;  // Attention N counts tokens, SIMPLE N counts output channels.
  parameter int GEMV_N_WIDTH = (GEMV_MAX_N <= 1) ? 1 : $clog2(GEMV_MAX_N + 1);
  parameter int GEMV_K_TILE_WIDTH = (GEMV_MAX_K / GEMV_K_TILE_SIZE <= 1) ? 1 : $clog2(
      GEMV_MAX_K / GEMV_K_TILE_SIZE + 1
  );
  parameter int GEMV_N_TILE_WIDTH = (GEMV_MAX_N / GEMV_N_TILE_SIZE <= 1) ? 1 : $clog2(
      GEMV_MAX_N / GEMV_N_TILE_SIZE + 1
  );

  parameter int GEMV_ACT_WIDTH = 8;
  parameter int GEMV_EXP_WIDTH = 8;
  parameter int GEMV_WGT_WIDTH = 4;
  parameter int GEMV_SCL_WIDTH = 16;
  // RoPE: split-half pairs (i, i+32); FP32 coefficient recurrence, BF16 rotation.
  parameter int ROPE_HEAD_DIM = QK_HEAD_DIM;
  parameter int ROPE_LANE_NUM = 4;
  parameter int ROPE_POSITION_WIDTH = 32;
  parameter int ROPE_MAX_LEN = 2048;
  parameter int ROPE_LEN_WIDTH = $clog2(ROPE_MAX_LEN + 1);
  parameter int ROPE_Q_BANK_ID = 7;
  parameter int ROPE_K_BANK_ID = 16;
  parameter int ROPE_K_BF16_BANK_ID = 5;
  parameter int ROPE_K_DATA_WIDTH = BFP_QUANT_LANE_NUM * 4 + 16;
  parameter int ROPE_K_DEPTH = 512 / BFP_QUANT_LANE_NUM;
  parameter int ROPE_K_INT4_BYTES = ROPE_K_DEPTH * BFP_QUANT_LANE_NUM * 4 / 8;
  parameter int ROPE_K_SCALE_BYTES = ROPE_K_DEPTH * GEMV_SCL_WIDTH / 8;
  // BANK16 read offsets are 64-bit words: INT4 starts at0, BF16 scales at32.
  parameter int ROPE_K_SCALE_READ_OFFSET = ROPE_K_INT4_BYTES / (S2MM_DATA_WIDTH / 8);
  parameter int ROPE_K_READ_WORDS = (ROPE_K_INT4_BYTES + ROPE_K_SCALE_BYTES) / (S2MM_DATA_WIDTH / 8);
  parameter int ROPE_ACT_DATA_WIDTH = ROPE_LANE_NUM * ACT_WIDTH;
  parameter int ROPE_ACT_BANK_NUM = 2;
  parameter int ROPE_ACT_BANK_IDS[ROPE_ACT_BANK_NUM] = '{8, 9};
  parameter int ROPE_OUT_DATA_WIDTH = BFP_QUANT_LANE_NUM * MAX_BFP_QUANT_WIDTH + BFP_EXP_WIDTH;
  parameter int ROPE_OUT_KEEP_WIDTH = ROPE_OUT_DATA_WIDTH / 8;
  typedef enum logic {
    ROPE_COMPUTE,
    ROPE_UPDATE
  } rope_mode_t;
  parameter string ROPE_DELTA_LUT_FILE = "pl/hdl/compute/rope/rope_delta_fp32.mem";
  // Conv configuration
  parameter int CONV_DATA_WIDTH = 64;
  parameter int CONV_WGT_DATA_WIDTH = 192;
  parameter int CONV_OUT_DATA_WIDTH = 64;
  parameter int CONV_KEEP_WIDTH = CONV_DATA_WIDTH / 8;
  parameter int CONV_WORD_SIZE = 4;
  parameter int CONV_LENGTH = 2048;
  parameter int CONV_WORD_NUM = CONV_LENGTH / CONV_WORD_SIZE;
  parameter int CONV_BRAM_BASE_DEPTH = 4096;
  parameter int CONV_BANK_DEPTH = 5120;  // Ten layers of 512 BF16 words each.

  parameter int CONV_BANK_NUM = 3;
  parameter int CONV_BANK_IDS[CONV_BANK_NUM] = '{2, 3, 4};
  parameter int CONV_WGT_BANK_NUM = 1;
  parameter int CONV_WGT_BANK_IDS[CONV_WGT_BANK_NUM] = '{11};
  parameter int CONV_OUT_BANK_NUM = 1;
  parameter int CONV_OUT_BANK_IDS[CONV_OUT_BANK_NUM] = '{5};
  // Element-wise BF16 multiplication followed by shared BFP8 quantization.
  parameter int EW_LANE_NUM = 4;
  parameter int EW_MAX_LEN = 2048;
  parameter int EW_A_DATA_WIDTH = EW_LANE_NUM * ACT_WIDTH;
  parameter int EW_B_DATA_WIDTH = EW_LANE_NUM * ACT_WIDTH;
  parameter int EW_BFP_QUANT_WIDTH = 8;
  parameter int EW_OUT_DATA_WIDTH = BFP_QUANT_LANE_NUM * EW_BFP_QUANT_WIDTH + BFP_EXP_WIDTH;
  parameter int EW_OUT_KEEP_WIDTH = EW_OUT_DATA_WIDTH / 8;
  parameter int EW_BFP_QUANT_ID = 1;
  parameter int EW_A_BANK_NUM = 1;
  parameter int EW_A_BANK_IDS[EW_A_BANK_NUM] = '{5};
  parameter int EW_B_BANK_NUM = 1;
  parameter int EW_B_BANK_IDS[EW_B_BANK_NUM] = '{6};
  // BANK7 lets Conv*C write BFP8 while C projection still reads BANK1.
  // BANK1 remains available for existing element-wise commands.
  parameter int EW_OUT_BANK_NUM = 2;
  parameter int EW_OUT_BANK_IDS[EW_OUT_BANK_NUM] = '{1, SWIGLU_BANK_ID};

  // Residual addition: BANK0 + Out projection BANK6 -> BANK0.
  parameter int RESIDUAL_MAX_LEN = 2048;
  parameter int RESIDUAL_A_DATA_WIDTH = 64;
  parameter int RESIDUAL_B_DATA_WIDTH = 64;
  parameter int RESIDUAL_OUT_DATA_WIDTH = 64;
  parameter int RESIDUAL_OUT_KEEP_WIDTH = RESIDUAL_OUT_DATA_WIDTH / 8;
  parameter int RESIDUAL_A_BANK_NUM = 1;
  parameter int RESIDUAL_A_BANK_IDS[RESIDUAL_A_BANK_NUM] = '{0};
  parameter int RESIDUAL_BANK_NUM = 1;
  parameter int RESIDUAL_BANK_IDS[RESIDUAL_BANK_NUM] = '{6};
  parameter int RESIDUAL_OUT_BANK_NUM = 1;
  parameter int RESIDUAL_OUT_BANK_IDS[RESIDUAL_OUT_BANK_NUM] = '{0};

  // Datamover configuration
  parameter int MM2S_DATA_WIDTH = 64;
  parameter int MM2S_KEEP_WIDTH = MM2S_DATA_WIDTH / 8;
  parameter int MM2S_WGT_PORT_NUM = 4;
  parameter int MM2S_WGT_DATA_WIDTH = 128;
  parameter int MM2S_WGT_KEEP_WIDTH = MM2S_WGT_DATA_WIDTH / 8;
  // Default DDR windows match the existing HP0, HP1, HP2, HP3 address map.
  parameter logic [31:0] MM2S_WGT_BASE_ADDR[MM2S_WGT_PORT_NUM] = '{
      32'h00000000,
      32'h20000000,
      32'h60000000,
      32'h40000000
  };
  parameter int MM2S_WGT_BANK_NUM = 2;
  parameter int MM2S_WGT_BANK_IDS[MM2S_WGT_BANK_NUM] = '{14, 15};
  parameter int MM2S_FIFO_DEPTH = 16;
  parameter int S2MM_FIFO_DEPTH = 16;
  parameter int MM2S_BANK_NUM = 9;
  parameter int MM2S_BANK_IDS[MM2S_BANK_NUM] = '{
      0,
      2,
      3,
      4,
      10,
      11,
      12,
      13,
      V_CACHE_WORK_BANK_ID
  };  // Activation, history initialization, gamma, Conv weight, scales
  parameter int S2MM_BANK_NUM = 4;
  parameter int S2MM_BANK_IDS[S2MM_BANK_NUM] = '{
      0,
      ROPE_K_BANK_ID,
      V_CACHE_WORK_BANK_ID,
      6
  };  // Residual, K/V cache and GEMV BF16 result readout

  typedef enum logic [2:0] {
    BANK_NONE,
    BANK_BRAM,
    BANK_URAM,
    BANK_URAM_BRAM,
    BANK_NON_POT_BRAM,
    BANK_REGISTERS,
    BANK_V_CACHE
  } bank_type_t;

  // BANK7 stores SwiGLU/Q/PV BFP8; BANK8/9 store BF16 QNorm/KNorm output.
  localparam bank_type_t BANK_TYPE[BANK_NUM] = '{
      0: BANK_BRAM,
      1: BANK_BRAM,
      2: BANK_BRAM,
      3: BANK_BRAM,
      4: BANK_BRAM,
      5: BANK_BRAM,
      6: BANK_BRAM,
      7: BANK_BRAM,
      8: BANK_BRAM,
      9: BANK_BRAM,
      10: BANK_BRAM,
      11: BANK_NON_POT_BRAM,
      12: BANK_URAM,
      13: BANK_URAM,
      14: BANK_URAM,
      15: BANK_URAM,
      16: BANK_REGISTERS,
      17: BANK_BRAM,
      18: BANK_BRAM,
      default: BANK_NONE
  };

  localparam int BANK_WRITE_WIDTH[BANK_NUM] = '{
      0: 64,
      1: RN_NORM_DATA_WIDTH,
      2: 64,
      3: 64,
      4: 64,
      5: 64,
      6: 64,
      7: SWIGLU_BANK_DATA_WIDTH,
      8: 64,
      9: 64,
      10: MM2S_DATA_WIDTH,
      11: MM2S_DATA_WIDTH,
      12: MM2S_DATA_WIDTH,
      13: MM2S_DATA_WIDTH,
      14: GEMV_WGT_DATA_WIDTH,
      15: GEMV_WGT_DATA_WIDTH,
      16: ROPE_K_DATA_WIDTH,
      17: V_CACHE_WRITE_WIDTH,
      18: 64,
      default: 0
  };

  localparam int BANK_READ_WIDTH[BANK_NUM] = '{
      0: 64,
      1: RN_NORM_DATA_WIDTH,
      2: 64,
      3: 64,
      4: 64,
      5: 64,
      6: 64,
      7: SWIGLU_BANK_DATA_WIDTH,
      8: 64,
      9: 64,
      10: RN_GAMMA_DATA_WIDTH,
      11: CONV_WGT_DATA_WIDTH,
      12: GEMV_SCL_DATA_WIDTH,
      13: GEMV_SCL_DATA_WIDTH,
      14: GEMV_WGT_DATA_WIDTH,
      15: GEMV_WGT_DATA_WIDTH,
      16: S2MM_DATA_WIDTH,
      17: V_CACHE_READ_WIDTH,
      18: 64,
      default: 0
  };

  // BRAM depths count write words; UltraRAM depths count read words.
  localparam int BANK_DEPTH[BANK_NUM] = '{
      0: 512,
      1: SOFTMAX_P_BANK_DEPTH,
      2: CONV_BANK_DEPTH,
      3: CONV_BANK_DEPTH,
      4: CONV_BANK_DEPTH,
      5: RN_MAX_LEN / (GEMV_OUT_BANK_DATA_WIDTH / ACT_WIDTH),  // Conv/Q/rotated K; QK scores use BANK6.
      6: PV_MAX_CONTEXT / 4,
      7: SWIGLU_BANK_DEPTH,
      8: 512,
      9: 512,
      10: RN_MAX_LEN / (MM2S_DATA_WIDTH / GAMMA_WIDTH),  // One 2048-element gamma vector, loaded at offset zero.
      11: CONV_WORD_NUM * (CONV_WGT_DATA_WIDTH / MM2S_DATA_WIDTH),
      12: GEMV_SCL_BANK_DEPTH,
      13: GEMV_SCL_BANK_DEPTH,
      14: GEMV_WGT_BANK_DEPTH,
      15: GEMV_WGT_BANK_DEPTH,
      16: ROPE_K_DEPTH,
      17: V_CACHE_WRITE_DEPTH,
      18: V_CACHE_WORK_DEPTH,
      default: 0
  };
  parameter int MAX_BANK_WR_WIDTH = 1024;
  parameter int MAX_BANK_WE_WIDTH = MAX_BANK_WR_WIDTH / 8;
  parameter int MAX_BANK_RD_WIDTH = 1024;

  // Register configuration
  parameter int REG_NUM = 4;
  parameter int REG_NUM_WIDTH = (REG_NUM <= 1) ? 1 : $clog2(REG_NUM);
  parameter int REG_DATA_WIDTH = 32;

  // Command configuration
  parameter int CMD_DATA_WIDTH = 128;  // Five-bit BANK IDs leave a 99-bit payload.
  parameter int OPCODE_WIDTH = 4;
  parameter int CMD_SRC_BANK_NUM = 4;
  parameter int PAYLOAD_WIDTH = CMD_DATA_WIDTH - OPCODE_WIDTH - BANK_NUM_WIDTH * (CMD_SRC_BANK_NUM + 1);
  // Controller register instructions: payload[34:32]=index, [31:0]=immediate.
  // BANK fields are ignored; higher payload bits are reserved and must be zero.
  parameter int CMD_REG_NUM = 8;
  parameter int CMD_REG_DATA_WIDTH = 32;
  parameter int CMD_REG_INDEX_WIDTH = $clog2(CMD_REG_NUM);
  parameter int CMD_REG_IMM_OFFSET = CMD_REG_DATA_WIDTH - 1;
  parameter int CMD_REG_INDEX_OFFSET = CMD_REG_DATA_WIDTH + CMD_REG_INDEX_WIDTH - 1;
  // DMA/GEMV reuse the otherwise unused SRC3 BANK field as operand flags.
  // With a flag set, the corresponding address field holds an R0-R7 index.
  parameter int CMD_ADDR0_REG_BIT = 0;  // DMA DDR/WLOAD offset; GEMV ACT offset.
  parameter int CMD_ADDR1_REG_BIT = 1;  // DMA BANK offset; GEMV OUT offset.
  // Layer context: R4=descriptor table, R5=layer index, R6=remaining layers,
  // R7=token position. Descriptor records are 256 bytes / 64 little-endian words.
  parameter int LAYER_DESC_WORDS = 64;
  parameter int LAYER_DESC_BYTES = LAYER_DESC_WORDS * 4;
  parameter int LAYER_MAX_NUM = 16;
  parameter int LAYER_KV_NUM = 6;
  parameter logic [31:0] LAYER_DESC_MAGIC = 32'h4c594452;
  parameter logic [31:0] LAYER_DESC_VERSION = 32'd2;
  parameter int LAYER_DESC_K_PORT0 = 28;
  parameter int LAYER_DESC_K_SCALE = 32;
  parameter int LAYER_DESC_K_HEAD_STRIDE = 33;
  parameter int LAYER_DESC_K_SCALE_STRIDE = 34;
  parameter int LAYER_DESC_MAX_CONTEXT = 35;
  parameter logic [1:0] LAYER_LOAD_DESC = 2'd0;
  parameter logic [1:0] LAYER_STORE_K = 2'd1;
  parameter logic [1:0] LAYER_LOAD_V = 2'd2;
  parameter logic [1:0] LAYER_STORE_V = 2'd3;
  parameter int LAYER_DESC_V_PORT0 = 36;
  parameter int LAYER_DESC_V_SCALE = 40;
  parameter int LAYER_DESC_V_HEAD_STRIDE = 41;
  parameter int LAYER_DESC_V_SCALE_STRIDE = 42;
  parameter int LAYER_DESC_V_TAIL = 43;
  parameter int LAYER_DESC_V_EXP = 44;  // Reserved in descriptor v2 (no EXP tail).
  // OP_V_CACHE: SRC0=17, SRC1=18 (in-place), SRC2=12/13, DST=14/15.
  // LSB fields: token slot [4:0], 32-channel tile [8:5], WGT word base, SCL word base.
  parameter int V_CACHE_CMD_SLOT_OFFSET = 4;
  parameter int V_CACHE_CMD_TILE_OFFSET = 8;
  parameter int V_CACHE_CMD_WGT_OFFSET = 40;
  parameter int V_CACHE_CMD_SCL_OFFSET = 72;
  // OP_ROPE payload bit0=1 selects the INT4 quantizer subcommand instead of
  // rotation. All other reserved low bits are zero; CMD/opcode widths stay fixed.
  parameter int INT4_QUANT_CMD_BIT = 0;
  // INT4 quantizer engine: MSB-first BF16 element count, 64-bit input word
  // offset, then packed INT4+BF16-scale output word offset. Not an opcode yet.
  parameter int INT4_QUANT_CMD_LEN_OFFSET = PAYLOAD_WIDTH - 1;
  parameter int INT4_QUANT_CMD_ACT_OFFSET = INT4_QUANT_CMD_LEN_OFFSET - INT4_QUANT_LEN_WIDTH;
  parameter int INT4_QUANT_CMD_OUT_OFFSET = INT4_QUANT_CMD_ACT_OFFSET - BANK_ADDR_WIDTH;
  // OP_SOFTMAX payload: MSB-first length, input word offset, output block offset.
  parameter int SOFTMAX_CMD_LEN_OFFSET = PAYLOAD_WIDTH - 1;
  parameter int SOFTMAX_CMD_ACT_OFFSET = SOFTMAX_CMD_LEN_OFFSET - SOFTMAX_LEN_WIDTH;
  parameter int SOFTMAX_CMD_OUT_OFFSET = SOFTMAX_CMD_ACT_OFFSET - BANK_ADDR_WIDTH;
  // RMSNorm uses a compact, LSB-anchored payload independent of CMD width.
  // Offsets count BANK words; all current ACT/output BANKs have depth 512.
  parameter int RN_LEN_IDX_WIDTH = $clog2(RN_LEN_NUM);
  parameter int RN_ACT_ADDR_WIDTH = $clog2(BANK_DEPTH[RN_ACT_BANK_IDS[0]]);
  parameter int RN_GAMMA_ADDR_WIDTH = $clog2(BANK_DEPTH[RN_GAMMA_BANK_IDS[0]]);
  parameter int RN_NORM_ADDR_WIDTH = $clog2(BANK_DEPTH[RN_NORM_BANK_IDS[0]]);
  parameter int RN_CMD_NORM_ADDR_OFFSET = RN_INITIAL_BIT + RN_NORM_ADDR_WIDTH;
  parameter int RN_CMD_GAMMA_ADDR_OFFSET = RN_CMD_NORM_ADDR_OFFSET + RN_GAMMA_ADDR_WIDTH;
  parameter int RN_CMD_ACT_ADDR_OFFSET = RN_CMD_GAMMA_ADDR_OFFSET + RN_ACT_ADDR_WIDTH;
  parameter int RN_CMD_LEN_IDX_OFFSET = RN_CMD_ACT_ADDR_OFFSET + RN_LEN_IDX_WIDTH;
  parameter int RN_CMD_PAYLOAD_WIDTH = RN_CMD_LEN_IDX_OFFSET + 1;
  // MSB-first header: OPCODE, SRC0, SRC1, SRC2, SRC3, DST; payload fills the low bits.
  parameter int CMD_OPCODE_OFFSET = CMD_DATA_WIDTH - 1;
  parameter int CMD_SRC0_BANK_OFFSET = CMD_OPCODE_OFFSET - OPCODE_WIDTH;
  parameter int CMD_SRC1_BANK_OFFSET = CMD_SRC0_BANK_OFFSET - BANK_NUM_WIDTH;
  parameter int CMD_SRC2_BANK_OFFSET = CMD_SRC1_BANK_OFFSET - BANK_NUM_WIDTH;
  parameter int CMD_SRC3_BANK_OFFSET = CMD_SRC2_BANK_OFFSET - BANK_NUM_WIDTH;
  parameter int CMD_DST_BANK_OFFSET = CMD_SRC3_BANK_OFFSET - BANK_NUM_WIDTH;
  typedef enum logic [OPCODE_WIDTH-1:0] {
    OP_END,
    OP_DMA_LOAD,
    OP_S2MM,
    OP_RMSNORM,
    OP_GEMV,
    OP_DMA_WLOAD,
    OP_CONV,
    OP_ELEMENT_WISE,
    OP_LAYER_CTRL,    // Former reserved opcode8: descriptor load / K cache store.
    OP_ROPE,
    OP_ROPE_UPDATE,
    OP_SOFTMAX,
    OP_V_CACHE,
    OP_SET_REG,       // R[index] = immediate.
    OP_ADD_REG,       // R[index] = R[index] + immediate, modulo 2^32.
    OP_LOOP           // Decrement R[index]; jump to immediate command address if nonzero.
  } opcode_t;
  parameter int ERROR_CODE_WIDTH = OPCODE_WIDTH + 3;

endpackage
