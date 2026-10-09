#!/usr/bin/env python3
"""Fill the approved SmolLM2 dispatcher extension points of the common template."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
DESIGN = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ip/infrastructure/cmd_dispatcher_template/rtl/cmd_dispatcher_template.sv"
OUTPUT = DESIGN / "rtl/isa_command_dispatcher.sv"

BODIES = {
"PORTS": """    ,
    input  logic [BANK_NUM-1:0] bank_tensor_valid,
    input  logic bank_tensor_state_error,
    output logic [BANK_NUM-1:0] wr_issue_valid,
    output logic [BANK_NUM-1:0][1:0] wr_issue_kind,
    output logic [BANK_NUM-1:0][15:0] wr_issue_index,
    output logic [BANK_NUM-1:0][15:0] wr_issue_count,
    output logic [BANK_NUM-1:0][15:0] wr_issue_total,
    output logic [BANK_NUM-1:0] wr_complete_valid,
    output logic [BANK_NUM-1:0] wr_complete_error,
    output logic [6:0] compute_cmd_valid,
    input  logic [6:0] compute_cmd_ready,
    output logic [6:0][OPCODE_WIDTH-1:0] compute_cmd_opcode,
    output logic [6:0][2:0][BANK_NUM_WIDTH-1:0] compute_cmd_bank,
    output logic [6:0][111:0] compute_cmd_payload,
    input  logic [6:0] compute_done_valid,
    output logic [6:0] compute_done_ready,
    input  logic [6:0][BANK_NUM_WIDTH-1:0] compute_done_tag,
    input  logic [6:0][1:0] compute_done_bank_count,
    input  logic [6:0][2:0][BANK_NUM_WIDTH-1:0] compute_done_bank,
    input  logic [6:0] compute_done_error
""",
"PARAMETERS": """    // Seven physical compute channels, one in-flight command per channel.
""",
"OPCODES": """    localparam logic [OPCODE_WIDTH-1:0] OP_GEMM = 3, OP_RMS = 4,
        OP_ROPE = 5, OP_SCORE = 6, OP_SOFTMAX = 7, OP_VALUE = 8,
        OP_ADD = 9, OP_SILU = 10, OP_FENCE = 11;
