"""Hidden grading harness for the raster_walker testbench-writing task.

The agent delivers tb/tb_raster_walker.sv. This harness compiles that
testbench with Icarus Verilog against each RTL variant in grading/rtl/ and
runs it:

  - golden.sv  -> the testbench must PASS it: vvp exit code 0, output
                  contains TB_PASS and does not contain TB_FAIL;
  - mut_*.sv   -> the testbench must NOT pass it (any other outcome —
                  TB_FAIL, nonzero exit, timeout — counts as detected).

Grading is the pytest exit code, fail-closed.
"""
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
TB = ROOT / "tb" / "tb_raster_walker.sv"
RTL_DIR = ROOT / "grading" / "rtl"
BUILD = ROOT / "sim_build_grading"
TOP = "tb_raster_walker"
COMPILE_TIMEOUT = 60
RUN_TIMEOUT = 30

MUTANTS = sorted(RTL_DIR.glob("mut_*.sv"))


def run_against(rtl: Path):
    BUILD.mkdir(exist_ok=True)
    vvp_file = BUILD / (rtl.stem + ".vvp")
    comp = subprocess.run(
        ["iverilog", "-g2012", "-s", TOP, "-o", str(vvp_file),
         str(rtl), str(TB)],
        capture_output=True, text=True, timeout=COMPILE_TIMEOUT)
    if comp.returncode != 0:
        return "compile-error", comp.stderr[-4000:]
    try:
        sim = subprocess.run(["vvp", str(vvp_file)],
                             capture_output=True, text=True,
                             timeout=RUN_TIMEOUT)
    except subprocess.TimeoutExpired:
        return "timeout", ""
    ok = (sim.returncode == 0 and "TB_PASS" in sim.stdout
          and "TB_FAIL" not in sim.stdout)
    return ("pass" if ok else "fail"), (sim.stdout[-4000:] + sim.stderr[-2000:])


def test_testbench_exists():
    assert TB.is_file(), "tb/tb_raster_walker.sv is missing"


def test_mutant_set_present():
    # Fail-closed: a missing/empty grading set must never grade as a pass.
    assert (RTL_DIR / "golden.sv").is_file(), "grading/rtl/golden.sv missing"
    assert len(MUTANTS) >= 10, "grading mutant set missing or truncated"


def test_conforming_implementation_passes():
    verdict, log = run_against(RTL_DIR / "golden.sv")
    assert verdict == "pass", (
        "testbench must pass the conforming implementation, "
        f"got: {verdict}\n{log}")


@pytest.mark.parametrize("mutant", MUTANTS, ids=lambda p: p.stem)
def test_defective_implementation_detected(mutant):
    verdict, log = run_against(mutant)
    assert verdict != "pass", (
        f"testbench passed the defective implementation {mutant.stem}\n{log}")
