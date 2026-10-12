"""Materialize the unchanged native-bank templates for controller simulation."""
from pathlib import Path

from infrastructure_sources import ROOT, resolve_profile, resolve_reference


def materialize_banks(work):
    work = Path(work)
    package = resolve_reference("ip/infrastructure/templates/bank_config_pkg.sv.tpl").read_text().replace(
        "{{PACKAGE_NAME}}", "controller_test_config_pkg")
    top = resolve_reference("ip/infrastructure/templates/bank_subsystem.sv.tpl").read_text().replace(
        "{{PACKAGE_NAME}}", "controller_test_config_pkg").replace(
        "{{MODULE_NAME}}", "controller_test_bank")
    config = work / "controller_test_config_pkg.sv"
    subsystem = work / "controller_test_bank.sv"
    with config.open("x") as stream:
        stream.write(package)
    with subsystem.open("x") as stream:
        stream.write(top)
    return [config, *resolve_profile("native_bank_children", root=ROOT, include_compatibility=True), subsystem]
