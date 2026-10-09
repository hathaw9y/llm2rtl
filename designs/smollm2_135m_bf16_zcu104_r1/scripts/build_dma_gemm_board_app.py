#!/usr/bin/env python3
"""Build the matching A53 standalone DDR DMA_LOAD board probe."""
from pathlib import Path
import hashlib
import shutil
import zipfile
import vitis

design = Path(__file__).resolve().parents[1]
board = design / "dma_gemm_board_probe"
artifacts = board / "artifacts"
xsa = artifacts / "zcu104_dma_gemm_board_probe.xsa"
workspace = design / "build" / "dma_load_board_vitis_cli"
if not xsa.exists():
    raise FileNotFoundError(xsa)
workspace.mkdir(parents=True, exist_ok=True)

client = vitis.create_client()
try:
    client.set_workspace(str(workspace))
    platform = client.create_platform_component(
        name="zcu104_dma_load_platform", hw_design=str(xsa),
        os="standalone", cpu="psu_cortexa53_0",
        domain_name="standalone_a53_0")
    platform.build()
    xpfm = client.find_platform_in_repos("zcu104_dma_load_platform")
    app = client.create_app_component(
        name="dma_gemm_board_probe", platform=xpfm,
        domain="standalone_a53_0", template="empty_application")
    app.import_files(from_loc=str(board), files=["main.c", "vectors.h"])
    app.build()
    elf = workspace / "dma_gemm_board_probe" / "build" / "dma_gemm_board_probe.elf"
    if not elf.exists():
        raise FileNotFoundError(elf)
    shutil.copy2(elf, artifacts / "zcu104_dma_gemm_board_probe.elf")
    with zipfile.ZipFile(xsa) as archive:
        (artifacts / "zcu104_dma_gemm_board_probe.hwh").write_bytes(
            archive.read("system.hwh"))
        (artifacts / "psu_init.tcl").write_bytes(archive.read("psu_init.tcl"))
    names = ("zcu104_dma_gemm_board_probe.bit",
             "zcu104_dma_gemm_board_probe.xsa",
             "zcu104_dma_gemm_board_probe.hwh",
             "zcu104_dma_gemm_board_probe.elf")
    (artifacts / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256((artifacts / name).read_bytes()).hexdigest()}  {name}\n"
        for name in names))
    print(f"DMA_BOARD_APP_WORKSPACE {workspace}")
finally:
    vitis.dispose()
