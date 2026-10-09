`timescale 1ns/1ps
module audit_decode_tb;
logic  clk;
logic  resetn;
logic  start;
logic [127:0] cmd_doutb;
logic  busy;
logic  done;
logic  error;
logic [7:0] error_code;
logic [3:0] current_pc;
logic  cmd_enb;
logic [3:0] cmd_addrb;
logic [3:0] engine_cmd_valid;
logic [15:0] engine_cmd_opcode;
logic [447:0] engine_cmd_payload;
logic [47:0] engine_cmd_bank_ids;
logic [127:0] engine_cmd_transaction_id;
logic [383:0] engine_cmd_generations;
logic [11:0] engine_cmd_desc_present;
logic [59:0] engine_cmd_profiles;
logic [131:0] engine_cmd_rows;
logic [191:0] engine_cmd_cols;
logic [119:0] engine_cmd_positions;
logic [59:0] engine_cmd_layers;
logic [383:0] engine_cmd_desc_generations;
logic [11:0] engine_cmd_data_valid;
logic [11:0] engine_cmd_scale_valid;
logic [11:0] engine_cmd_desc_busy;
logic [59:0] engine_cmd_desc_owner;
logic [3:0] engine_cmd_b7_static_valid;
logic [255:0] engine_cmd_embedding_lanes;
logic [127:0] engine_cmd_embedding_lane_valid;
logic [3:0] engine_cmd_ready;
logic [3:0] engine_resp_valid;
logic [127:0] engine_resp_transaction_id;
logic [11:0] engine_resp_used_bank_mask;
logic [7:0] engine_resp_used_bank_count;
logic [47:0] engine_resp_bank_ids;
logic [383:0] engine_resp_generations;
logic [31:0] engine_resp_error_code;
logic [3:0] engine_resp_ready;
logic [15:0] bank_busy;
logic [79:0] bank_owner_port;
logic [15:0] bank_desc_present;
logic [79:0] bank_profiles;
logic [175:0] bank_rows;
logic [255:0] bank_cols;
logic [159:0] bank_positions;
logic [79:0] bank_layers;
logic [511:0] bank_generations;
logic [15:0] bank_data_valid;
logic [15:0] bank_scale_valid;
logic  bank_b7_static_valid;
logic  bank_b7_rope_valid;
logic [63:0] bank_embedding_lanes;
logic [31:0] bank_embedding_lane_valid;
logic  acquire_valid;
logic [31:0] acquire_transaction_id;
logic [2:0] acquire_used_bank_mask;
logic [11:0] acquire_bank_ids;
logic [14:0] acquire_roles;
logic [95:0] acquire_generations;
logic  acquire_ready;
logic [7:0] acquire_error_code;
logic  release_valid;
logic [31:0] release_transaction_id;
logic [2:0] release_used_bank_mask;
logic [11:0] release_bank_ids;
logic [14:0] release_roles;
logic [95:0] release_generations;
logic  release_ready;
logic [7:0] release_error_code;
logic  cfg_valid;
logic [31:0] cfg_transaction_id;
logic [3:0] cfg_bank;
logic [4:0] cfg_profile;
logic [10:0] cfg_rows;
logic [15:0] cfg_cols;
logic [9:0] cfg_position;
logic [4:0] cfg_layer;
logic [1:0] cfg_component;
logic [31:0] cfg_generation;
logic  cfg_resp_ready;
logic  cfg_ready;
logic  cfg_resp_valid;
logic [31:0] cfg_resp_transaction_id;
logic [7:0] cfg_resp_error_code;
logic [128:0] vectors[0:2956];
logic [127:0] record;
int checked=0;
smollm2_isa_dispatcher dut(.clk(clk),
.resetn(resetn),
.start(start),
.cmd_doutb(cmd_doutb),
.busy(busy),
.done(done),
.error(error),
.error_code(error_code),
.current_pc(current_pc),
.cmd_enb(cmd_enb),
.cmd_addrb(cmd_addrb),
.engine_cmd_valid(engine_cmd_valid),
.engine_cmd_opcode(engine_cmd_opcode),
.engine_cmd_payload(engine_cmd_payload),
.engine_cmd_bank_ids(engine_cmd_bank_ids),
.engine_cmd_transaction_id(engine_cmd_transaction_id),
.engine_cmd_generations(engine_cmd_generations),
.engine_cmd_desc_present(engine_cmd_desc_present),
.engine_cmd_profiles(engine_cmd_profiles),
.engine_cmd_rows(engine_cmd_rows),
.engine_cmd_cols(engine_cmd_cols),
.engine_cmd_positions(engine_cmd_positions),
.engine_cmd_layers(engine_cmd_layers),
.engine_cmd_desc_generations(engine_cmd_desc_generations),
.engine_cmd_data_valid(engine_cmd_data_valid),
.engine_cmd_scale_valid(engine_cmd_scale_valid),
.engine_cmd_desc_busy(engine_cmd_desc_busy),
.engine_cmd_desc_owner(engine_cmd_desc_owner),
.engine_cmd_b7_static_valid(engine_cmd_b7_static_valid),
.engine_cmd_embedding_lanes(engine_cmd_embedding_lanes),
.engine_cmd_embedding_lane_valid(engine_cmd_embedding_lane_valid),
.engine_cmd_ready(engine_cmd_ready),
.engine_resp_valid(engine_resp_valid),
.engine_resp_transaction_id(engine_resp_transaction_id),
.engine_resp_used_bank_mask(engine_resp_used_bank_mask),
.engine_resp_used_bank_count(engine_resp_used_bank_count),
.engine_resp_bank_ids(engine_resp_bank_ids),
.engine_resp_generations(engine_resp_generations),
.engine_resp_error_code(engine_resp_error_code),
.engine_resp_ready(engine_resp_ready),
.bank_busy(bank_busy),
.bank_owner_port(bank_owner_port),
.bank_desc_present(bank_desc_present),
.bank_profiles(bank_profiles),
.bank_rows(bank_rows),
.bank_cols(bank_cols),
.bank_positions(bank_positions),
.bank_layers(bank_layers),
.bank_generations(bank_generations),
.bank_data_valid(bank_data_valid),
.bank_scale_valid(bank_scale_valid),
.bank_b7_static_valid(bank_b7_static_valid),
.bank_b7_rope_valid(bank_b7_rope_valid),
.bank_embedding_lanes(bank_embedding_lanes),
.bank_embedding_lane_valid(bank_embedding_lane_valid),
.acquire_valid(acquire_valid),
.acquire_transaction_id(acquire_transaction_id),
.acquire_used_bank_mask(acquire_used_bank_mask),
.acquire_bank_ids(acquire_bank_ids),
.acquire_roles(acquire_roles),
.acquire_generations(acquire_generations),
.acquire_ready(acquire_ready),
.acquire_error_code(acquire_error_code),
.release_valid(release_valid),
.release_transaction_id(release_transaction_id),
.release_used_bank_mask(release_used_bank_mask),
.release_bank_ids(release_bank_ids),
.release_roles(release_roles),
.release_generations(release_generations),
.release_ready(release_ready),
.release_error_code(release_error_code),
.cfg_valid(cfg_valid),
.cfg_transaction_id(cfg_transaction_id),
.cfg_bank(cfg_bank),
.cfg_profile(cfg_profile),
.cfg_rows(cfg_rows),
.cfg_cols(cfg_cols),
.cfg_position(cfg_position),
.cfg_layer(cfg_layer),
.cfg_component(cfg_component),
.cfg_generation(cfg_generation),
.cfg_resp_ready(cfg_resp_ready),
.cfg_ready(cfg_ready),
.cfg_resp_valid(cfg_resp_valid),
.cfg_resp_transaction_id(cfg_resp_transaction_id),
.cfg_resp_error_code(cfg_resp_error_code));
initial begin
clk=0;
resetn=0;
start=0;
cmd_doutb=0;
engine_cmd_ready=0;
engine_resp_valid=0;
engine_resp_transaction_id=0;
engine_resp_used_bank_mask=0;
engine_resp_used_bank_count=0;
engine_resp_bank_ids=0;
engine_resp_generations=0;
engine_resp_error_code=0;
bank_busy=0;
bank_owner_port=0;
bank_desc_present=0;
bank_profiles=0;
bank_rows=0;
bank_cols=0;
bank_positions=0;
bank_layers=0;
bank_generations=0;
bank_data_valid=0;
bank_scale_valid=0;
bank_b7_static_valid=0;
bank_b7_rope_valid=0;
bank_embedding_lanes=0;
bank_embedding_lane_valid=0;
acquire_ready=0;
acquire_error_code=0;
release_ready=0;
release_error_code=0;
cfg_ready=0;
cfg_resp_valid=0;
cfg_resp_transaction_id=0;
cfg_resp_error_code=0;
$readmemh("audit_decode.hex",vectors);
for(int i=0;i<2957;i++)begin
 record=vectors[i][127:0];force dut.record_r=record;#1;
 if((dut.static_error_w==0)!==vectors[i][128])$fatal(1,"static mismatch index%0d record%032h expected%0b error%0h",i,record,vectors[i][128],dut.static_error_w);
 release dut.record_r;checked++;
end
$display("AUDIT_STATIC_DECODE_PASS checked=%0d",checked);$finish;
end
endmodule
