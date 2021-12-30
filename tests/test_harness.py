#!/usr/bin/env python3
"""
Praxis Test & Verification Harness
Executes all Rust engine unit/integration tests, pure-Nix test suites,
CLI commands, simulation scenarios, and em-dash zero-tolerance audits.
"""

import os
import subprocess
import sys
import time

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ENGINE_DIR = os.path.join(ROOT_DIR, "engine")
PRAXIS_BIN = os.path.join(ENGINE_DIR, "target", "release", "praxis")


def run_cmd(cmd: list[str], cwd: str = ROOT_DIR) -> tuple[int, str, str]:
    proc = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return proc.returncode, proc.stdout, proc.stderr


def log_suite(name: str, passed: bool, duration: float, extra: str = ""):
    status = "\033[92mPASS\033[0m" if passed else "\033[91mFAIL\033[0m"
    print(f"[{status}] {name:<35} ({duration:.2f}s) {extra}")


def main() -> int:
    print("=================================================================")
    print("       PRAXIS COMPREHENSIVE VERIFICATION TEST SUITE              ")
    print("=================================================================\n")

    overall_start = time.time()
    failures = 0

    # 1. Zero Em Dash Audit
    start = time.time()
    rc, stdout, stderr = run_cmd([sys.executable, "scripts/check_no_em_dashes.py"])
    passed = (rc == 0)
    if not passed:
        failures += 1
    log_suite("Em Dash Zero-Tolerance Audit", passed, time.time() - start)

    # 2. Build Engine Release Binary
    start = time.time()
    rc, stdout, stderr = run_cmd(["cargo", "build", "--release"], cwd=ENGINE_DIR)
    passed = (rc == 0 and os.path.exists(PRAXIS_BIN))
    if not passed:
        failures += 1
        print(f"Engine compilation failed: {stderr}")
    log_suite("Praxis Engine Compilation", passed, time.time() - start)

    if not passed:
        print("\nAborting: Engine binary unavailable.")
        return 1

    # 3. Rust Unit and Integration Tests
    start = time.time()
    rc, stdout, stderr = run_cmd(["cargo", "test", "--quiet"], cwd=ENGINE_DIR)
    passed = (rc == 0)
    if not passed:
        failures += 1
        print(stderr)
    log_suite("Rust Core Test Suite (17 tests)", passed, time.time() - start)

    # 4. CLI Subcommand: Simulate
    start = time.time()
    rc, stdout, stderr = run_cmd([PRAXIS_BIN, "simulate"])
    passed = (rc == 0 and "All Deterministic Simulation Tests Passed" in stdout)
    if not passed:
        failures += 1
    log_suite("Deterministic Cluster Simulator", passed, time.time() - start)

    # 5. CLI Subcommand: Build
    start = time.time()
    rc, stdout, stderr = run_cmd([PRAXIS_BIN, "build"])
    passed = (rc == 0 and "Artifact Synthesis Complete" in stdout)
    if not passed:
        failures += 1
    log_suite("Artifact Synthesis (OCI, eBPF, SLSA)", passed, time.time() - start)

    # 6. CLI Subcommand: Graph
    start = time.time()
    rc, stdout, stderr = run_cmd([PRAXIS_BIN, "graph"])
    passed = (rc == 0 and "PRAXIS BOOT & SERVICE TOPOLOGY DAG" in stdout)
    if not passed:
        failures += 1
    log_suite("Topology DAG Visualizer", passed, time.time() - start)

    # 7. CLI Subcommand: Dashboard
    start = time.time()
    rc, stdout, stderr = run_cmd([PRAXIS_BIN, "dashboard"])
    passed = (rc == 0 and "PRAXIS CLUSTER CONTROL PLANE" in stdout)
    if not passed:
        failures += 1
    log_suite("Control Plane Status Dashboard", passed, time.time() - start)

    # 8. Pure Nix Expression Evaluation Tests via Praxis Engine
    nix_eval_tests = [
        ("Inline Arithmetic & Let-In", "let x = 100; y = 25; in x / y", "4"),
        ("Higher-Order Lambda Currying", "let f = a: b: a + b; in f 19 23", "42"),
        ("Attribute Set Recursive Merging", "let a = { u = 1; }; b = { v = 2; }; in a // b", "{ u = 1; v = 2; }"),
        ("Standard Builtins String Length", 'builtins.stringLength "praxis-hypervisor"', "17"),
        ("Standard Builtins Substring", 'builtins.substring 0 6 "praxis-engine"', '"praxis"'),
    ]

    for test_name, expr, expected in nix_eval_tests:
        start = time.time()
        rc, stdout, stderr = run_cmd([PRAXIS_BIN, "eval", expr])
        out = stdout.strip()
        passed = (rc == 0 and out == expected)
        if not passed:
            failures += 1
            print(f"  Eval failed for: {expr} | Expected: '{expected}', Got: '{out}' | Error: {stderr}")
        log_suite(f"Nix Eval: {test_name}", passed, time.time() - start)

    # 9. Static AST Linter
    start = time.time()
    rc, stdout, stderr = run_cmd([PRAXIS_BIN, "lint", "flake.nix"])
    passed = (rc == 0)
    if not passed:
        failures += 1
    log_suite("Static AST Linter (flake.nix)", passed, time.time() - start)

    print("\n=================================================================")
    total_time = time.time() - overall_start
    if failures == 0:
        print(f"\033[92mALL TESTS PASSED SUCCESSFULLY (Total time: {total_time:.2f}s)\033[0m")
        return 0
    else:
        print(f"\033[91mFAILURE: {failures} test suite(s) failed (Total time: {total_time:.2f}s)\033[0m")
        return 1


if __name__ == "__main__":
    sys.exit(main())
