# Independent intermediate quantizer review

Read-only source, numeric, protocol, test and tool-evidence review using fpga-systemverilog, fpga-quantization and fpga-vivado. Reviewer edited no RTL, shared tests/reference, contracts or scripts. This report is the only repository output. Frozen packet hash 25f32c88bfda1ae3285b4c892b52301ebf490d9da46c618b95b7d44960906361 was verified. The current common-contract structural gate was independently run and passed for four declared contracts; this gate is not RTL or model proof.

## Result

No blocking finding remains for the frozen standalone quantizer packet and tested configurations. The implementation is a reusable two-pass streaming arithmetic child; it is not full Attention RTL, a bank adapter, a model-quality result, or a board deployment.

## Numeric review

Finite normal FP32 inputs are decoded exactly by magnitude; exponent-zero subnormals and signed zero are deliberately treated as zero. Positive normal encodings are monotonic, so the row maximum comparison is valid. A zero row produces scale 0x3f80. Any NaN or infinity records an error and the complete commanded row is consumed before an error response; no quantized output is produced.

For nonzero maximum with FP32 exponent E and 24-bit significand M, the scale normalization uses M < 7*2^21 with BF16 exponent E-3/divisor 7*2^13, otherwise exponent E-2/divisor 7*2^14. Dividing only the high 11/10 bits by 7 and concatenating remainder plus low bits preserves the exact remainder. Quotient parity implements RNE, including a 256 significand carry; nonpositive resulting BF16 exponent is clamped to 0x0080. This correctly handles tiny exponent-3 inputs above the normalization threshold, which may require scale greater than minimum normal.

Each boundary (k+0.5)*scale is exactly representable in FP32: BF16's eight-bit significand multiplied by an odd integer at most 13 requires at most 12 significant bits. Threshold normalization and exponent-zero encoding preserve the half-minimum-normal scale as an FP32 subnormal; only input values are FTZ. Strict/inclusive comparisons alternate so exact ties select the even integer. Seven threshold crossings yield magnitude 0..7; four-bit negation gives symmetric signed INT4 -7..7 and cannot emit code -8. There is no approximate reciprocal or synthesized real arithmetic. Dequantization is q times the decoded BF16 scale.

The Python Fraction/integer oracle was inspected independently and does not copy the RTL's bit-sliced implementation. Reviewer additionally compared a separately derived normalization/quotient/remainder scale calculation with the current Fraction oracle for 22,352 magnitudes across every finite normal FP32 exponent, random significands, and normalization edges. All matched. The current reference hash and result are recorded in /tmp/quantizer_readonly_review/scale_oracle_check.json. This is additional software-oracle validation, not a separate RTL simulation.

## Protocol and implementation review

A command is accepted only in IDLE. Exactly the accepted count is collected; invalid counts consume no input and emit no output. Buffer indexing is bounded for one-element, power-of-two, and non-power-of-two capacities. The row memory is not reset, but only newly accepted row addresses can be replayed. Last-input magnitude/error updates precede scale preparation. Reset clears state and valid flags, cancelling activity without exposing stale buffer contents.

Replay uses registered BRAM read, comparison flags and a balanced reduction/sign stage. The whole replay pipeline stalls when its output is valid and not ready, retaining quantized data, scale and last. Unstalled replay supports one word per cycle after pipeline fill; a command remains single-outstanding through its held response. Completion is entered only after the last quantized output handshake, or after a fully consumed nonfinite row/invalid command. Response ID/error remain stable until acceptance. No input or output activity is permitted for a completed command.

The output carries one INT4 nibble and its common BF16 scale per transfer; nibble packing, scale-metadata storage and native-bank/controller integration are separate. A later adapter must not authorize bank release until its own payload and scale writes have all been accepted. The caller selects one activation token row, one KV token/head row, or one weight group/tail per command. A full row exceeding the default MAX_ELEMENTS=256 needs a larger independently verified instantiation or a scale-preserving higher-level schedule; splitting it into independent commands changes the scale granularity.

## Independently executed checks

Reviewer ran strict Verilator --lint-only -Wall, with no warning waiver, on current RTL for MAX_ELEMENTS 1, 13, 15 and 256. All exit 0 with empty warning output. This includes the full-count-range generate branch and the non-power-of-two branch. Logs, exit files and RTL identity are in /tmp/quantizer_readonly_review/lint_max*.log, lint_max*.exit and rtl_identity.json. Dynamic evidence below covers MAX_ELEMENTS 13 and 256; the additional parameter lint profiles are structural checks only.

