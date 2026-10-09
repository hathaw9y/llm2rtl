#!/usr/bin/env python3
"""Create the opcode-3 GEMM extension probe by replacing USER marker bodies only."""
from __future__ import annotations

import argparse
from pathlib import Path
import re


BODIES = {
    "PORTS": """    ,
    output logic m_user_cmd_valid,
    input  logic m_user_cmd_ready,
    output logic [BANK_NUM_WIDTH-1:0] m_user_cmd_bank0,
    output logic [BANK_NUM_WIDTH-1:0] m_user_cmd_bank1,
    output logic [BANK_NUM_WIDTH-1:0] m_user_cmd_bank2,
    input  logic s_user_done_valid,
    output logic m_user_done_ready,
    input  logic [BANK_NUM_WIDTH-1:0] s_user_done_bank0,
    input  logic [BANK_NUM_WIDTH-1:0] s_user_done_bank1,
    input  logic [BANK_NUM_WIDTH-1:0] s_user_done_bank2,
    input  logic s_user_done_error
""",
    "PARAMETERS": """    // The probe uses only base-template parameters.
""",
    "OPCODES": """    localparam logic [OPCODE_WIDTH-1:0] OP_GEMM_PROBE = 3;
""",
    "DECLARATIONS": """    localparam integer USER_MARKER_COUNT = 14;
    logic user_pending_r;
    logic [BANK_NUM_WIDTH-1:0] user_pending_bank0_r;
    logic [BANK_NUM_WIDTH-1:0] user_pending_bank1_r;
    logic [BANK_NUM_WIDTH-1:0] user_pending_bank2_r;
    logic [BANK_NUM_WIDTH:0] user_bank0_index_w;
    logic [BANK_NUM_WIDTH:0] user_bank1_index_w;
    logic [BANK_NUM_WIDTH:0] user_bank2_index_w;
    logic user_completion_match_w;
""",
    "DECODE": """    always_comb begin
        user_bank0_index_w = {1'b0, operand0_bank_w};
        user_bank1_index_w = {1'b0, operand1_bank_w};
        user_bank2_index_w = {1'b0, operand2_bank_w};
        user_opcode_known_w = (opcode_w == OP_GEMM_PROBE);
        user_command_legal_w = user_opcode_known_w &&
            (user_bank0_index_w < BANK_NUM_LIMIT) &&
            (user_bank1_index_w < BANK_NUM_LIMIT) &&
            (user_bank2_index_w < BANK_NUM_LIMIT) &&
            (operand0_bank_w != operand1_bank_w) &&
            (operand0_bank_w != operand2_bank_w) &&
            (operand1_bank_w != operand2_bank_w);
        user_bank_eligible_w = 1'b0;
        if (user_command_legal_w) begin
            user_bank_eligible_w = !user_pending_r &&
                !bank_busy[operand0_bank_w] && !bank_busy[operand1_bank_w] &&
                !bank_busy[operand2_bank_w];
        end
    end
""",
    "ISSUE": """    always_comb begin
        m_user_cmd_valid = aresetn && (state_r == ISSUE_COMMAND) &&
            (opcode_w == OP_GEMM_PROBE) &&
            !fixed_response_fault_w && !fixed_executor_fault_w &&
            !user_response_fault_w && !user_executor_fault_w;
        m_user_cmd_bank0 = operand0_bank_w;
        m_user_cmd_bank1 = operand1_bank_w;
        m_user_cmd_bank2 = operand2_bank_w;
        user_request_valid_w = m_user_cmd_valid;
        user_request_ready_w = m_user_cmd_ready;
        user_request_fire_w = m_user_cmd_valid && m_user_cmd_ready;
        user_bank_acquire_valid_w = '0;
        user_bank_acquire_port_w = '0;
        if (user_request_fire_w && user_command_legal_w) begin
            user_bank_acquire_valid_w[operand0_bank_w] = 1'b1;
            user_bank_acquire_port_w[operand0_bank_w] = PORT_ROLE_WIDTH'(3);
            user_bank_acquire_valid_w[operand1_bank_w] = 1'b1;
            user_bank_acquire_port_w[operand1_bank_w] = PORT_ROLE_WIDTH'(4);
            user_bank_acquire_valid_w[operand2_bank_w] = 1'b1;
            user_bank_acquire_port_w[operand2_bank_w] = PORT_ROLE_WIDTH'(5);
        end
    end
""",
    "COMPLETION": """    always_comb begin
        m_user_done_ready = aresetn;
        user_completion_match_w = s_user_done_valid && user_pending_r &&
            (s_user_done_bank0 == user_pending_bank0_r) &&
            (s_user_done_bank1 == user_pending_bank1_r) &&
            (s_user_done_bank2 == user_pending_bank2_r);
        user_pending_any_w = user_pending_r;
        user_bank_release_valid_w = '0;
        user_bank_release_port_w = '0;
        if (aresetn && user_completion_match_w) begin
            user_bank_release_valid_w[user_pending_bank0_r] = 1'b1;
            user_bank_release_port_w[user_pending_bank0_r] = PORT_ROLE_WIDTH'(3);
            user_bank_release_valid_w[user_pending_bank1_r] = 1'b1;
            user_bank_release_port_w[user_pending_bank1_r] = PORT_ROLE_WIDTH'(4);
            user_bank_release_valid_w[user_pending_bank2_r] = 1'b1;
            user_bank_release_port_w[user_pending_bank2_r] = PORT_ROLE_WIDTH'(5);
        end
        user_response_fault_w = cmd_dispatcher_busy && s_user_done_valid &&
            !user_completion_match_w;
        user_executor_fault_w = cmd_dispatcher_busy &&
            user_completion_match_w && s_user_done_error;
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            user_pending_r <= 1'b0;
            user_pending_bank0_r <= '0;
            user_pending_bank1_r <= '0;
            user_pending_bank2_r <= '0;
        end else begin
            if (user_completion_match_w) begin
                user_pending_r <= 1'b0;
            end
            if (user_request_fire_w) begin
                user_pending_r <= 1'b1;
                user_pending_bank0_r <= operand0_bank_w;
                user_pending_bank1_r <= operand1_bank_w;
                user_pending_bank2_r <= operand2_bank_w;
            end
        end
    end
""",
}


def replace_body(text: str, name: str, body: str) -> str:
    pattern = re.compile(
        rf"(?P<begin>^[ \t]*// USER_{name}_BEGIN[ \t]*\n).*?"
        rf"(?P<end>^[ \t]*// USER_{name}_END[ \t]*$)", re.M | re.S)
    updated, count = pattern.subn(lambda m: m.group("begin") + body + m.group("end"), text)
    if count != 1:
        raise RuntimeError(f"expected exactly one USER_{name} region, got {count}")
    return updated


def erase_bodies(text: str) -> str:
    for name in BODIES:
        text = replace_body(text, name, "")
    return text


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    original = args.source.read_text(encoding="utf-8")
    extended = original
    for name, body in BODIES.items():
        extended = replace_body(extended, name, body)
    if erase_bodies(original) != erase_bodies(extended):
        raise RuntimeError("extension changed text outside USER marker bodies")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(extended, encoding="utf-8")
    print("PASS: extension probe changed USER marker bodies only")


if __name__ == "__main__":
    main()