""",
"DECLARATIONS": """    localparam integer USER_MARKER_COUNT = 14;
    localparam logic [1:0] WRITE_FULL = 0, WRITE_PART = 1, WRITE_INPLACE = 2;
    logic [6:0] compute_pending_r;
    logic [6:0][2:0][BANK_NUM_WIDTH-1:0] pending_bank_r;
    logic [6:0][2:0][PORT_ROLE_WIDTH-1:0] pending_role_r;
    logic [6:0][1:0] pending_bank_count_r;
    logic [6:0][BANK_NUM_WIDTH-1:0] pending_dst_r;
    logic [6:0] completion_match_w;
    logic [6:0] compute_fire_w;
    logic [2:0] selected_channel_w;
    logic is_compute_w, is_fence_w, source_invalid_w, dma_load_invalid_w;
    logic [1:0] used_bank_count_w;
    logic [BANK_NUM_WIDTH-1:0] write_bank_w;
    logic [1:0] write_kind_w;
    logic [15:0] write_index_w, write_count_w, write_total_w;
    logic [15:0] gemm_n_start_w, gemm_n_total_w;
    logic [7:0] gemm_n_tile_w;
    logic [5:0] gemm_m_start_w, gemm_m_count_w;
    logic [10:0] gemm_k_w;
    logic [9:0] score_q_start_w;
    logic [5:0] score_m_count_w;
    logic [10:0] score_kv_len_w;
    logic [5:0] embedding_row_w, embedding_rows_w;
    logic [BANK_NUM_WIDTH:0] bank1_index_w, bank2_index_w;
    logic all_banks_free_w;

    function automatic logic [PORT_ROLE_WIDTH-1:0] role_for(
        input logic [OPCODE_WIDTH-1:0] op, input integer position);
        case (op)
            OP_GEMM: role_for = PORT_ROLE_WIDTH'(3 + position);
            OP_RMS: role_for = PORT_ROLE_WIDTH'(6 + position);
            OP_ROPE: role_for = PORT_ROLE_WIDTH'(9 + position);
            OP_SCORE: role_for = PORT_ROLE_WIDTH'(11 + position);
            OP_SOFTMAX: role_for = PORT_ROLE_WIDTH'(14);
            OP_VALUE: role_for = PORT_ROLE_WIDTH'(15 + position);
            OP_ADD, OP_SILU: role_for = PORT_ROLE_WIDTH'(18 + position);
            default: role_for = '0;
        endcase
    endfunction

    function automatic logic bank_allowed(input int role, input logic [3:0] bank);
        case (role)
            1: bank_allowed = (bank == 0 || bank == 3 || bank == 7 ||
                               bank == 8 || bank == 9);
            2: bank_allowed = (bank == 5 || bank == 6 || bank == 12);
            3: bank_allowed = (bank == 2 || bank == 10 || bank == 11);
            4: bank_allowed = (bank == 3);
            5: bank_allowed = (bank == 1 || bank == 4 || bank == 5 ||
                               bank == 6 || bank == 8 || bank == 9 || bank == 12);
            6: bank_allowed = (bank == 0 || bank == 5);
            7: bank_allowed = (bank == 3);
            8: bank_allowed = (bank == 2);
            9: bank_allowed = (bank == 4 || bank == 5 || bank == 8);
            10: bank_allowed = (bank == 7);
            11: bank_allowed = (bank == 4);
            12: bank_allowed = (bank == 8);
            13: bank_allowed = (bank == 10);
            14: bank_allowed = (bank == 10);
            15: bank_allowed = (bank == 10);
            16: bank_allowed = (bank == 9);
            17: bank_allowed = (bank == 11);
            18: bank_allowed = (bank == 0 || bank == 5 || bank == 8);
            19: bank_allowed = (bank == 1 || bank == 9);
            20: bank_allowed = (bank == 0 || bank == 5 || bank == 10);
            default: bank_allowed = 1'b0;
        endcase
    endfunction
