#!/usr/bin/env python3
"""Create the opcode-3 arbitrary role extension probe by replacing USER marker bodies only."""
from __future__ import annotations

import argparse
from pathlib import Path
import re


BODIES = {
    "PORTS": """    , output logic m_ctrl_probe_cmd_valid
    , input logic m_ctrl_probe_cmd_ready
    , output logic [BANK_NUM_WIDTH-1:0] m_ctrl_probe_cmd_src, m_ctrl_probe_cmd_dst
    , input logic s_ctrl_probe_sts_valid
    , output logic m_ctrl_probe_sts_ready
    , input logic [BANK_NUM_WIDTH-1:0] s_ctrl_probe_sts_src, s_ctrl_probe_sts_dst
    , input logic s_ctrl_probe_sts_error
""",
    "PARAMETERS": """    // Arbitrary two-operand executor smoke fixture; base parameters suffice.
""",
    "OPCODES": """    localparam logic [OPCODE_WIDTH-1:0] OP_PROBE = OPCODE_WIDTH'(3);
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_PROBE_READ = PORT_ROLE_WIDTH'(3);
    localparam logic [PORT_ROLE_WIDTH-1:0] PORT_PROBE_WRITE = PORT_ROLE_WIDTH'(4);
""",
    "DECLARATIONS": """    logic probe_pending_r, probe_issued_r, probe_completed_r;
    logic [BANK_NUM_WIDTH-1:0] probe_src_r, probe_dst_r;
    logic probe_match_w, probe_status_fire_w, probe_owner_fault_w;
""",
    "DECODE": """    always_comb begin
        user_opcode_known_w = opcode_w == OP_PROBE;
        user_command_legal_w = user_opcode_known_w &&
            {1'b0,operand0_bank_w} < BANK_NUM_LIMIT &&
            {1'b0,operand1_bank_w} < BANK_NUM_LIMIT && operand0_bank_w != operand1_bank_w;
        user_bank_eligible_w = 1'b0;
        user_bank_wr_acquire_valid_w = '0; user_bank_rd_acquire_valid_w = '0;
        user_bank_wr_acquire_port_w = '0; user_bank_rd_acquire_port_w = '0;
        if (user_command_legal_w) begin
            user_bank_wr_acquire_valid_w[operand0_bank_w] = 1'b1;
            user_bank_rd_acquire_valid_w[operand1_bank_w] = 1'b1;
            user_bank_wr_acquire_port_w[operand0_bank_w] = PORT_PROBE_WRITE;
            user_bank_rd_acquire_port_w[operand1_bank_w] = PORT_PROBE_READ;
            user_bank_eligible_w = !probe_pending_r &&
                !bank_wr_busy[operand0_bank_w] && !bank_rd_busy[operand0_bank_w] &&
                !bank_wr_busy[operand1_bank_w] && !bank_rd_busy[operand1_bank_w] &&
                !bank_rd_pending[operand0_bank_w] && !bank_rd_pending[operand1_bank_w];
        end
    end
""",
    "ISSUE": """    always_comb begin
        m_ctrl_probe_cmd_valid = aresetn && state_r == EXECUTE && opcode_w == OP_PROBE;
        m_ctrl_probe_cmd_src = operand1_bank_w;
        m_ctrl_probe_cmd_dst = operand0_bank_w;
        user_request_valid_w = m_ctrl_probe_cmd_valid;
        user_request_ready_w = m_ctrl_probe_cmd_ready;
    end
""",
    "COMPLETION": """    always_comb begin
        m_ctrl_probe_sts_ready = aresetn && cmd_dispatcher_busy;
        probe_status_fire_w = s_ctrl_probe_sts_valid && m_ctrl_probe_sts_ready;
        probe_owner_fault_w = probe_pending_r &&
            (!bank_rd_busy[probe_src_r] || bank_rd_owner_port[probe_src_r] != PORT_PROBE_READ ||
             !bank_wr_busy[probe_dst_r] || bank_wr_owner_port[probe_dst_r] != PORT_PROBE_WRITE);
        probe_match_w = probe_pending_r && !probe_completed_r && !probe_owner_fault_w &&
            (probe_issued_r || user_request_fire_w) &&
            s_ctrl_probe_sts_src == probe_src_r && s_ctrl_probe_sts_dst == probe_dst_r;
        user_pending_any_w = probe_pending_r;
        user_bank_wr_release_valid_w = '0; user_bank_rd_release_valid_w = '0;
        user_bank_wr_release_port_w = '0; user_bank_rd_release_port_w = '0;
        if (probe_pending_r && probe_completed_r && !probe_owner_fault_w && !bank_rd_pending[probe_src_r]) begin
            user_bank_wr_release_valid_w[probe_dst_r] = 1'b1;
            user_bank_rd_release_valid_w[probe_src_r] = 1'b1;
            user_bank_wr_release_port_w[probe_dst_r] = PORT_PROBE_WRITE;
            user_bank_rd_release_port_w[probe_src_r] = PORT_PROBE_READ;
        end
        user_response_fault_w = probe_owner_fault_w || (probe_status_fire_w && !probe_match_w);
        user_executor_fault_w = probe_status_fire_w && probe_match_w && s_ctrl_probe_sts_error;
    end
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            probe_pending_r <= 1'b0; probe_issued_r <= 1'b0; probe_completed_r <= 1'b0;
            probe_src_r <= '0; probe_dst_r <= '0;
        end else begin
            if (user_acquire_fire_w) begin
                probe_pending_r <= 1'b1;
                probe_src_r <= operand1_bank_w; probe_dst_r <= operand0_bank_w;
            end
            if (user_request_fire_w) probe_issued_r <= 1'b1;
            if (probe_status_fire_w && probe_match_w) probe_completed_r <= 1'b1;
            if (probe_pending_r && bank_wr_release_valid[probe_dst_r] && bank_rd_release_valid[probe_src_r] &&
                bank_wr_release_accepted[probe_dst_r] && bank_rd_release_accepted[probe_src_r]) begin
                probe_pending_r <= 1'b0; probe_issued_r <= 1'b0; probe_completed_r <= 1'b0;
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
