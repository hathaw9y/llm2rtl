"""Render design-authoring references into a synthetic control-only fixture."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
TEMPLATES = ROOT / "ip/infrastructure/templates"


def slot(text, name, body):
    pattern = rf"(\s*// {name}_BEGIN\n).*?(\s*// {name}_END)"
    result, count = re.subn(pattern, lambda match: match[1] + body + "\n" + match[2], text, flags=re.S)
    if count != 1:
        raise ValueError(f"expected exactly one {name} slot, got {count}")
    return result


def names(text, **mapping):
    for name, value in mapping.items():
        text = text.replace(f"__{name}__", value)
    if re.search(r"__[A-Z][A-Z0-9_]*__", text):
        raise ValueError("unfilled scalar template insertion")
    return text


def write(path, text):
    with path.open("x") as stream:
        stream.write(text)
    return path


def materialize(out, bank_id_width=3, deny_write_role=False):
    out = Path(out)
    config = (TEMPLATES / "bank_config_pkg.sv.tpl").read_text().replace("{{PACKAGE_NAME}}", "reference_test_config_pkg")
    config = config.replace("localparam int BANK_NUM = 2;", "localparam int BANK_NUM = 4;")
    config = config.replace("'{1,2}", "'{1,1,1,1}").replace("'{128,128}", "'{128,128,128,128}")
    config = config.replace("'{64,4096}", "'{64,64,64,64}")
    config = config.replace("'{8'h02,8'h02}", "'{8'h02,8'h02,8'h02,8'h02}")
    config = config.replace("'{8'h04,8'h04}", "'{8'h04,8'h04,8'h04,8'h04}")
    if deny_write_role:
        config = config.replace("'{8'h02,8'h02,8'h02,8'h02}", "'{8'h00,8'h02,8'h02,8'h02}")
    config = config.replace("endpackage", f"""
    localparam int BANK_NUM_WIDTH = {bank_id_width};
    localparam int PORT_ID_WIDTH = ROLE_WIDTH;
    localparam int CMD_DATA_WIDTH = 128;
    localparam int OPCODE_WIDTH = 4;
    localparam int ENGINE_NUM = 2;
    localparam int PAYLOAD_WIDTH = CMD_DATA_WIDTH-OPCODE_WIDTH-5*BANK_NUM_WIDTH;
    localparam logic [3:0] OP_END = 4'd0;