""",
"DECODE": """    always_comb begin
        is_compute_w = (opcode_w >= OP_GEMM) && (opcode_w <= OP_SILU);
        is_fence_w = (opcode_w == OP_FENCE);
        selected_channel_w = 3'd0;
        case (opcode_w)
            OP_GEMM: selected_channel_w = 3'd0;
            OP_RMS: selected_channel_w = 3'd1;
            OP_ROPE: selected_channel_w = 3'd2;
            OP_SCORE: selected_channel_w = 3'd3;
            OP_SOFTMAX: selected_channel_w = 3'd4;
            OP_VALUE: selected_channel_w = 3'd5;
            OP_ADD, OP_SILU: selected_channel_w = 3'd6;
            default: selected_channel_w = 3'd0;
        endcase
        used_bank_count_w = 2'd3;
        if (opcode_w == OP_ROPE) used_bank_count_w = 2'd2;
        if (opcode_w == OP_SOFTMAX) used_bank_count_w = 2'd1;
        bank1_index_w = {1'b0, operand1_bank_w};
        bank2_index_w = {1'b0, operand2_bank_w};
        gemm_n_start_w = command_r[62:47];
        gemm_n_total_w = command_r[46:31];
        gemm_m_start_w = command_r[30:25];
        gemm_m_count_w = command_r[24:19];
        gemm_k_w = command_r[18:8];
        gemm_n_tile_w = command_r[7:0];
        score_q_start_w = command_r[26:17];
        score_m_count_w = command_r[16:11];
        score_kv_len_w = command_r[10:0];
        embedding_rows_w = command_r[11:6];
        embedding_row_w = command_r[5:0];

        user_opcode_known_w = is_compute_w || is_fence_w;
        user_command_legal_w = 1'b0;
        if (is_fence_w) begin
            user_command_legal_w = (command_r[123:0] == '0);
        end else if (is_compute_w) begin
            user_command_legal_w = bank_in_range_w &&
                ((used_bank_count_w < 2) || (bank1_index_w < BANK_NUM_LIMIT)) &&
                ((used_bank_count_w < 3) || (bank2_index_w < BANK_NUM_LIMIT)) &&
                ((used_bank_count_w < 2) || (operand0_bank_w != operand1_bank_w)) &&
                ((used_bank_count_w < 3) ||
                 ((operand0_bank_w != operand2_bank_w) &&
                  (operand1_bank_w != operand2_bank_w))) &&
                ((used_bank_count_w != 1) ||
                 ((operand1_bank_w == '0) && (operand2_bank_w == '0))) &&
                ((used_bank_count_w != 2) || (operand2_bank_w == '0));
            user_command_legal_w = user_command_legal_w &&
                bank_allowed(int'(role_for(opcode_w, 0)), operand0_bank_w) &&
                ((used_bank_count_w < 2) ||
                 bank_allowed(int'(role_for(opcode_w, 1)), operand1_bank_w)) &&
                ((used_bank_count_w < 3) ||
                 bank_allowed(int'(role_for(opcode_w, 2)), operand2_bank_w));
            if (opcode_w == OP_GEMM) begin
                user_command_legal_w = user_command_legal_w &&
                    (command_r[111:63] == '0) &&
                    (gemm_n_total_w != 0) && (gemm_n_total_w <= 16'd49152) &&
                    (gemm_n_tile_w != 0) && (gemm_n_tile_w <= 8'd192) &&
                    ({1'b0, gemm_n_start_w} + {9'b0, gemm_n_tile_w} <=
                     {1'b0, gemm_n_total_w}) &&
                    (gemm_m_count_w != 0) && (gemm_m_count_w <= 6'd32) &&
                    ({1'b0, gemm_m_start_w} + {1'b0, gemm_m_count_w} <= 7'd32) &&
                    (gemm_k_w != 0);
            end else if (opcode_w == OP_RMS || opcode_w == OP_ROPE ||
                         opcode_w == OP_ADD || opcode_w == OP_SILU) begin
                user_command_legal_w = user_command_legal_w &&
                    (command_r[111:6] == '0) &&
                    ((command_r[5:0] != 0) ||
                     (opcode_w == OP_RMS && ALLOW_ZERO_RMS_PROBE)) &&
                    (command_r[5:0] <= 6'd32);
            end else if (opcode_w == OP_SCORE || opcode_w == OP_SOFTMAX ||
                         opcode_w == OP_VALUE) begin
                user_command_legal_w = user_command_legal_w &&
                    (command_r[111:27] == '0) &&
                    (score_m_count_w != 0) && (score_m_count_w <= 6'd32) &&
                    (score_kv_len_w != 0) && (score_kv_len_w <= 11'd1024) &&
                    ({1'b0, score_q_start_w} + {5'b0, score_m_count_w} <=
                     score_kv_len_w);
            end else begin
                user_command_legal_w = user_command_legal_w &&
                    (command_r[111:0] == '0);
            end
        end

        all_banks_free_w = !(|(pending_mm2s_r | pending_s2mm_r)) &&
            !(|compute_pending_r) && !(|bank_busy);
        user_bank_eligible_w = 1'b0;
        if (is_fence_w && user_command_legal_w) begin
            user_bank_eligible_w = all_banks_free_w;
        end else if (is_compute_w && user_command_legal_w) begin
            user_bank_eligible_w = !compute_pending_r[selected_channel_w] &&
                !bank_busy[operand0_bank_w] &&
                ((used_bank_count_w < 2) || !bank_busy[operand1_bank_w]) &&
                ((used_bank_count_w < 3) || !bank_busy[operand2_bank_w]);
        end

        source_invalid_w = 1'b0;
        if (is_compute_w && user_command_legal_w) begin
            source_invalid_w = !bank_tensor_valid[operand0_bank_w] ||
                ((used_bank_count_w >= 2) &&
                 !bank_tensor_valid[operand1_bank_w]);
        end
        dma_load_invalid_w = 1'b0;
        if (opcode_w == OP_MM2S && command_r[24:0] != '0) begin
            dma_load_invalid_w = (command_r[24:12] != '0) ||
                (embedding_rows_w == 0) || (embedding_rows_w > 6'd32) ||
                (embedding_row_w >= embedding_rows_w) ||
                (byte_count_w != BTT_WIDTH'(1152)) ||
                (local_offset_w !=
                 (BANK_ADDR_WIDTH'(embedding_row_w) << 10) +
                 (BANK_ADDR_WIDTH'(embedding_row_w) << 7));
        end

        write_bank_w = (opcode_w == OP_ROPE || opcode_w == OP_SOFTMAX) ?
            operand0_bank_w : operand2_bank_w;
        write_kind_w = WRITE_FULL;
        write_index_w = 16'd0;
        write_count_w = 16'd1;
        write_total_w = 16'd1;
        if (opcode_w == OP_GEMM) begin
            write_kind_w = WRITE_PART;
            write_index_w = gemm_n_start_w;
            write_count_w = {8'd0, gemm_n_tile_w};
            write_total_w = gemm_n_total_w;
        end else if (opcode_w == OP_ROPE || opcode_w == OP_SOFTMAX) begin
            write_kind_w = WRITE_INPLACE;
            write_count_w = 16'd0;
            write_total_w = 16'd0;
        end
    end
""",
"ISSUE": """    always_comb begin
        compute_cmd_valid = '0;
        compute_cmd_opcode = '0;
        compute_cmd_bank = '0;
        compute_cmd_payload = '0;
        compute_fire_w = '0;
        user_request_valid_w = 1'b0;
        user_request_ready_w = 1'b0;
        user_request_fire_w = 1'b0;
        user_bank_acquire_valid_w = '0;
        user_bank_acquire_port_w = '0;
        if (aresetn && (state_r == ISSUE_COMMAND) && is_compute_w &&
            !fixed_response_fault_w && !fixed_executor_fault_w &&
            !user_response_fault_w && !user_executor_fault_w) begin
            compute_cmd_valid[selected_channel_w] = 1'b1;
            compute_cmd_opcode[selected_channel_w] = opcode_w;
            compute_cmd_bank[selected_channel_w][0] = operand0_bank_w;
            compute_cmd_bank[selected_channel_w][1] = operand1_bank_w;
            compute_cmd_bank[selected_channel_w][2] = operand2_bank_w;
            compute_cmd_payload[selected_channel_w] = command_r[111:0];
            user_request_valid_w = 1'b1;
            user_request_ready_w = compute_cmd_ready[selected_channel_w];
            compute_fire_w[selected_channel_w] =
                compute_cmd_ready[selected_channel_w];
            user_request_fire_w = compute_cmd_ready[selected_channel_w];
            if (user_request_fire_w) begin
                user_bank_acquire_valid_w[operand0_bank_w] = 1'b1;
                user_bank_acquire_port_w[operand0_bank_w] = role_for(opcode_w, 0);
                if (used_bank_count_w >= 2) begin
                    user_bank_acquire_valid_w[operand1_bank_w] = 1'b1;
                    user_bank_acquire_port_w[operand1_bank_w] = role_for(opcode_w, 1);
                end
                if (used_bank_count_w >= 3) begin
                    user_bank_acquire_valid_w[operand2_bank_w] = 1'b1;
                    user_bank_acquire_port_w[operand2_bank_w] = role_for(opcode_w, 2);
                end
            end
        end else if (aresetn && (state_r == ISSUE_COMMAND) && is_fence_w &&
                     !fixed_response_fault_w && !fixed_executor_fault_w &&
                     !user_response_fault_w && !user_executor_fault_w) begin
            user_request_valid_w = 1'b1;
            user_request_ready_w = all_banks_free_w;
            user_request_fire_w = all_banks_free_w;
        end
    end
""",
"COMPLETION": """    always_comb begin
        compute_done_ready = '0;
        completion_match_w = '0;
        user_pending_any_w = |compute_pending_r;
        user_bank_release_valid_w = '0;
        user_bank_release_port_w = '0;
        user_response_fault_w = 1'b0;
        user_executor_fault_w = bank_tensor_state_error;
        wr_issue_valid = '0;
        wr_issue_kind = '0;
        wr_issue_index = '0;
        wr_issue_count = '0;
        wr_issue_total = '0;
        wr_complete_valid = '0;
        wr_complete_error = '0;

        if (aresetn && fixed_request_fire_w && opcode_w == OP_MM2S) begin
            wr_issue_valid[operand0_bank_w] = 1'b1;
            if (command_r[24:0] != '0) begin
                wr_issue_kind[operand0_bank_w] = WRITE_PART;
                wr_issue_index[operand0_bank_w] = {10'd0, embedding_row_w};
                wr_issue_count[operand0_bank_w] = 16'd1;
                wr_issue_total[operand0_bank_w] = {10'd0, embedding_rows_w};
            end else begin
                wr_issue_kind[operand0_bank_w] = WRITE_FULL;
                wr_issue_count[operand0_bank_w] = 16'd1;
                wr_issue_total[operand0_bank_w] = 16'd1;
            end
        end
        if (aresetn && s_ctrl_mm2s_sts_valid && mm2s_response_match_w) begin
            wr_complete_valid[s_ctrl_mm2s_sts_tag] = 1'b1;
            wr_complete_error[s_ctrl_mm2s_sts_tag] = s_ctrl_mm2s_sts_error;
        end

        if (aresetn && user_request_fire_w && is_compute_w) begin
            wr_issue_valid[write_bank_w] = 1'b1;
            wr_issue_kind[write_bank_w] = write_kind_w;
            wr_issue_index[write_bank_w] = write_index_w;
            wr_issue_count[write_bank_w] = write_count_w;
            wr_issue_total[write_bank_w] = write_total_w;
        end
        for (int channel = 0; channel < 7; channel++) begin
            compute_done_ready[channel] = aresetn;
            completion_match_w[channel] = compute_done_valid[channel] &&
                compute_pending_r[channel] &&
                (compute_done_tag[channel] == pending_bank_r[channel][0]) &&
                (compute_done_bank_count[channel] == pending_bank_count_r[channel]);
            for (int position = 0; position < 3; position++) begin
                if (compute_done_bank[channel][position] != pending_bank_r[channel][position])
                    completion_match_w[channel] = 1'b0;
            end
            if (aresetn && completion_match_w[channel]) begin
                for (int position = 0; position < 3; position++) begin
                    if (position < pending_bank_count_r[channel]) begin
                        user_bank_release_valid_w[compute_done_bank[channel][position]] = 1'b1;
                        user_bank_release_port_w[compute_done_bank[channel][position]] =
                            pending_role_r[channel][position];
                    end
                end
                wr_complete_valid[pending_dst_r[channel]] = 1'b1;
                wr_complete_error[pending_dst_r[channel]] = compute_done_error[channel];
            end
            if (cmd_dispatcher_busy && compute_done_valid[channel] &&
                !completion_match_w[channel]) user_response_fault_w = 1'b1;
            if (cmd_dispatcher_busy && completion_match_w[channel] &&
                compute_done_error[channel]) user_executor_fault_w = 1'b1;
        end
        if (cmd_dispatcher_busy && (state_r == ISSUE_COMMAND)) begin
            if (is_compute_w && source_invalid_w) user_executor_fault_w = 1'b1;
            if (opcode_w == OP_S2MM && bank_in_range_w &&
                !bank_allowed(2, operand0_bank_w)) user_executor_fault_w = 1'b1;
            if (opcode_w == OP_MM2S && bank_in_range_w &&
                !bank_allowed(1, operand0_bank_w)) user_executor_fault_w = 1'b1;
            if (opcode_w == OP_S2MM && bank_in_range_w &&
                !bank_tensor_valid[operand0_bank_w]) user_executor_fault_w = 1'b1;
            if (opcode_w == OP_MM2S && dma_load_invalid_w)
                user_executor_fault_w = 1'b1;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            compute_pending_r <= '0;
            pending_bank_r <= '0;
            pending_role_r <= '0;
            pending_bank_count_r <= '0;
            pending_dst_r <= '0;
        end else begin
            for (int channel = 0; channel < 7; channel++) begin
                if (completion_match_w[channel]) compute_pending_r[channel] <= 1'b0;
                if (compute_fire_w[channel]) begin
                    compute_pending_r[channel] <= 1'b1;
                    pending_bank_r[channel][0] <= operand0_bank_w;
                    pending_bank_r[channel][1] <= operand1_bank_w;
                    pending_bank_r[channel][2] <= operand2_bank_w;
                    pending_role_r[channel][0] <= role_for(opcode_w, 0);
                    pending_role_r[channel][1] <= role_for(opcode_w, 1);
                    pending_role_r[channel][2] <= role_for(opcode_w, 2);
                    pending_bank_count_r[channel] <= used_bank_count_w;
                    pending_dst_r[channel] <= write_bank_w;
                end
            end
        end
    end
""",
}

def replace_body(source: str, name: str, body: str) -> str:
    pattern = re.compile(rf"(?P<start>^\s*// USER_{name}_BEGIN\n).*?(?P<end>^\s*// USER_{name}_END)", re.M | re.S)
    result, count = pattern.subn(lambda match: match["start"] + body + match["end"], source)
    if count != 1:
        raise RuntimeError(f"expected one USER_{name} marker pair, got {count}")
    return result

def main() -> None:
    source = SOURCE.read_text()
    output = source.replace("module cmd_dispatcher_template #(",
                            "module isa_command_dispatcher #(", 1)
    template_param = "    parameter integer PORT_ROLE_WIDTH   = 3\n"
    probe_param = ("    parameter integer PORT_ROLE_WIDTH   = 3,\n"
                   "    parameter bit ALLOW_ZERO_RMS_PROBE   = 1'b0\n")
    if output.count(template_param) != 1:
        raise RuntimeError("dispatcher template parameter anchor changed")
    output = output.replace(template_param, probe_param, 1)
    for name, body in BODIES.items():
        output = replace_body(output, name, body)
    stripped = output.replace("module isa_command_dispatcher #(",
                              "module cmd_dispatcher_template #(", 1)
    stripped = stripped.replace(probe_param, template_param, 1)
    for name in BODIES:
        stripped = replace_body(stripped, name, "")
        source = replace_body(source, name, "")
    if stripped != source:
        raise RuntimeError("generated dispatcher changed common template outside USER markers")
    # The model-specific GEMM_TILES sequencer also changes the common FSM
    # control points. Keep that small overlay explicit and reproducible.
    with tempfile.TemporaryDirectory(prefix="smollm2_dispatcher_") as temp:
        baseline = Path(temp) / "baseline.sv"
        patched = Path(temp) / "patched.sv"
        baseline.write_text(output)
        subprocess.run(["patch", "--batch", "--silent", "--output", str(patched),
                        str(baseline),
                        str(DESIGN / "scripts/gemm_tiles_dispatcher.patch")], check=True)
        output = patched.read_text()
    OUTPUT.write_text(output)
    print(f"generated {OUTPUT}")

if __name__ == "__main__":
    main()
