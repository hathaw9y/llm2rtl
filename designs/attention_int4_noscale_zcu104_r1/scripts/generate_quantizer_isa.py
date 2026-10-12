#!/usr/bin/env python3
"""Generate design-local native bank and controller copies for ISA opcode 3.

Shared infrastructure and the verified arithmetic child are never rewritten.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys

DESIGN = Path(__file__).resolve().parents[1]
ROOT = DESIGN.parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from infrastructure_sources import resolve_reference


def region(text, name, body):
    pattern = re.compile(rf'(^[ \t]*// USER_{name}_BEGIN[^\n]*\n).*?(^[ \t]*// USER_{name}_END[^\n]*$)', re.M | re.S)
    changed, count = pattern.subn(lambda m: m.group(1)+body+m.group(2), text)
    if count != 1:
        raise RuntimeError(f'expected one USER_{name} region, found {count}')
    return changed


CONTROLLER = {
    'PORTS': '''    , output logic m_ctrl_quant_cmd_valid
    , input logic m_ctrl_quant_cmd_ready
    , output logic [BANK_NUM_WIDTH-1:0] m_ctrl_quant_cmd_src_bank, m_ctrl_quant_cmd_dst_bank, m_ctrl_quant_cmd_scale_bank
    , output logic [8:0] m_ctrl_quant_cmd_elements
    , input logic s_ctrl_quant_resp_valid
    , output logic m_ctrl_quant_resp_ready
    , input logic [BANK_NUM_WIDTH-1:0] s_ctrl_quant_resp_src_bank, s_ctrl_quant_resp_dst_bank, s_ctrl_quant_resp_scale_bank
    , input logic s_ctrl_quant_resp_error
''',
    'PARAMETERS': '''    // This design's QUANTIZE count is bounded by the verified child.
    localparam int QUANT_MAX_ELEMENTS = 256;
''',
    'OPCODES': '''    localparam logic [OPCODE_WIDTH-1:0] OP_QUANTIZE = OPCODE_WIDTH'(3);
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_QUANT_SRC = PORT_ROLE_WIDTH'(3);
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_QUANT_DATA_DST = PORT_ROLE_WIDTH'(4);
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_QUANT_SCALE_DST = PORT_ROLE_WIDTH'(5);
''',
    'DECLARATIONS': '''    logic quant_pending_r, quant_issued_r, quant_completed_r;
    logic [BANK_NUM_WIDTH-1:0] quant_src_r, quant_dst_r, quant_scale_bank_r;
    logic quant_response_match_w, quant_response_fire_w, quant_owner_fault_w;
    if (AXI_ADDRESS_LSB > 0) begin : g_reserved_command_bits
        logic [AXI_ADDRESS_LSB-1:0] unused_reserved_bits;
        assign unused_reserved_bits = command_r[AXI_ADDRESS_LSB-1:0];
    end
''',
    'DECODE': '''    always_comb begin
        user_opcode_known_w = opcode_w == OP_QUANTIZE;
        user_command_legal_w = user_opcode_known_w &&
            {1'b0,operand0_bank_w} < BANK_NUM_LIMIT &&
            {1'b0,operand1_bank_w} < BANK_NUM_LIMIT &&
            {1'b0,operand2_bank_w} < BANK_NUM_LIMIT &&
            operand0_bank_w != operand1_bank_w && operand0_bank_w != operand2_bank_w && operand1_bank_w != operand2_bank_w &&
            byte_count_w != '0 && byte_count_w <= BTT_WIDTH'(QUANT_MAX_ELEMENTS) &&
            local_offset_w == '0 && axi_address_w == '0;
        user_bank_eligible_w = 1'b0;
        user_bank_wr_acquire_valid_w = '0; user_bank_rd_acquire_valid_w = '0;
        user_bank_wr_acquire_port_w = '0; user_bank_rd_acquire_port_w = '0;
        if (user_command_legal_w) begin
            user_bank_rd_acquire_valid_w[operand0_bank_w] = 1'b1;
            user_bank_wr_acquire_valid_w[operand1_bank_w] = 1'b1;
            user_bank_wr_acquire_valid_w[operand2_bank_w] = 1'b1;
            user_bank_rd_acquire_port_w[operand0_bank_w] = PORT_QUANT_SRC;
            user_bank_wr_acquire_port_w[operand1_bank_w] = PORT_QUANT_DATA_DST;
            user_bank_wr_acquire_port_w[operand2_bank_w] = PORT_QUANT_SCALE_DST;
            user_bank_eligible_w = !quant_pending_r &&
                !bank_wr_busy[operand0_bank_w] && !bank_rd_busy[operand0_bank_w] &&
                !bank_wr_busy[operand1_bank_w] && !bank_rd_busy[operand1_bank_w] &&
                !bank_wr_busy[operand2_bank_w] && !bank_rd_busy[operand2_bank_w];
        end
    end
''',
    'ISSUE': '''    always_comb begin
        m_ctrl_quant_cmd_valid = aresetn && state_r == EXECUTE && opcode_w == OP_QUANTIZE;
        m_ctrl_quant_cmd_src_bank = operand0_bank_w;
        m_ctrl_quant_cmd_dst_bank = operand1_bank_w;
        m_ctrl_quant_cmd_scale_bank = operand2_bank_w;
        m_ctrl_quant_cmd_elements = 9'(byte_count_w);
        user_request_valid_w = m_ctrl_quant_cmd_valid;
        user_request_ready_w = m_ctrl_quant_cmd_ready;
    end
''',
    'COMPLETION': '''    // Executor response certifies all native read responses consumed and both
    // final destination writes accepted. No bank request follows completion.
    always_comb begin
        m_ctrl_quant_resp_ready = aresetn && cmd_dispatcher_busy;
        quant_response_fire_w = s_ctrl_quant_resp_valid && m_ctrl_quant_resp_ready;
        quant_owner_fault_w = quant_pending_r &&
            (!bank_rd_busy[quant_src_r] || bank_rd_owner_port[quant_src_r] != PORT_QUANT_SRC ||
             !bank_wr_busy[quant_dst_r] || bank_wr_owner_port[quant_dst_r] != PORT_QUANT_DATA_DST ||
             !bank_wr_busy[quant_scale_bank_r] || bank_wr_owner_port[quant_scale_bank_r] != PORT_QUANT_SCALE_DST);
        quant_response_match_w = quant_pending_r && !quant_completed_r && !quant_owner_fault_w &&
            (quant_issued_r || user_request_fire_w) &&
            s_ctrl_quant_resp_src_bank == quant_src_r && s_ctrl_quant_resp_dst_bank == quant_dst_r &&
            s_ctrl_quant_resp_scale_bank == quant_scale_bank_r;
        user_pending_any_w = quant_pending_r;
        user_bank_wr_release_valid_w = '0; user_bank_rd_release_valid_w = '0;
        user_bank_wr_release_port_w = '0; user_bank_rd_release_port_w = '0;
        if (quant_pending_r && quant_completed_r && !quant_owner_fault_w) begin
            user_bank_rd_release_valid_w[quant_src_r] = 1'b1;
            user_bank_wr_release_valid_w[quant_dst_r] = 1'b1;
            user_bank_wr_release_valid_w[quant_scale_bank_r] = 1'b1;
            user_bank_rd_release_port_w[quant_src_r] = PORT_QUANT_SRC;
            user_bank_wr_release_port_w[quant_dst_r] = PORT_QUANT_DATA_DST;
            user_bank_wr_release_port_w[quant_scale_bank_r] = PORT_QUANT_SCALE_DST;
        end
        user_response_fault_w = quant_owner_fault_w || (quant_response_fire_w && !quant_response_match_w);
        user_executor_fault_w = quant_response_fire_w && quant_response_match_w && s_ctrl_quant_resp_error;
    end
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            quant_pending_r <= 1'b0; quant_issued_r <= 1'b0; quant_completed_r <= 1'b0;
            quant_src_r <= '0; quant_dst_r <= '0; quant_scale_bank_r <= '0;
        end else begin
            if (user_acquire_fire_w) begin
                quant_pending_r <= 1'b1;
                quant_src_r <= operand0_bank_w; quant_dst_r <= operand1_bank_w; quant_scale_bank_r <= operand2_bank_w;
            end
            if (user_request_fire_w) quant_issued_r <= 1'b1;
            if (quant_response_fire_w && quant_response_match_w) quant_completed_r <= 1'b1;
            if (quant_pending_r && bank_rd_release_valid[quant_src_r] && bank_wr_release_valid[quant_dst_r] &&
                bank_wr_release_valid[quant_scale_bank_r] && bank_rd_release_accepted[quant_src_r] &&
                bank_wr_release_accepted[quant_dst_r] && bank_wr_release_accepted[quant_scale_bank_r]) begin
                quant_pending_r <= 1'b0; quant_issued_r <= 1'b0; quant_completed_r <= 1'b0;
            end
        end
    end
'''
}

BANK_PORTS = '''    input logic quant_src_bank_enb [0:2],
    input logic [31:0] quant_src_bank_addrb [0:2],
    output logic quant_src_bank_read_ready [0:2],
    output logic quant_src_bank_valid [0:2],
    output logic [127:0] quant_src_bank_doutb [0:2],
    input logic quant_data_bank_ena [0:2],
    input logic [31:0] quant_data_bank_addra [0:2],
    input logic [127:0] quant_data_bank_dina [0:2],
    input logic [15:0] quant_data_bank_wea [0:2],
    output logic quant_data_bank_ready [0:2],
    input logic quant_scale_bank_ena [0:2],
    input logic [31:0] quant_scale_bank_addra [0:2],
    input logic [127:0] quant_scale_bank_dina [0:2],
    input logic [15:0] quant_scale_bank_wea [0:2],
    output logic quant_scale_bank_ready [0:2],
'''
BANK_ROUTING = '''    for (int b=0; b<BANK_NUM; b++) begin
      // Select by ownership independently of native enable/ready, avoiding a
      // ready-to-enable mux loop. Captured response roles select return valid.
      if (bank_rd_owner_port[b] == OWNER_QUANT_SRC) begin
        rd_req_valid[b] = quant_src_bank_enb[b]; rd_req_owner[b] = OWNER_QUANT_SRC;
        rd_req_addr[b] = quant_src_bank_addrb[b];
      end
      if (bank_wr_owner_port[b] == OWNER_QUANT_DATA_DST) begin
        wr_req_valid[b] = quant_data_bank_ena[b]; wr_req_owner[b] = OWNER_QUANT_DATA_DST;
        wr_req_addr[b] = quant_data_bank_addra[b]; wr_req_data[b] = quant_data_bank_dina[b]; wr_req_strb[b] = quant_data_bank_wea[b];
      end else if (bank_wr_owner_port[b] == OWNER_QUANT_SCALE_DST) begin
        wr_req_valid[b] = quant_scale_bank_ena[b]; wr_req_owner[b] = OWNER_QUANT_SCALE_DST;
        wr_req_addr[b] = quant_scale_bank_addra[b]; wr_req_data[b] = quant_scale_bank_dina[b]; wr_req_strb[b] = quant_scale_bank_wea[b];
      end
      // A DMA request conflicting with the selected compute owner is rejected
      // explicitly, never silently discarded or allowed to alter the bank.
      if (mm2s_bank_ena[b] && bank_wr_owner_port[b] != OWNER_MM2S) begin wr_req_valid[b]=1'b1; wr_req_owner[b]='0; end
      if (s2mm_bank_enb[b] && bank_rd_owner_port[b] != OWNER_S2MM) begin rd_req_valid[b]=1'b1; rd_req_owner[b]='0; end
    end
'''
BANK_OUTPUTS = '''  for (genvar b=0; b<BANK_NUM; b++) begin : g_quant_outputs
    assign quant_src_bank_read_ready[b] = rd_req_ready[b] && rd_req_owner[b] == OWNER_QUANT_SRC;
    assign quant_src_bank_valid[b] = rd_rsp_valid[b] && rd_rsp_owner[b] == OWNER_QUANT_SRC;
    assign quant_src_bank_doutb[b] = rd_rsp_data[b];
    assign quant_data_bank_ready[b] = wr_req_ready[b] && wr_req_owner[b] == OWNER_QUANT_DATA_DST;
    assign quant_scale_bank_ready[b] = wr_req_ready[b] && wr_req_owner[b] == OWNER_QUANT_SCALE_DST;
  end
'''


def generate_controller():
    source = (ROOT/'ip/infrastructure/controller/cmd_dispatcher_template.sv').read_text()
    result = source
    for name, body in CONTROLLER.items(): result = region(result, name, body)
    base, extended = source, result
    for name in CONTROLLER:
        base = region(base, name, '')
        extended = region(extended, name, '')
    if base != extended: raise RuntimeError('controller changed outside USER bodies')
    # The pinned generation addendum authorizes these guarded array-index casts
    # in the local copy. Full-width tag comparisons and external tags stay intact.
    for engine in ('mm2s','s2mm'):
        token = f'[s_ctrl_{engine}_sts_tag]'
        if result.count(token) != 6: raise RuntimeError(f'unexpected {engine} tag-index transform count')
        result = result.replace(token, f"[BANK_NUM_WIDTH'(s_ctrl_{engine}_sts_tag)]")
    return result.replace('module cmd_dispatcher_template #(', 'module attention_quantizer_controller #(')


def generate_package():
    result = (ROOT/'ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/bank_subsystem_template/rtl/bank_config_pkg.sv.tpl').read_text()
    changes = {
        '{{PACKAGE_NAME}}':'attention_quantizer_bank_config_pkg',
        '  localparam int BANK_NUM = 2;':'  localparam int BANK_NUM = 3;',
        "MEMORY_TYPES [0:BANK_NUM-1] = '{1,2}":"MEMORY_TYPES [0:BANK_NUM-1] = '{1,1,1}",
        "WRITE_WIDTHS [0:BANK_NUM-1] = '{128,128}":"WRITE_WIDTHS [0:BANK_NUM-1] = '{128,128,128}",
        "READ_WIDTHS [0:BANK_NUM-1] = '{128,128}":"READ_WIDTHS [0:BANK_NUM-1] = '{128,128,128}",
        "WRITE_DEPTHS [0:BANK_NUM-1] = '{64,4096}":"WRITE_DEPTHS [0:BANK_NUM-1] = '{256,256,256}",
        'MM2S_BANK_NUM = 2':'MM2S_BANK_NUM = 3', 'S2MM_BANK_NUM = 2':'S2MM_BANK_NUM = 3',
        "= '{0,1}":"= '{0,1,2}",
        "WR_CAPABILITIES = '{8'h02,8'h02}":"WR_CAPABILITIES = '{8'h32,8'h32,8'h32}",
        "RD_CAPABILITIES = '{8'h04,8'h04}":"RD_CAPABILITIES = '{8'h0c,8'h0c,8'h0c}",
    }
    for old,new in changes.items():
        if old not in result: raise RuntimeError(f'missing bank configuration token {old}')
        result=result.replace(old,new)
    return region(result,'CONFIG', '''  localparam logic [ROLE_WIDTH-1:0] OWNER_QUANT_SRC = 3'd3;
  localparam logic [ROLE_WIDTH-1:0] OWNER_QUANT_DATA_DST = 3'd4;
  localparam logic [ROLE_WIDTH-1:0] OWNER_QUANT_SCALE_DST = 3'd5;
''')


def generate_banks():
    result = (ROOT/'ip/infrastructure/archive/pre_physical_20261012/snapshot/ip/infrastructure/bank_subsystem_template/rtl/bank_subsystem.sv.tpl').read_text()
    for name,body in [('PORTS',BANK_PORTS),('ROUTING',BANK_ROUTING),('OUTPUTS',BANK_OUTPUTS)]:
        result=region(result,name,body)
    return result.replace('{{MODULE_NAME}}','attention_quantizer_bank_subsystem').replace('{{PACKAGE_NAME}}','attention_quantizer_bank_config_pkg')


def generate_top():
    controller = (ROOT/'ip/infrastructure/controller/cmd_dispatcher_template.sv').read_text()
    public = controller[controller.index('    input  logic aclk,'):controller.index('    output logic [BANK_NUM-1:0] bank_wr_acquire_valid')]
    for old,new in [('AXI_ADDR_WIDTH','32'),('BTT_WIDTH','23'),('BANK_NUM_WIDTH','2'),('TAG_WIDTH','4'),('BANK_ADDR_WIDTH','32'),('CMD_DATA_WIDTH','128')]:
        public=public.replace(old,new)
    top = '''`timescale 1ns/1ps
module attention_quantizer_isa_top #(
    parameter int CMD_ADDR_WIDTH = 10,
    parameter int CMD_READ_LATENCY = 2,
    parameter int MAX_COMMANDS = 1024
) (
'''+public+'''    input logic mm2s_bank_ena [0:2],
    input logic [31:0] mm2s_bank_addra [0:2],
    input logic [127:0] mm2s_bank_dina [0:2],
    input logic [15:0] mm2s_bank_wea [0:2],
    output logic mm2s_bank_ready [0:2],
    input logic s2mm_bank_enb [0:2],
    input logic [31:0] s2mm_bank_addrb [0:2],
    output logic [127:0] s2mm_bank_doutb [0:2],
    output logic s2mm_bank_read_ready [0:2],
    output logic s2mm_bank_valid [0:2],
    output logic bank_subsystem_error,
    output logic [2:0] bank_subsystem_error_code
);
  logic [2:0] bank_wr_acquire_valid, bank_rd_acquire_valid, bank_wr_release_valid, bank_rd_release_valid;
  logic [2:0][2:0] bank_wr_acquire_port, bank_rd_acquire_port, bank_wr_release_port, bank_rd_release_port;
  logic [2:0] bank_wr_busy, bank_rd_busy;
  logic [2:0][2:0] bank_wr_owner_port, bank_rd_owner_port;
  logic [2:0] bank_wr_acquire_accepted, bank_rd_acquire_accepted, bank_wr_release_accepted, bank_rd_release_accepted;
  logic [2:0][32:0] unused_bank_committed_prefix;
  logic unused_ownership_error, unused_router_error;
  logic [2:0] unused_ownership_error_code, unused_router_error_code;
  logic m_ctrl_quant_cmd_valid, m_ctrl_quant_cmd_ready;
  logic [1:0] m_ctrl_quant_cmd_src_bank, m_ctrl_quant_cmd_dst_bank, m_ctrl_quant_cmd_scale_bank;
  logic [8:0] m_ctrl_quant_cmd_elements;
  logic s_ctrl_quant_resp_valid, m_ctrl_quant_resp_ready, s_ctrl_quant_resp_error;
  logic [1:0] s_ctrl_quant_resp_src_bank, s_ctrl_quant_resp_dst_bank, s_ctrl_quant_resp_scale_bank;
  logic quant_src_bank_enb [0:2], quant_src_bank_read_ready [0:2], quant_src_bank_valid [0:2];
  logic [31:0] quant_src_bank_addrb [0:2];
  logic [127:0] quant_src_bank_doutb [0:2];
  logic quant_data_bank_ena [0:2], quant_data_bank_ready [0:2];
  logic [31:0] quant_data_bank_addra [0:2];
  logic [127:0] quant_data_bank_dina [0:2];
  logic [15:0] quant_data_bank_wea [0:2];
  logic quant_scale_bank_ena [0:2], quant_scale_bank_ready [0:2];
  logic [31:0] quant_scale_bank_addra [0:2];
  logic [127:0] quant_scale_bank_dina [0:2];
  logic [15:0] quant_scale_bank_wea [0:2];
'''
    program = ['aclk','aresetn','cmd_dispatcher_start','cmd_dispatcher_busy','cmd_dispatcher_done','cmd_dispatcher_error','cmd_dispatcher_error_code','current_pc','cmd_enb','cmd_addrb','cmd_doutb']
    dma = [f'{prefix}_ctrl_{engine}_{name}' for engine in ('mm2s','s2mm') for prefix,name in [
        ('m','cmd_valid'),('m','cmd_ready'),('m','cmd_addr'),('m','cmd_btt'),('m','cmd_offset'),('m','cmd_bank'),('m','cmd_tag'),
        ('s','sts_valid'),('m','sts_ready'),('s','sts_tag'),('s','sts_error')]]
    ownership = [f'bank_{d}_{n}' for d in ('wr','rd') for n in ('acquire_valid','acquire_port','release_valid','release_port','busy','owner_port','acquire_accepted','release_accepted')]
    quantctrl = ['m_ctrl_quant_cmd_'+n for n in ('valid','ready','src_bank','dst_bank','scale_bank','elements')]+['s_ctrl_quant_resp_'+n for n in ('valid','src_bank','dst_bank','scale_bank','error')]+['m_ctrl_quant_resp_ready']
    connect = lambda names: ',\n      '.join('.'+n+'('+n+')' for n in names)
    top += '''  attention_quantizer_controller #(.BANK_NUM(3), .BANK_NUM_WIDTH(2), .TAG_WIDTH(4),
      .CMD_ADDR_WIDTH(CMD_ADDR_WIDTH), .CMD_READ_LATENCY(CMD_READ_LATENCY), .MAX_COMMANDS(MAX_COMMANDS)) u_controller (
      '''+connect(program+dma+ownership+['bank_subsystem_error']+quantctrl)+''');
'''
    banknative = ['mm2s_bank_'+n for n in ('ena','addra','dina','wea','ready')]+['s2mm_bank_'+n for n in ('enb','addrb','doutb','read_ready','valid')]
    quantnative = ['quant_src_bank_'+n for n in ('enb','addrb','read_ready','valid','doutb')]+['quant_'+d+'_bank_'+n for d in ('data','scale') for n in ('ena','addra','dina','wea','ready')]
    top += '  attention_quantizer_bank_subsystem u_banks (\n      '+connect(['aclk','aresetn']+ownership+banknative+quantnative+['bank_subsystem_error','bank_subsystem_error_code'])+''',
      .bank_committed_prefix(unused_bank_committed_prefix), .ownership_error(unused_ownership_error),
      .router_error(unused_router_error), .ownership_error_code(unused_ownership_error_code), .router_error_code(unused_router_error_code));
'''
    mappings = {'cmd_valid':'m_ctrl_quant_cmd_valid','cmd_ready':'m_ctrl_quant_cmd_ready','cmd_src_bank':'m_ctrl_quant_cmd_src_bank','cmd_dst_bank':'m_ctrl_quant_cmd_dst_bank','cmd_scale_bank':'m_ctrl_quant_cmd_scale_bank','cmd_elements':'m_ctrl_quant_cmd_elements','resp_valid':'s_ctrl_quant_resp_valid','resp_ready':'m_ctrl_quant_resp_ready','resp_src_bank':'s_ctrl_quant_resp_src_bank','resp_dst_bank':'s_ctrl_quant_resp_dst_bank','resp_scale_bank':'s_ctrl_quant_resp_scale_bank','resp_error':'s_ctrl_quant_resp_error'}
    top += '  attention_quantizer_executor u_executor (\n      '+connect(['aclk','aresetn']+quantnative)+',\n      '+',\n      '.join('.'+p+'('+v+')' for p,v in mappings.items())+');\nendmodule\n'
    return top


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output-dir',type=Path,default=DESIGN/'rtl')
    args=parser.parse_args()
    packet_path=DESIGN/'modules/attention_quantizer_isa.json'
    if hashlib.sha256(packet_path.read_bytes()).hexdigest() != 'cb0734d094aaa449f4f1cdcee01ac0f3cc43aac427bc1aab0288d7850d027a47':
        raise RuntimeError('frozen integration packet mismatch')
    addendum=DESIGN/'modules/attention_quantizer_isa_generation_addendum.json'
    if hashlib.sha256(addendum.read_bytes()).hexdigest() != 'ab828c7a28def8494661c4f17378a20d265028160dd0626989a22132cc1b6de1':
        raise RuntimeError('generated tag-index adaptation addendum mismatch')
    packet=json.loads(packet_path.read_text())
    for key in ('child','child_contract','child_independent_review','native_contract','controller_contract','controller_index'):
        p=packet[key]
        if hashlib.sha256(resolve_reference(p['path'],root=ROOT,expected_sha256=p['sha256']).read_bytes()).hexdigest()!=p['sha256']:
            raise RuntimeError(f'pin mismatch: {key}')
    for path,expected in packet['common_contracts'].items():
        if hashlib.sha256(resolve_reference(path,root=ROOT,expected_sha256=expected).read_bytes()).hexdigest()!=expected: raise RuntimeError(f'pin mismatch {path}')
    args.output_dir.mkdir(parents=True,exist_ok=True)
    for filename,text in [('attention_quantizer_controller.sv',generate_controller()),('attention_quantizer_bank_config_pkg.sv',generate_package()),('attention_quantizer_bank_subsystem.sv',generate_banks()),('attention_quantizer_isa_top.sv',generate_top())]:
        (args.output_dir/filename).write_text(text)
    controller_input=ROOT/'ip/infrastructure/controller/cmd_dispatcher_template.sv'
    controller_output=args.output_dir/'attention_quantizer_controller.sv'
    evidence={
        'packet_sha256':hashlib.sha256(packet_path.read_bytes()).hexdigest(),
        'addendum_sha256':hashlib.sha256(addendum.read_bytes()).hexdigest(),
        'controller_input_sha256':hashlib.sha256(controller_input.read_bytes()).hexdigest(),
        'controller_output_sha256':hashlib.sha256(controller_output.read_bytes()).hexdigest(),
        'tag_index_transform_counts':{'mm2s':6,'s2mm':6},
        'generated_source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(args.output_dir.glob('attention_quantizer_*.sv'))},
    }
    print(json.dumps(evidence,sort_keys=True))
    print('PASS: generated ISA quantizer controller/native bank copies from pinned inputs')

if __name__=='__main__': main()
