"""Materialize the unchanged native-bank templates for controller simulation."""
from pathlib import Path

from infrastructure_sources import ROOT, resolve_profile


def materialize_banks(work):
    work = Path(work)
    directory = ROOT / "ip/infrastructure/templates"
    package = (directory / "bank_config_pkg.sv.tpl").read_text().replace(
        "{{PACKAGE_NAME}}", "controller_test_config_pkg")
    top = (directory / "bank_subsystem.sv.tpl").read_text().replace(
        "{{PACKAGE_NAME}}", "controller_test_config_pkg").replace(
        "{{MODULE_NAME}}", "controller_test_bank")
    config = work / "controller_test_config_pkg.sv"
    subsystem = work / "controller_test_bank.sv"
    with config.open("x") as stream:
        stream.write(package)
    with subsystem.open("x") as stream:
        stream.write(top)
    return [config, *resolve_profile("native_bank_children", root=ROOT), subsystem]
