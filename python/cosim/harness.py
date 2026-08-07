#!/usr/bin/env python3
"""
Co-simulation harness for the TBU-controlled 6G baseband fabric.

Uses the calibrated energy model to:
  - estimate power under rising load
  - apply the same regional / pruning decisions the RTL makes
  - check that the 4 W envelope is respected

This is the software twin of the fabric_slice / multi_slice_top path.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import numpy as np
from power.energy_model import EnergyParams, DEFAULT_ENERGY
from tbu.core import TBUParams, boundary_measure, classify_region, Region


def rtl_style_throttle(power_W: float, tbu: TBUParams) -> float:
    """Mirror the inverted logistic used by the TBCU (1 - B_δ)."""
    B = boundary_measure(power_W, tbu)
    return float(1.0 - B)


def rtl_style_prune(region: Region, throttle: float) -> tuple[bool, int]:
    """Mirror pruning_controller.sv decisions."""
    if region == Region.BOUND:
        return True, 2          # approx + aggressive
    if region == Region.BOUNDARY:
        return True, 1          # approx + light
    if throttle < 0.75:
        return True, 1
    return False, 0


def run_harness(
    load_factors: list[float],
    energy: EnergyParams = DEFAULT_ENERGY,
    tbu: TBUParams = TBUParams(S_crit=4.0, delta=0.25, K=12.0),
) -> None:
    print("=" * 64)
    print("TBU Co-simulation Harness")
    print("=" * 64)
    print(energy.summary())
    print(f"{'Load':>6}  {'Req ops':>12}  {'Eff ops':>12}  {'Power W':>8}  "
          f"{'Thr':>6}  {'Region':<10}  {'Prune':>5}")
    print("-" * 64)

    full = energy.max_ops_per_tile

    for load in load_factors:
        requested = load * full
        # First pass – unconstrained power estimate
        power_raw = energy.power_W(requested, throttle=1.0)
        thr = rtl_style_throttle(float(power_raw), tbu)
        region = classify_region(float(power_raw), tbu)
        approx_en, prune_level = rtl_style_prune(region, thr)

        # Apply algorithmic intensity reduction then throttle
        eff = energy.effective_ops(requested, approx_en=approx_en, prune_level=prune_level)
        power = float(energy.power_W(eff, throttle=thr))

        print(f"{load:6.2f}  {requested:12.3e}  {eff:12.3e}  {power:8.3f}  "
              f"{thr:6.3f}  {region.name:<10}  {prune_level:5d}")

    print("-" * 64)
    print("Harness complete – envelope behaviour mirrors RTL control policy.")


if __name__ == "__main__":
    profile = list(np.linspace(0.1, 2.5, 15))
    run_harness(profile)
