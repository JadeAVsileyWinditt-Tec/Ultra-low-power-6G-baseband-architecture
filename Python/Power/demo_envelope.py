#!/usr/bin/env python3
"""
Demonstrate the TBU thermal boundary controller on the 2048-tile fabric.

Phase 1 – normal intensity-capped operation (design point, ~2.8 W max).
Phase 2 – synthetic over-subscription that forces the continuous
          boundary measure to throttle the fabric back toward 4 W.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import numpy as np
from power.fabric import FabricParams, FabricPowerModel
from tbu.core import TBUParams


def main():
    fabric = FabricParams()
    tbu = TBUParams(S_crit=4.0, delta=0.35, K=15.0)
    model = FabricPowerModel(fabric=fabric, tbu=tbu)

    print("=" * 64)
    print("TBU-6G Baseband – Thermal Envelope Demonstration")
    print("=" * 64)
    print(f"Tiles              : {fabric.n_tiles}")
    print(f"Transistors/tile   : {fabric.transistors_per_tile:,}")
    print(f"Intensity cap      : {fabric.intensity_cap_ops_per_transistor} ops/transistor")
    print(f"Energy per op      : {fabric.energy_per_op_J * 1e12:.2f} pJ")
    print(f"Max power @ cap    : {fabric.n_tiles * fabric.max_power_per_tile_W:.3f} W")
    print(f"Thermal envelope   : {fabric.thermal_envelope_W} W")
    print(f"TBU δ (softness)   : {tbu.delta}")
    print()

    # ------------------------------------------------------------------
    print("Phase 1: Intensity-capped load (design operating region)")
    print("-" * 64)
    load_profile = np.linspace(0.0, 1.0, 11)
    results = model.run_load_profile(load_profile.tolist(), label="capped")

    print(f"{'Load':>6}  {'Unconst P':>10}  {'Throttled P':>12}  "
          f"{'B_δ':>7}  {'Region':<10}  {'Entropy':>8}")
    for r in results:
        print(f"{r['load_factor']:6.2f}  {r['unconstrained_power_W']:10.3f}  "
              f"{r['total_power_W']:12.3f}  {r['boundary_measure']:7.4f}  "
              f"{r['region']:<10}  {r['entropy']:8.4f}")

    # ------------------------------------------------------------------
    print()
    print("Phase 2: Synthetic over-subscription (TBU must throttle)")
    print("-" * 64)
    overload_profile = np.linspace(0.9, 2.8, 14)
    results2 = model.run_load_profile(
        overload_profile.tolist(),
        label="overload",
        respect_intensity_cap=False,
    )

    print(f"{'Load':>6}  {'Unconst P':>10}  {'Throttled P':>12}  "
          f"{'B_δ':>7}  {'Region':<10}  {'Entropy':>8}")
    for r in results2:
        print(f"{r['load_factor']:6.2f}  {r['unconstrained_power_W']:10.3f}  "
              f"{r['total_power_W']:12.3f}  {r['boundary_measure']:7.4f}  "
              f"{r['region']:<10}  {r['entropy']:8.4f}")

    print()
    print(model.summary())
    print("Demonstration complete.")
    print("In Phase 1 the intensity caps keep power well under 4 W.")
    print("In Phase 2 the continuous TBU boundary measure actively")
    print("throttles the fabric as unconstrained power crosses the envelope.")


if __name__ == "__main__":
    main()