## Completed producer evidence inspected

Reviewer did not execute XSIM or Vivado synthesis. The completed quantizer_final001 packet was independently inspected: every manifest source/vector hash matches current contents, compile/elaboration/simulation/lint/synthesis exit files are zero, both decoded simulation outputs contain the exact standalone ATTENTION_INT4_QUANTIZER_XSIM_PASS, and the synthesis log contains exactly one executed standalone ATTENTION_INT4_QUANTIZER_OOC_PASS. The completion result records source identity PASS. Historical quantizer_try001 is not reused as current-source evidence.

MAX_ELEMENTS=13 reports 173 independent oracle rows and 179 cases; MAX_ELEMENTS=256 reports 156 oracle rows and 162 cases. Vectors include signed zero/FTZ, min-normal scale clamp and tiny exponent-3 boundaries, scale RNE ties and quantization halfway ties with sign/parity, extrema, every normal exponent, random rows, maximum lengths/group tails, and nonfinite first/middle/last positions. The self-checking TB verifies exact nibble/scale/last, complete nonfinite input consumption, invalid counts, input gaps, output/response stalls, response identity, completion only after the last payload acceptance, reset during input/output stalls, and repeated command use.

## OOC synthesis and timing scope

Actual tool Vivado 2025.2, part xczu7ev-ffvc1156-2-e, top attention_int4_quantizer, default MAX_ELEMENTS=256, aclk period 5 ns. The synthesized report maps the 256x32 row buffer to one RAMB18E2: 600 LUTs, 295 FFs, one RAMB18, zero RAMB36/URAM/DSP. The clock/source context and 0.5 ns setup boundary delays are explicit. Internal estimated setup/hold and pulse-width reports show WNS 2.240 ns, WHS 0.084 ns, WPWS 1.958 ns, all total violations zero and zero failing endpoints. These values were read directly from the reports, not inferred from the completion marker.

External input/output hold paths are explicitly excluded; this is unplaced synthesized OOC timing, not physical external-I/O or routed board signoff. DRC reports zero checks found. Methodology has one SYNTH-6 warning: the inferred BRAM did not merge an output register, so memory timing may be suboptimal in a future integration. Synthesis also emits normal OOC DRC coverage/floorplanning warnings. No routed timing, congestion, full Attention resources, or board runtime is claimed.

## Limits

Numerical behavior is exact relative to the declared FTZ/minimum-scale/symmetric-INT4 contract. No calibration tensors, whole-model quality, full Attention execution, weight/KV packing, AXI/native-bank connection, metadata write completion, or physical FPGA run was validated. New generated adapters and larger capacities require fresh contracts and source-bound tests. The OOC estimates support this standalone module's bounded 200 MHz analysis only; integration requires fresh timing context.

## Reviewed current identity

- `designs/attention_int4_noscale_zcu104_r1/rtl/attention_int4_quantizer.sv`: `9740ff60facbed8a74f3a881dfd1d51316719a9a31a44d1852515fccbcc9db5c`
- `designs/attention_int4_noscale_zcu104_r1/reference/quantizer_reference.py`: `b1bd5271a8b8c98c015bb579432a141f9dc938fe7114b4708b1f0ea5f629fefe`
- `designs/attention_int4_noscale_zcu104_r1/tb/tb_attention_int4_quantizer.sv`: `3189e03cd6bb2b5b3ad5c4da3f2f3171ef719cb90ec98b7601b77f670d7f5419`
- `designs/attention_int4_noscale_zcu104_r1/modules/attention_int4_quantizer.json`: `25f32c88bfda1ae3285b4c892b52301ebf490d9da46c618b95b7d44960906361`
- `designs/attention_int4_noscale_zcu104_r1/scripts/run_quantizer.py`: `e9372369deee03bc06969de449ac9e63fe134c6fd66befe132e6a0eebefaf964`
- `designs/attention_int4_noscale_zcu104_r1/scripts/quantizer_ooc.tcl`: `165a8bf381323968858e4e9e24c5e00576b70a7d8510afa437de39a34aad7e19`
