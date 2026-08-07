"""
Calibrated energy / power model for the 2048-tile TBU baseband fabric.

Source numbers (architecture specification):
  - ~40 billion transistors total
  - ≤ 700 ops / transistor (local intensity hard-cap)
  - ~0.10 pJ / operation
  - ≤ 4 W thermal envelope
  - Peak useful workload ≤ 2.6 × 10¹³ ops/s after pruning
"""

from __future__ import annotations

from dataclasses import dataclass
import numpy as np


@dataclass(frozen=True)
class EnergyParams:
    n_tiles: int = 2048
    transistors_total: int = 40_000_000_000
    intensity_cap_ops_per_transistor: float = 700.0
    energy_per_op_J: float = 0.10e-12          # 0.10 pJ
    thermal_envelope_W: float = 4.0
    target_ops_per_s: float = 2.6e13           # after 12–15× intensity cut

    # Approx / prune intensity reduction factors
    approx_factor: float = 0.55                  # approx ALU activity vs exact
    prune_light_factor: float = 0.75
    prune_aggressive_factor: float = 0.40

    @property
    def transistors_per_tile(self) -> float:
        return self.transistors_total / self.n_tiles

    @property
    def max_ops_per_tile(self) -> float:
        return self.transistors_per_tile * self.intensity_cap_ops_per_transistor

    @property
    def max_ops_fabric(self) -> float:
        return self.max_ops_per_tile * self.n_tiles

    @property
    def power_at_full_intensity_W(self) -> float:
        """Unconstrained power if every tile ran at the intensity cap."""
        return self.max_ops_fabric * self.energy_per_op_J

    def effective_ops(
        self,
        requested_ops: float,
        approx_en: bool = False,
        prune_level: int = 0,
    ) -> float:
        """
        Apply algorithmic intensity reduction then clamp to the hard cap.
        prune_level: 0=none, 1=light, 2=aggressive
        """
        ops = requested_ops
        if prune_level == 1:
            ops *= self.prune_light_factor
        elif prune_level >= 2:
            ops *= self.prune_aggressive_factor
        if approx_en:
            ops *= self.approx_factor
        return min(ops, self.max_ops_per_tile)

    def power_W(
        self,
        ops_per_tile: float | np.ndarray,
        throttle: float = 1.0,
    ) -> float | np.ndarray:
        """Instantaneous power for one or many tiles after throttle."""
        return np.asarray(ops_per_tile) * self.energy_per_op_J * throttle

    def summary(self) -> str:
        return (
            f"Energy model\n"
            f"  Tiles              : {self.n_tiles}\n"
            f"  Transistors/tile   : {self.transistors_per_tile:,.0f}\n"
            f"  Intensity cap      : {self.intensity_cap_ops_per_transistor} ops/xtor\n"
            f"  Energy/op          : {self.energy_per_op_J*1e12:.2f} pJ\n"
            f"  Power @ full cap   : {self.power_at_full_intensity_W:.3f} W\n"
            f"  Thermal envelope   : {self.thermal_envelope_W} W\n"
            f"  Target ops/s       : {self.target_ops_per_s:.2e}\n"
        )


# Default singleton used by demos and higher-level models
DEFAULT_ENERGY = EnergyParams()


if __name__ == "__main__":
    e = DEFAULT_ENERGY
    print(e.summary())
    print(f"Effective ops (exact, no prune) : {e.effective_ops(1e10):.3e}")
    print(f"Effective ops (approx+aggr)     : {e.effective_ops(1e10, approx_en=True, prune_level=2):.3e}")