endpackage
""")
    sources = [write(out / "reference_test_config_pkg.sv", config)]
    controller_template = (TEMPLATES / "controller.sv.tpl").read_text()
    sources.append(write(out / "reference_unbound_controller.sv", names(controller_template,
        CONFIG_PKG="reference_test_config_pkg", CONTROLLER_MODULE="reference_unbound_controller")))
    decode = """    always_comb begin
        opcode_known_w = opcode_w == OP_END || opcode_w == 4'd1 || opcode_w == 4'd2;
        command_legal_w = opcode_w == OP_END;
        selected_engine_w = opcode_w == 4'd2 ? ENGINE_ID_WIDTH'(1) : '0;
        command_wr_mask_w = '0; command_rd_mask_w = '0;
        command_wr_roles_w = '0; command_rd_roles_w = '0;
        allow_split_overlap_w = 1'b0;
        if ((opcode_w == 4'd1 || opcode_w == 4'd2) &&
            int'(src_bank_w[0]) < BANK_NUM && int'(dst_bank_w) < BANK_NUM) begin
            command_legal_w = 1'b1;
            command_rd_mask_w[$clog2(BANK_NUM)'(src_bank_w[0])] = 1'b1;
            command_rd_roles_w[$clog2(BANK_NUM)'(src_bank_w[0])] = ROLE_WIDTH'(2);
            command_wr_mask_w[$clog2(BANK_NUM)'(dst_bank_w)] = 1'b1;
            command_wr_roles_w[$clog2(BANK_NUM)'(dst_bank_w)] = ROLE_WIDTH'(1);
        end
    end"""
    controller = slot(controller_template, "USER_DECODE", decode)
    sources.append(write(out / "reference_test_controller.sv", names(controller,
        CONFIG_PKG="reference_test_config_pkg", CONTROLLER_MODULE="reference_test_controller")))
    executor_template = (TEMPLATES / "executor_engine.sv.tpl").read_text()
    sources.append(write(out / "reference_unbound_executor.sv", names(executor_template,
        CONFIG_PKG="reference_test_config_pkg", EXECUTOR_MODULE="reference_unbound_executor")))
    executor = slot(executor_template, "USER_PORTS", """    , input logic fixture_allow_core_done, fixture_allow_drain
    , input logic fixture_core_error, fixture_unclean_fault""")
    executor = slot(executor, "USER_DECLARATIONS", "    logic fixture_core_done_r;")
    executor = slot(executor, "USER_LEGALITY", """    assign command_legal_w = (s_ctrl_cmd_opcode == 4'd1 || s_ctrl_cmd_opcode == 4'd2) &&
        int'(s_ctrl_cmd_src_bank[0]) < __CONFIG_PKG__::BANK_NUM &&
        int'(s_ctrl_cmd_dst_bank) < __CONFIG_PKG__::BANK_NUM;""")
    executor = slot(executor, "USER_DATAPATH", """    // SYNTHETIC TEST CORE. No arithmetic, bank traffic or model operation claimed.
    always_ff @(posedge aclk) begin
        if (!aresetn || !core_start_w) fixture_core_done_r <= 1'b0;
        else if (fixture_allow_core_done) fixture_core_done_r <= 1'b1;
    end
    assign core_done_w = fixture_core_done_r;
    assign core_error_w = fixture_core_error;
    assign core_unclean_fault_w = fixture_unclean_fault;
    // Test-controlled analogue of final accepted bank write/read drain.
    assign drain_done_w = fixture_allow_drain;""")
    sources.append(write(out / "reference_test_executor.sv", names(executor,
        CONFIG_PKG="reference_test_config_pkg", EXECUTOR_MODULE="reference_test_executor")))
    bank = (TEMPLATES / "bank_subsystem.sv.tpl").read_text().replace("{{PACKAGE_NAME}}", "reference_test_config_pkg").replace("{{MODULE_NAME}}", "reference_test_bank")
    sources.append(write(out / "reference_test_bank.sv", bank))
    shared = """
    localparam int PAYLOAD_WIDTH = CMD_DATA_WIDTH-OPCODE_WIDTH-5*BANK_NUM_WIDTH;
    logic [ENGINE_NUM-1:0] engine_valid, engine_ready, response_valid, response_ready;
    logic [ENGINE_NUM-1:0] response_error, response_clean;
    logic [ENGINE_NUM-1:0][CMD_DATA_WIDTH-1:0] response_command;
    logic [ENGINE_NUM-1:0][OPCODE_WIDTH-1:0] engine_opcode;
    logic [ENGINE_NUM-1:0][3:0][BANK_NUM_WIDTH-1:0] engine_src;
    logic [ENGINE_NUM-1:0][BANK_NUM_WIDTH-1:0] engine_dst;
    logic [ENGINE_NUM-1:0][PAYLOAD_WIDTH-1:0] engine_payload;
    logic [ENGINE_NUM-1:0] raw_ready, raw_response_valid, raw_response_clean, raw_response_error;
    logic [ENGINE_NUM-1:0] observed_core_start, observed_core_done;
    logic [ENGINE_NUM-1:0][CMD_DATA_WIDTH-1:0] raw_response_command;
    logic [BANK_NUM-1:0] wr_acquire, rd_acquire, wr_release, rd_release;
    logic [BANK_NUM-1:0] wr_busy, rd_busy, wr_acquired, rd_acquired, wr_released, rd_released;
    logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] wr_acquire_role, rd_acquire_role;
    logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] wr_release_role, rd_release_role, wr_owner, rd_owner;
    logic bank_error;
    logic unused_mm2s_ena [0:MM2S_BANK_COUNT-1];
    logic [ADDR_WIDTH-1:0] unused_mm2s_addra [0:MM2S_BANK_COUNT-1];
    logic [MM2S_DATA_WIDTH-1:0] unused_mm2s_dina [0:MM2S_BANK_COUNT-1];
    logic [MM2S_DATA_WIDTH/8-1:0] unused_mm2s_wea [0:MM2S_BANK_COUNT-1];
    logic unused_s2mm_enb [0:S2MM_BANK_COUNT-1];
    logic [ADDR_WIDTH-1:0] unused_s2mm_addrb [0:S2MM_BANK_COUNT-1];
    for (genvar p=0; p<MM2S_BANK_COUNT; p++) begin
        assign unused_mm2s_ena[p] = 1'b0; assign unused_mm2s_addra[p] = '0;
        assign unused_mm2s_dina[p] = '0; assign unused_mm2s_wea[p] = '0;
    end
    for (genvar p=0; p<S2MM_BANK_COUNT; p++) begin
        assign unused_s2mm_enb[p] = 1'b0; assign unused_s2mm_addrb[p] = '0;
    end
    assign engine_ready = raw_ready & fixture_issue_allow;
    assign response_valid = raw_response_valid | (fixture_bad_response ? ENGINE_NUM'(1) : '0);
    assign response_error = raw_response_error;
    assign response_clean = raw_response_clean | (fixture_bad_response ? ENGINE_NUM'(1) : '0);
    for (genvar e=0; e<ENGINE_NUM; e++) begin
        assign response_command[e] = fixture_bad_response && e == 0 ?
            (raw_response_command[e] ^ CMD_DATA_WIDTH'(1)) : raw_response_command[e];
    end
"""
    controller_ports = """
        .current_pc(), .cmd_bram_enb(cmd_bram_enb), .cmd_bram_addrb(cmd_bram_addrb), .cmd_bram_doutb(cmd_bram_doutb),
        .m_engine_cmd_valid(engine_valid), .m_engine_cmd_ready(engine_ready),
        .m_engine_cmd_opcode(engine_opcode), .m_engine_cmd_src_bank(engine_src),
        .m_engine_cmd_dst_bank(engine_dst), .m_engine_cmd_payload(engine_payload),
        .s_engine_resp_valid(response_valid), .s_engine_resp_ready(response_ready),
        .s_engine_resp_command(response_command), .s_engine_resp_error(response_error),
        .s_engine_resp_clean(response_clean),
        .bank_wr_acquire_valid(wr_acquire), .bank_rd_acquire_valid(rd_acquire),
        .bank_wr_acquire_port(wr_acquire_role), .bank_rd_acquire_port(rd_acquire_role),
        .bank_wr_release_valid(wr_release), .bank_rd_release_valid(rd_release),
        .bank_wr_release_port(wr_release_role), .bank_rd_release_port(rd_release_role),
        .bank_wr_busy(wr_busy), .bank_rd_busy(rd_busy), .bank_wr_owner_port(wr_owner), .bank_rd_owner_port(rd_owner),
        .bank_wr_acquire_accepted(wr_acquired), .bank_rd_acquire_accepted(rd_acquired),
        .bank_wr_release_accepted(wr_released), .bank_rd_release_accepted(rd_released), .bank_subsystem_error(bank_error)
"""
    bank_ports = """
        .bank_wr_acquire_valid(wr_acquire), .bank_rd_acquire_valid(rd_acquire),
        .bank_wr_acquire_port(wr_acquire_role), .bank_rd_acquire_port(rd_acquire_role),
        .bank_wr_release_valid(wr_release), .bank_rd_release_valid(rd_release),
        .bank_wr_release_port(wr_release_role), .bank_rd_release_port(rd_release_role),
        .bank_wr_busy(wr_busy), .bank_rd_busy(rd_busy), .bank_wr_owner_port(wr_owner), .bank_rd_owner_port(rd_owner),
        .bank_wr_acquire_accepted(wr_acquired), .bank_rd_acquire_accepted(rd_acquired),
        .bank_wr_release_accepted(wr_released), .bank_rd_release_accepted(rd_released),
        .mm2s_bank_ena(unused_mm2s_ena), .mm2s_bank_addra(unused_mm2s_addra),
        .mm2s_bank_dina(unused_mm2s_dina), .mm2s_bank_wea(unused_mm2s_wea), .mm2s_bank_ready(),
        .s2mm_bank_enb(unused_s2mm_enb), .s2mm_bank_addrb(unused_s2mm_addrb),
        .s2mm_bank_doutb(), .s2mm_bank_read_ready(), .s2mm_bank_valid(),
        .bank_committed_prefix(), .bank_subsystem_error(bank_error), .ownership_error(), .router_error(),
        .bank_subsystem_error_code(), .ownership_error_code(), .router_error_code()
"""
    engines = """
    for (genvar e=0; e<ENGINE_NUM; e++) begin : g_engines
        reference_test_executor u_engine (
            .aclk(aclk), .aresetn(aresetn), .s_ctrl_cmd_valid(engine_valid[e] && fixture_issue_allow[e]),
            .s_ctrl_cmd_ready(raw_ready[e]), .s_ctrl_cmd_opcode(engine_opcode[e]),
            .s_ctrl_cmd_src_bank(engine_src[e]), .s_ctrl_cmd_dst_bank(engine_dst[e]),
            .s_ctrl_cmd_payload(engine_payload[e]), .m_ctrl_resp_valid(raw_response_valid[e]),
            .m_ctrl_resp_ready(response_ready[e]), .m_ctrl_resp_command(raw_response_command[e]),
            .m_ctrl_resp_error(raw_response_error[e]), .m_ctrl_resp_clean(raw_response_clean[e]),
            .m_ctrl_resp_error_code(), .fixture_allow_core_done(fixture_core_done_allow[e]),
            .fixture_allow_drain(fixture_drain_allow[e]), .fixture_core_error(fixture_core_error[e]),
            .fixture_unclean_fault(fixture_unclean_fault[e])
        );
        assign observed_core_start[e] = u_engine.core_start_w;
        assign observed_core_done[e] = u_engine.core_done_w;
    end
"""
    fabric = names((TEMPLATES / "execution_fabric_native.sv.tpl").read_text(),
        CONFIG_PKG="reference_test_config_pkg", FABRIC_MODULE="reference_test_fabric",
        CONTROLLER_MODULE="reference_test_controller", BANK_MODULE="reference_test_bank",
        USER_TOP_PORTS="""output logic cmd_bram_enb,
    output logic [CMD_ADDR_WIDTH-1:0] cmd_bram_addrb,
    input logic [127:0] cmd_bram_doutb,
    input logic [ENGINE_NUM-1:0] fixture_issue_allow, fixture_core_done_allow,
    input logic [ENGINE_NUM-1:0] fixture_drain_allow, fixture_core_error, fixture_unclean_fault,
    input logic fixture_bad_response""",
        USER_SHARED_SIGNALS=shared, USER_CONTROLLER_PORTS=controller_ports,
        USER_BANK_PORTS=bank_ports, USER_ENGINE_INSTANCES=engines,
        USER_ASSERTIONS="// Invariants are dynamically checked by tb_reference_templates.")
    sources.append(write(out / "reference_test_fabric.sv", fabric))
    return sources
