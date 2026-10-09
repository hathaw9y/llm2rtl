#!/usr/bin/env python3
"""Build the ZCU104 A53 standalone smoke program with Vitis 2025.2 CLI."""
from pathlib import Path
import hashlib
import shutil
import zipfile
import vitis

design = Path(__file__).resolve().parents[1]
board = design / "board_smoke"
xsa = board / "artifacts" / "zcu104_gemm_board_smoke.xsa"
workspace = design / "build" / "gemm_board_vitis_cli"
if not xsa.exists():
    raise FileNotFoundError(xsa)
workspace.mkdir(parents=True, exist_ok=True)

client = vitis.create_client()
try:
    client.set_workspace(str(workspace))
    platform = client.create_platform_component(
        name="zcu104_gemm_platform", hw_design=str(xsa),
        os="standalone", cpu="psu_cortexa53_0",
        domain_name="standalone_a53_0")
    platform.build()
    xpfm = client.find_platform_in_repos("zcu104_gemm_platform")
    app = client.create_app_component(
        name="gemm_board_smoke", platform=xpfm,
        domain="standalone_a53_0", template="empty_application")
    app.import_files(from_loc=str(board), files=["main.c", "vectors.h"])
    app.build()
    elf = workspace / "gemm_board_smoke" / "build" / "gemm_board_smoke.elf"
    if not elf.exists():
        raise FileNotFoundError(elf)
    artifacts = board / "artifacts"
    shutil.copy2(elf, artifacts / "zcu104_gemm_board_smoke.elf")
    with zipfile.ZipFile(xsa) as archive:
        (artifacts / "zcu104_gemm_board_smoke.hwh").write_bytes(
            archive.read("system.hwh"))
        (artifacts / "psu_init.tcl").write_bytes(archive.read("psu_init.tcl"))
    names = ("zcu104_gemm_board_smoke.bit", "zcu104_gemm_board_smoke.xsa",
             "zcu104_gemm_board_smoke.hwh", "zcu104_gemm_board_smoke.elf")
    (artifacts / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256((artifacts / name).read_bytes()).hexdigest()}  {name}\n"
        for name in names))
    print(f"BOARD_APP_WORKSPACE {workspace}")
finally:
    vitis.dispose()
